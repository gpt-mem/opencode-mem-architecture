# Промпт для отдельной сессии: независимая проверка, что Ladder (trained-assist) принял новый вариант

Скопируй этот файл целиком в новую сессию OpenCode как задачу.

---

## Задача

Проверить, что воркер Ladder на проде (`https://llm-ladder.trainedassist.store`) уже работает с «новым вариантом» — то есть больше **не отвергает** клиентское поле `ladder_cache_variant`, а вырезает его и обслуживает дефолтную ветку.

Контекст (для понимания, что именно проверяем; в отчёте не пересказывать):

- `trained-assist/trained-assist-llm-ladder#276` («fix: ignore legacy Ladder cache variants») — смержен и задеплоен: из тела запроса поле `ladder_cache_variant` вырезается, проверка блока снята, заголовки `x-ladder-cache-variant` / `x-ladder-cache-scope` и поля `ladder_cache_scope` / `ladder_cache_variant` из ответа убраны.
- `gpt-mem/opencode-mem#165` — клиентская маска и её леджер `provider_cache_mark` выпилены, форк это поле больше не шлёт.
- До #276 сервис отвечал `400 invalid ladder_cache_variant` на любое тело с этим блоком, из-за чего на `ladder/*` умирал второй шаг ассистента.

Версия сервиса наружу не отдаётся, поэтому проверка только чёрно-белая (поведенческая).

## Ограничения

- Только чтение: **ничего не коммитить, не пушить, не деплоить**, репозитории не править.
- Секреты не печатать в вывод и не писать в отчёт (ключ достаётся из конфига в переменную окружения и используется через `$KEY`).
- Работать на боевом сервисе разрешено только `POST /v1/chat/completions` с короткими промптами (1–2 предложения) и без tools у провайдера. Никаких длинных генераций.
- Всё, что не прошло, фиксировать как FAIL, а не «починить».

## Предусловия

```bash
# ключ ладдера — в конфиге opencode, наружу не печатаем
KEY=$(python3 -c "import json;print(json.load(open('$HOME/.config/opencode/opencode.json'))['provider']['ladder']['options']['apiKey'])")
[ -n "$KEY" ] && echo "ключ есть" || echo "КЛЮЧ НЕ НАЙДЕН — стоп"
```

Если ключа нет — проверку не начинать, отчёт: BLOCKED.

## Шаги

### 0. Зафиксировать, что именно проверяем

```bash
export GH_TOKEN=$(security find-generic-password -s github.com -a kobzevvv -w) 2>/dev/null
gh api repos/trained-assist/trained-assist-llm-ladder/commits/main --jq '.sha + " | " + (.commit.message|split("\n")[0])'
```

Ожидается коммит с сообщением вида `fix: ignore legacy Ladder cache variants (#276)`.
Если main не содержит этого коммита — дальше всё равно проверять поведение, но отметить это в отчёте.

### 1. Контрольный запрос без блока

```bash
curl -sS -o /tmp/lv1.json -D /tmp/lv1.hdr -w "HTTP %{http_code}\n" \
  -X POST https://llm-ladder.trainedassist.store/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -H 'User-Agent: opencode/2.0 (darwin; arm64) Bun/1.4.2' \
  -d '{"model":"build","messages":[{"role":"user","content":"Say hi."}],"stream":false}'
```

**PASS:** HTTP 200, тело — обычный chat-completion.
Важно: если Cloudflare отвечает `403` с `error code: 1010` — это блок по User-Agent, а не проверяемая ошибка; повторить с другим UA и отметить в отчёте, что без корректного UA сервис отвечает 403 (это отдельная находка).

### 2. Блок с настоящим scope (то, что раньше давало 400)

Взять scope из заголовков шага 1, если он есть (`grep -i 'x-ladder-cache-scope' /tmp/lv1.hdr`), иначе — синтетический корректный по формату `v1_` + 32 hex.

```bash
SCOPE=$(grep -i 'x-ladder-cache-scope' /tmp/lv1.hdr | tr -d '\r' | awk '{print $2}')
[ -n "$SCOPE" ] || SCOPE="v1_$(printf '%032d' 0)"
cat > /tmp/lv2.json <<EOF
{"model":"build","messages":[{"role":"user","content":"Say hi."}],
 "ladder_cache_variant":{"rung":"opencode-go/longcat-2.5-preview-free",
 "cache_scope":"$SCOPE","variant":"masked",
 "messages":[{"role":"user","content":"Say hi."}]}}
EOF
curl -sS -o /tmp/lv2.out -D /tmp/lv2.hdr -w "HTTP %{http_code}\n" \
  -X POST https://llm-ladder.trainedassist.store/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -H 'User-Agent: opencode/2.0 (darwin; arm64) Bun/1.4.2' --data-binary @/tmp/lv2.json
```

**PASS:** HTTP 200. **До #276 здесь был 400 `invalid ladder_cache_variant`.**

### 3. Блок с заведомо мусорным scope и чужим rung

```bash
cat > /tmp/lv3.json <<'EOF'
{"model":"build","messages":[{"role":"user","content":"Say hi."}],
 "ladder_cache_variant":{"rung":"openrouter/some/other","cache_scope":"garbage",
 "variant":"masked","messages":[{"role":"user","content":"Say hi."}]}}
EOF
curl -sS -o /tmp/lv3.out -D /tmp/lv3.hdr -w "HTTP %{http_code}\n" \
  -X POST https://llm-ladder.trainedassist.store/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -H 'User-Agent: opencode/2.0 (darwin; arm64) Bun/1.4.2' --data-binary @/tmp/lv3.json
```

**PASS:** HTTP 200. Сервис не должен ни валидировать, ни отвергать подсказку.

### 4. Поле вырезается и не уходит провайдеру

Поднять локальный прокси, который логирует тело запроса и пересылает его на прод:

```bash
cat > /tmp/lv-proxy.mjs <<'EOF'
import http from 'node:http'
const UP = 'https://llm-ladder.trainedassist.store'
const server = http.createServer(async (req, res) => {
  const chunks = []; for await (const c of req) chunks.push(c)
  const body = Buffer.concat(chunks)
  console.log('REQ BODY KEYS:', Object.keys(JSON.parse(body.toString() || '{}')))
  console.log('HAS ladder_cache_variant:', Object.hasOwn(JSON.parse(body.toString() || '{}'), 'ladder_cache_variant'))
  const h = { ...req.headers }; delete h.host; delete h['content-length']
  const up = await fetch(UP + req.url, { method: req.method, headers: h, body: body.length ? body : undefined })
  const t = await up.text()
  console.log('UPSTREAM STATUS:', up.status)
  res.writeHead(up.status, Object.fromEntries(up.headers.entries())); res.end(t)
})
server.listen(8802, '127.0.0.1', () => console.log('proxy 8802'))
EOF
node /tmp/lv-proxy.mjs > /tmp/lv-proxy.log 2>&1 &
sleep 1
```

Дальше отправить запрос с блоком на прокси (тот же URL, но порт 8802 и путь `/v1/chat/completions`):

```bash
curl -sS -o /dev/null -w "HTTP %{http_code}\n" \
  -X POST http://127.0.0.1:8802/v1/chat/completions \
  -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  -H 'User-Agent: opencode/2.0 (darwin; arm64) Bun/1.4.2' --data-binary @/tmp/lv2.json
sleep 1; cat /tmp/lv-proxy.log
```

**PASS:** в логе прокси `HAS ladder_cache_variant: false` (поле вырезано до апстрима) и `UPSTREAM STATUS: 200`.
Потом убить прокси: `pkill -f lv-proxy.mjs`

### 5. Ответ не содержит cache-полей

```bash
echo "--- заголовки ---"; cat /tmp/lv2.hdr | grep -i 'x-ladder' || echo "(нет x-ladder-* заголовков)"
echo "--- поля в теле ---"; grep -o 'ladder_cache_scope\|ladder_cache_variant' /tmp/lv2.out || echo "(нет полей ladder_cache_* в теле)"
```

**PASS:** нет `x-ladder-cache-variant`, нет `x-ladder-cache-scope`, нет `ladder_cache_scope`/`ladder_cache_variant` в теле.
(Наличие других `x-ladder-*` заголовков — норма, например `x-ladder-model`, `x-ladder-attempts`.)

### 6. Клиент форка это поле больше не шлёт

```bash
CFG=$(python3 -c "import json;c=json.load(open('$HOME/.config/opencode/opencode.json'));c['provider']['ladder']['options']['baseURL']='http://127.0.0.1:8802/v1';print(json.dumps(c))")
cd /tmp && OPENCODE_CONFIG_CONTENT="$CFG" ~/.opencode/bin/opencode run --standalone \
  --model ladder/build --auto "вызови bash 'echo probe-ladder-variant'" 2>&1 | tail -6
sleep 1; echo "--- что ушло в сеть ---"; grep -E "HAS ladder_cache_variant|UPSTREAM STATUS|REQ BODY KEYS" /tmp/lv-proxy.log | tail -6
```

**PASS:** `HAS ladder_cache_variant: false`, `UPSTREAM STATUS: 200`, и в выводе хода **нет** строки `invalid ladder_cache_variant`.
Ранее здесь ход падал с `Error: invalid ladder_cache_variant` на втором шаге.

### 7. Двухшаговый ход на `ladder/build` (регрессия того самого бага)

```bash
cd /tmp && ~/.opencode/bin/opencode run --standalone --model ladder/build --auto \
  "вызови bash 'echo step-one-value', затем покажи результат" 2>&1 | tail -8
```

**PASS:** ход завершился без `invalid ladder_cache_variant` и без прочих ошибок; в выводе видно значение `step-one-value`.

### 8. Префикс-кеш ладдера жив и без маски

```bash
grep -i 'x-ladder-attempts' /tmp/lv2.hdr || echo "(нет x-ladder-attempts)"
```

**PASS (мягкий):** заголовок содержит `pin=hit` либо `pin=hit` встречается в последующих запросах серии. Если `pin=hit` нет — это не регресс (кеш зависит от прогрева и нагрузки), но отметить в отчёте.

### 9. Регрессия по соседним провайдерам

```bash
cd /tmp && ~/.opencode/bin/opencode run --standalone --model mem-gpt/build --auto "ответь одним словом: ok" 2>&1 | tail -3
cd /tmp && ~/.opencode/bin/opencode run --standalone --model opencode-go/beam-free --auto "ответь одним словом: ok" 2>&1 | tail -3
~/.opencode/bin/opencode auth list 2>&1 | tail -5
```

**PASS:** оба отвечают, `auth list` показывает `OpenCode Go` и `Mem-GPT`.

### 10. Сток-бэкап не сломан

```bash
~/.opencode/bin/opencode.stock-backup --version 2>&1 | head -1
~/.opencode/bin/opencode.stock-backup auth list 2>&1 | tail -5
```

**PASS:** версия `2.0.32`, обе креды на месте, та же база.

## Критерии приёмки (сводно)

| # | Проверка | PASS-условие |
|---|---|---|
| 1 | Контрольный запрос | HTTP 200 |
| 2 | Блок с настоящим scope | HTTP 200 (было 400) |
| 3 | Блок с мусорным scope/rung | HTTP 200 (было 400) |
| 4 | Поле вырезается до апстрима | в прокси `HAS ladder_cache_variant: false` |
| 5 | Ответ без cache-полей | нет `x-ladder-cache-*`, нет `ladder_cache_*` в теле |
| 6 | Клиент форка не шлёт блок | `HAS ladder_cache_variant: false`, ход без ошибки |
| 7 | Двухшаговый ход на ladder | без `invalid ladder_cache_variant` |
| 8 | Префикс-кеш | `pin=hit` (мягкий критерий) |
| 9 | mem-gpt / opencode-go / auth | отвечают, обе креды |
| 10 | Сток-бэкап | v2.0.32, обе креды |

Итог: **PASS**, если зелёные пункты 1–7 и 9–10; пункт 8 — отдельно как наблюдение.

## Если проверка упала

1. Проверить, что на проде именно новая ревизия: `gh api repos/trained-assist/trained-assist-llm-ladder/commits/main --jq .sha` и `gh run list --repo trained-assist/trained-assist-llm-ladder --limit 5`.
2. Посмотреть в коде сервиса, что именно должно измениться: `src/ladder.js` (нет проверки `invalid ladder_cache_variant`, нет `cacheScopeFor`), `src/handler.js` (`ladder_cache_variant: _ignoredCacheVariant`, пустые `cacheHeaders`, тело без `ladder_cache_*`).
3. Ничего не деплоить — только диагностика. В отчёте указать, что нужно для исправления.

## Формат отчёта

1. Итоговая строка: `ИТОГ: PASS` / `ИТОГ: FAIL (N из M)` / `ИТОГ: BLOCKED (причина)`.
2. Таблица: номер | проверка | фактический HTTP/значение | PASS/FAIL | комментарий.
3. Отдельно: версия `main` ладдера на момент проверки.
4. Отдельно: наблюдения (например, 403 по UA, отсутствие `pin=hit`, что-либо неожиданное).
5. Ничего секретного: токены, ключи и полные тела с ключами не выводить.

Если все пункты PASS — отчёт короткий, без пересказа теории.
