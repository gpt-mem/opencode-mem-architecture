# Промпт для отдельной сессии: проверка, что ai-agent-runner запускает наш свежий opencode

Скопируй этот файл целиком в новую сессию OpenCode как задачу.

---

## Задача

Проверить, **какой именно opencode запускает trained-assist в проде** (репозиторий `trained-assist/ai-agent-runner`, воркер на VM), и ответить на вопрос: **это наша свежая сборка или устаревшая?**

Под «свежей» понимается сборка форка `gpt-mem/opencode-mem`, содержащая изменение `gpt-mem/opencode-mem#165` (выпил маски Ladder и леджера `provider_cache_mark`), то есть исходный коммит

```
7a12f66b4abc741d380af2125ef9fe4e72d43f53   (v2-base, merge PR #165)
```

или любой его потомок.

Контекст (в отчёте не пересказывать, использовать для трактовки):

- Раннер не ставит opencode из npm: он бандлит **закреплённую (pinned) сборку форка** — пять полей `OPENCODE_*` в `.github/workflows/vm-worker-release.yml`.
- Промоушен форка в раннере автоматический: `.github/workflows/opencode-fork-promotion.yml` (cron `41 */6 * * *` + ручной `workflow_dispatch`) находит в `gpt-mem/opencode-mem` последний опубликованный релиз вида `mem-preview-<YYYYMMDD>-<...>`, прогоняет гейт и, если зелёный, переписывает пин и открывает PR.
- Детектор берёт **только** теги по регулярке `^mem-preview-\d{8}-[A-Za-z0-9.-]+$` (`scripts/update-opencode-release-pin.mjs`, `PREVIEW_TAG` в `scripts/opencode-promotion-candidate.mjs`), требует `target_commitish` = полный 40-символьный SHA и ассеты `opencode-linux-x64.tar.gz` + `opencode-linux-x64.tar.gz.sha256` с опубликованным дайджестом.
- Наш свежий релиз форка `mem-v20261020-0431-7a12f66b4abc` (source `7a12f66b4abc741d380af2125ef9fe4e72d43f53`) под эти требования **не подходит**: тег не по регулярке, ассеты только `opencode-darwin-arm64.tar.gz` (+ `.sha256`), linux-x64 нет.
- Воркер работает на модели `ladder/free` (`deploy/vm-worker/engine-config/opencode.json`), провайдер `ladder`, baseURL `https://llm-ladder.trainedassist.store/v1`.

**Важная честная оговорка, чтобы не сделать неверный вывод:** после `trained-assist/trained-assist-llm-ladder#276` сервис **игнорирует** легаси-блок `ladder_cache_variant` и больше не отвечает `400 invalid ladder_cache_variant`. Поэтому поведенческая проверка «есть ли 400» **не различает** старую и новую сборку — у обеих её не будет. Различать надо по источнику и по бинарю (шаги 3 и 4). Не делай вывод «всё хорошо, 400 нет ⇒ раннер свежий».

## Ограничения

- Только чтение: **ничего не коммитить, не пушить, не деплоить, не менять пин**, PR не открывать. Только диагностика и отчёт.
- Секреты не выводить в лог и не писать в отчёт. Токены брать из переменных окружения и использовать как `$TOKEN`; в отчёте — только факт наличия/отсутствия.
- Не запускать длительные генерации. Для поведенческой проверки хватит одного короткого хода.

## Предусловия

```bash
export GH_TOKEN=$(security find-generic-password -s github.com -a kobzevvv -w 2>/dev/null)
[ -n "$GH_TOKEN" ] && echo "GH-токен есть" || echo "GH-ТОКЕН НЕТ — шаги с GitHub API невозможны"

RUNNER=trained-assist/ai-agent-runner
FORK=gpt-mem/opencode-mem
FRESH=7a12f66b4abc741d380af2125ef9fe4e72d43f53
```

Если GH-токена нет — отчёт `ИТОГ: BLOCKED`, и не пытаться обходить.

## Шаги

### 1. Что зашито в пин раннера (main)

```bash
gh api repos/$RUNNER/contents/.github/workflows/vm-worker-release.yml?ref=main --jq .content \
  | base64 --decode | grep -nE "OPENCODE_(RELEASE_TAG|VERSION|SOURCE_SHA|ARCHIVE_SHA256|BINARY_SHA256)"
```

Записать все пять значений.

**PASS-условие шага:** значения читаются (ровно по одному вхождению каждого поля).

### 2. Пайплайн промоушена: что он в последний раз сделал

```bash
gh run list --repo $RUNNER --workflow opencode-fork-promotion.yml --limit 8 \
  --json databaseId,conclusion,status,createdAt,event,headSha \
  --jq '.[] | "\(.createdAt) \(.event) \(.status)/\(.conclusion) run=\(.databaseId)"'
```

Для последних прогонов гейта — вытащить артефакт решения:

```bash
gh run download <run_id> --repo $RUNNER --name promotion-decision --dir /tmp/promotion-decision 2>/dev/null \
  && cat /tmp/promotion-decision/promotion-decision.json | head -40
```

Разобрать поле `outcome` и `reason`:
- `promoted` — кандидат прошёл гейт и пин переписан;
- `up-to-date` — активная сборка == последний релиз;
- `downgrade` — раннер на более новой сборке, откат запрещён;
- гейт красный — в `reason` будет причина.

**PASS-условие шага:** есть прогон, который либо промоутил, либо честно объяснил, почему не промоулил (иначе «свежесть непонятна»).

### 3. Свежесть по исходному коммиту (решающая проверка)

Взять `OPENCODE_SOURCE_SHA` из шага 1 и сравнить с `FRESH`:

```bash
PIN_SHA=$(gh api repos/$RUNNER/contents/.github/workflows/vm-worker-release.yml?ref=main --jq .content \
  | base64 --decode | awk '/OPENCODE_SOURCE_SHA:/{print $2}')
echo "pinned=$PIN_SHA fresh=$FRESH"

# потомок ли свежего коммита закреплённый?  exit 0 = да (свежо), 1 = нет (устарело)
gh api repos/$FORK/compare/$FRESH...$PIN_SHA --jq '"status=\(.status) ahead_by=\(.ahead_by) behind_by=\(.behind_by)"'
```

Интерпретация: `status` = `ahead` (пин впереди `FRESH`) ⇒ пин содержит выпил маски ⇒ **свежо**. `status` = `diverged` или `behind` ⇒ **устарело**: закреплённая сборка старше фикса.

**PASS-условие шага:** `status=ahead` (или `identical`).

### 4. Бинарный признак (решающая проверка, независимая от GitHub)

Скачать linux-бинарь **закреплённого** релиза и проверить, что в нём нет клиентского кода маски:

```bash
PIN_TAG=$(gh api repos/$RUNNER/contents/.github/workflows/vm-worker-release.yml?ref=main --jq .content \
  | base64 --decode | awk '/OPENCODE_RELEASE_TAG:/{print $2}')
PIN_ARCHIVE_SHA=$(gh api repos/$RUNNER/contents/.github/workflows/vm-worker-release.yml?ref=main --jq .content \
  | base64 --decode | awk '/OPENCODE_ARCHIVE_SHA256:/{print $2}')

mkdir -p /tmp/pincheck && cd /tmp/pincheck
gh release download "$PIN_TAG" --repo $FORK --pattern opencode-linux-x64.tar.gz --dir . || echo "СКАЧАТЬ НЕЛЬЗЯ"
echo "$PIN_ARCHIVE_SHA  opencode-linux-x64.tar.gz" | sha256sum --check --status && echo "sha256 архива: ok" || echo "sha256 архива: НЕ СОВПАДАЕТ"
tar xzf opencode-linux-x64.tar.gz
BIN=$(find . -name opencode -type f | head -1)
echo "бинарь: $BIN"
LC_ALL=C strings -a "$BIN" | grep -c "ladder_cache_variant" || true
```

Эталон, проверенный на этой машине:

| сборка | вхождений `ladder_cache_variant` в бинаре |
|---|---|
| `663876427c7b` (старая, с маской) | 2 |
| `2d96e3d9e570` (старая, с маской) | 2 |
| `7a12f66b4abc` (свежая, без маски) | 0 |
| `6d9423b15591` (свежая, без маски) | 0 |

**PASS-условие шага:** `0` вхождений ⇒ маски в закреплённом бинаре нет ⇒ сборка свежая по этому признаку. `2` (или больше) ⇒ маска в бинаре есть ⇒ сборка устаревшая.

### 5. Живой воркер: что реально запущено

Воркер отдаёт идентичность на `GET /version` (без авторизации: `/healthz` — liveness, `/version` — релиз воркера + версия/коммит/sha зашитого opencode, `/readyz` — readiness).

Эндпоинт France не лежит в репозитории открытым текстом — он в `VM_WORKER_ENDPOINTS` (JSON-массив порядка) на Runner API, в секретах воркера и в `docs/VM-WORKER-SECRET-INVENTORY.md` / `docs/CLOUDFLARE-RUNNER-API.md`. Найти можно так:

```bash
gh api repos/$RUNNER/contents/docs/VM-WORKER-SECRET-INVENTORY.md?ref=main --jq .content | base64 --decode \
  | grep -nE "https://[A-Za-z0-9._-]+(\.sslip\.io|trainedassist\.[a-z]+)" | head
# также посмотреть локальные переменные/секреты, если они есть:
env | grep -iE "VM_WORKER|WORKER_ENDPOINT" || true
```

Если эндпоинт найден:

```bash
curl -fsS --max-time 20 "$WORKER/version" | head -c 2000; echo
```

В ответе искать: версию opencode, source commit зашитого opencode и sha256 бинаря. Сравнить с пин��м из шага 1.

**PASS-условие шага:** `opencode.sourceCommit` = `FRESH` (или потомок) ⇒ воркер реально запускает свежую сборку.

Если эндпоинт недоступен/не найден — **не считать провалом**: поставить `UNKNOWN`, указать в отчёте, что живое подтверждение не получено, и опираться на шаги 3–4 (исходник + бинарь).

### 6. Поведенческая проверка через раннер (если доступен API)

Если есть API раннера и ключ с правом `runs:write` — один короткий прогон: `POST /v1/runs` (см. `docs/CLOUDFLARE-RUNNER-API.md`, порядок: Runner API → France VM → Ladder free → result callback), с задачей, которая делает вызов тула в два шага (например «вызови bash `echo probe-runner`, затем покажи результат»).

**PASS-условие шага:** прогон завершился успешно, в ответе видно `probe-runner`, в логах нет `invalid ladder_cache_variant`.

Оговорка: отсутствие 400 **не доказывает** свежесть (см. оговорку выше) — это проверка «ничего не сломалось», а не «свежая версия».

Если API/ключ недоступны — `UNKNOWN` с указанием, что для этого нужен ключ раннера.

### 7. Блокирующий разрыв: почему раннер может быть не свежим

Проверить, существует ли релиз, который промоушен-пайплайн **вообще мог бы** подхватить под нашу свежую ревизию:

```bash
gh api "repos/$FORK/releases?per_page=100" --jq '.[] | select(.draft|not)
  | "\(.tag_name)  target=\(.target_commitish)  assets=\([.assets[].name]|join(","))"' | head -25
```

Ищем: тег по `^mem-preview-\d{8}-[A-Za-z0-9.-]+$`, `target_commitish` = `7a12f66b4abc741d380af2125ef9fe4e72d43f53`, ассеты `opencode-linux-x64.tar.gz` + `opencode-linux-x64.tar.gz.sha256`.

**PASS-условие шага:** такой релиз существует. Если нет — это и есть корень расхождения; перечислить в отчёте ровно чего не хватает:

1. релиз в `gpt-mem/opencode-mem` с тегом `mem-preview-<YYYYMMDD>-<суффикс>` (не `mem-v...` — детектор такие игнорирует);
2. `target_commitish` = полный SHA `7a12f66b4abc741d380af2125ef9fe4e72d43f53`;
3. ассет `opencode-linux-x64.tar.gz` (наша текущая цепочка публикует только darwin-архив — linux-x64 нужно собрать отдельно) и `.sha256` рядом;
4. опубликованный GitHub дайджест архива (`sha256:...` в `assets[].digest`) — его требует `opencode-promotion-candidate.mjs`;
5. после этого — прогон гейта (`workflow_dispatch` с `candidate_tag` / `candidate_source` / `candidate_archive_sha256` либо ожидание крона `41 */6 * * *`), успех гейта, PR промоушена с переписанным пином, merge, новый релиз воркера и деплой.

## Критерии приёмки (сводно)

| # | Проверка | PASS-условие | иначе |
|---|---|---|---|
| 1 | Пин читается | 5 полей `OPENCODE_*` | BLOCKED |
| 2 | Промоушен отработал | есть `promoted` / `up-to-date` / `downgrade` с внятным `reason` | UNKNOWN |
| 3 | Свежесть по коммиту | `compare` = `ahead`/`identical` | **FAIL: устарело** |
| 4 | Бинарный признак | 0 вхождений `ladder_cache_variant` | **FAIL: маска в бинаре** |
| 5 | Живой воркер | `opencode.sourceCommit` = `FRESH` | UNKNOWN (нет эндпоинта) |
| 6 | Поведение через API | прогон успешен, `probe-runner` виден | UNKNOWN (нет ключа) |
| 7 | Разрыв | есть `mem-preview-*` релиз под `FRESH` с linux-x64 | **FAIL: разрыв, перечислить п.1–5** |

**Итог:**
- `ИТОГ: PASS` — шаги 3, 4, 7 зелёные (это про свежесть сборки), шаг 5 подтверждает живую выдачу, 6 — успех.
- `ИТОГ: FAIL (раннер запускает устаревшую сборку)` — шаг 3 или 4 красные; обязательно приложить шаг 7 с точным списком недостающего.
- `ИТОГ: BLOCKED` — нет GH-токена.

## Если проверка упала

1. Не чинить, не деплоить. Только диагностика.
2. Сверить, что в форке вообще есть коммит `7a12f66b4abc741d380af2125ef9fe4e72d43f53` в ветке `v2-base`:
   `gh api repos/$FORK/commits/7a12f66b4abc741d380af2125ef9fe4e72d43f53 --jq .sha`
3. Проверить, не откатывал ли пин кто-то вручную: `gh pr list --repo $RUNNER --state all --limit 20 --search "opencode" --json number,state,title,mergedAt`.
4. Посмотреть решения гейта: `scripts/opencode-promotion-gate.mjs`, `scripts/opencode-release-identity.mjs`, `scripts/assert-opencode-release-freshness.mjs` в `main` раннера — там видно, что именно проверяется.
5. В отчёте указать, что нужно для исправления, отдельным разделом «Что требуется» (без выполнения).

## Формат отчёта

1. Первая строка: `ИТОГ: PASS` / `ИТОГ: FAIL (N из M)` / `ИТОГ: BLOCKED (причина)`.
2. Таблица: № | проверка | факт (значения, числа, версии) | PASS/FAIL/UNKNOWN | комментарий.
3. Отдельно — **фактическая идентичность opencode в раннере**: тег, версия, source commit, sha256 бинаря (из пина и, если получилось, из живого `/version`).
4. Отдельно — **сравнение с нашей свежей сборкой**: `FRESH` = `7a12f66b4abc741d380af2125ef9fe4e72d43f53`, совпадает / не совпадает, чем отличается.
5. Отдельно — **«Что требуется»**: конкретный список шагов (релиз → ассеты → гейт → PR → merge → релиз воркера → деплой), если раннер не свежий.
6. Секреты, ключи и полные тела запросов в отчёте не приводить.

Если все зелёные — отчёт короткий: итог, таблица, идентичность, одна строка «разрыва нет».
