#!/usr/bin/env python3
"""
Детектор новых релизов апстрима — дешёвый шаг перед opencode-сессией.

Что делает:
  1. находит в апстриме теги линии v2.*, которых ещё не обрабатывали;
  2. собирает сырьё: коммиты диапазона, связанные PR, изменённые файлы;
  3. кладёт это в JSON — его читает opencode-сессия (этап «изучить»).

Чего этот скрипт НЕ делает: не судит, что для нас полезно, не пишет отчёт и не
заводит issue — это работа opencode (chain/prompt-upstream-study.txt). Здесь только
факты, поэтому шаг можно гонять без модели и не тратить токены впустую.

Запуск: chain/run-upstream-collect.sh
Окружение:
  UPSTREAM_BASE_TAG  — переопределить базу (например, чтобы переразобрать старее);
  UPSTREAM_DRY_RUN=1 — только разбор, ничего не писать в GitHub;
  GH_TOKEN           — если нет, берётся из локального keychain.
"""

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

GH = os.environ.get("GH_BIN", "gh")
SCRIPTS = os.path.expanduser("~/.opencode/scripts")
STATE_DIR = os.path.join(SCRIPTS, "upstream-watch")
STATE_PATH = os.path.join(STATE_DIR, "state.json")
COLLECT_DIR = os.path.join(STATE_DIR, "collected")
ARCH = "/Users/vova/opencode-mem-architecture"
POLICY_PATH = os.environ.get(
    "UPSTREAM_POLICY", os.path.join(ARCH, "chain", "upstream-policy.json")
)


def log(msg: str) -> None:
    print(f"[{datetime.now().strftime('%F %T')}] {msg}", flush=True)


def gh_api(path: str, method: str = "GET", params=None):
    """gh api → JSON. Ошибка — исключение с коротким текстом stderr."""
    cmd = [GH, "api", path]
    # gh трактует наличие -f как переключение на POST: для GET параметры надо
    # отправлять явно через --method GET, иначе search-эндпоинты отдают 404.
    if method != "GET" or params:
        cmd += ["--method", method]
    for key, value in (params or {}).items():
        cmd += ["-f", f"{key}={value}"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        err = (res.stderr or res.stdout or "").strip().splitlines()
        raise RuntimeError(f"gh api {path} → {err[-1] if err else 'ошибка'}")
    if not res.stdout.strip():
        return None
    return json.loads(res.stdout)


def semver_key(tag: str):
    """Сортировка тегов v2.0.32 > v2.0.9 > v2.0.10 (точками, не как строки)."""
    m = re.match(r"^v?(\d+)\.(\d+)\.(\d+)", tag)
    if not m:
        return (0, 0, 0)
    return tuple(int(x) for x in m.groups())


def tag_ref_commit(repo: str, ref_sha: str, ref_type: str) -> str:
    """Annotated tag → коммит; иначе ref_sha уже коммит."""
    if ref_type == "tag":
        return gh_api(f"repos/{repo}/git/tags/{ref_sha}")["object"]["sha"]
    return ref_sha


def upstream_tags(repo: str, prefix: str):
    """Все теги с префиксом: {tag: {sha, type}} — один вызов matching-refs."""
    out = {}
    page = 1
    while True:
        refs = gh_api(f"repos/{repo}/git/matching-refs/tags/{prefix}?per_page=100&page={page}") or []
        if not refs:
            break
        for r in refs:
            name = r["ref"].split("/")[-1]
            out[name] = {"sha": r["object"]["sha"], "type": r["object"]["type"]}
        if len(refs) < 100:
            break
        page += 1
    return out


def load_state() -> dict:
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH) as f:
            return json.load(f)
    return {"tags": {}}


def save_state(state: dict) -> None:
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_PATH + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
    os.replace(tmp, STATE_PATH)


def resolve_fork_base(policy: dict, state: dict, tags: dict):
    """
    База форка = самый новый тег апстрима, который форк уже содержит.
    Проверка: compare <sha>...v2-base в репозитории форка → ahead/identical.
    """
    fork_repo = policy["fork_repo"]
    branch = policy["fork_branch"]
    up_repo = policy["upstream_repo"]
    fork_head = gh_api(f"repos/{fork_repo}/commits/{branch}")["sha"]

    cached_sha = state.get("base_sha")
    if cached_sha:
        try:
            cmp = gh_api(f"repos/{fork_repo}/compare/{cached_sha}...{branch}")
            if cmp.get("status") in ("ahead", "identical"):
                log(f"база из кэша: {state.get('base_tag')} ({cached_sha[:12]})")
                return cached_sha, state.get("base_tag"), fork_head
        except RuntimeError:
            log("кэш базы не сходится — пересчитываю")

    for tag in sorted(tags.keys(), key=semver_key, reverse=True):
        # Тег и его объект живут в апстриме; в форке проверяем уже коммит.
        sha = tag_ref_commit(up_repo, tags[tag]["sha"], tags[tag]["type"])
        try:
            cmp = gh_api(f"repos/{fork_repo}/compare/{sha}...{branch}")
        except RuntimeError:
            continue
        if cmp.get("status") in ("ahead", "identical"):
            log(f"база найдена: {tag} ({sha[:12]})")
            return sha, tag, fork_head
    raise RuntimeError("не нашёл тег апстрима, который содержит форк")


def fork_divergence(fork_repo: str, upstream_repo: str, base_sha: str, fork_head: str):
    """
    Наши коммиты и файлы, в которых форк разошёлся с апстримом.
    Считаем по merge-base с апстримным HEAD: compare-по-файлам обрезается на
    300 файлах и включает общие изменения — это портит картину.
    """
    try:
        cmp = gh_api(f"repos/{upstream_repo}/compare/{fork_head}...HEAD")
    except RuntimeError:
        cmp = {}
    mb = (cmp.get("merge_base_commit") or {}).get("sha") or base_sha
    side = gh_api(f"repos/{fork_repo}/compare/{mb}...{fork_head}")
    files = set()
    for c in side.get("commits", []):
        try:
            detail = gh_api(f"repos/{fork_repo}/commits/{c['sha']}")
            files.update(f["filename"] for f in detail.get("files", []))
        except RuntimeError:
            pass
    log(
        f"merge-base: {mb[:12]}, наших коммитов: {len(side.get('commits', []))}, "
        f"файлов расхождения: {len(files)}"
    )
    return files, mb, side.get("commits", [])


def collect_range(policy: dict, base_sha: str, tag: str, tag_sha: str, diverged: set):
    """Сырьё по диапазону base..tag: коммиты, PR, файлы — без суждений."""
    up = policy["upstream_repo"]
    cmp = gh_api(f"repos/{up}/compare/{base_sha}...{tag_sha}")
    commits = cmp.get("commits", [])
    total = cmp.get("total_commits", len(commits))
    cap = policy.get("max_commits_to_classify", 200)
    truncated = total > len(commits) or len(commits) > cap
    commits = commits[:cap]

    pr_numbers = []
    items = []
    for c in commits:
        sha = c["sha"]
        subject = c["commit"]["message"].splitlines()[0]
        m = re.search(r"#(\d+)", subject)
        pr_no = int(m.group(1)) if m else None
        if pr_no and pr_no not in pr_numbers:
            pr_numbers.append(pr_no)
        files = []
        try:
            detail = gh_api(f"repos/{up}/commits/{sha}")
            files = [f["filename"] for f in detail.get("files", [])]
        except RuntimeError:
            pass
        items.append(
            {
                "sha": sha,
                "subject": subject,
                "pr": pr_no,
                "files": files,
                "touches_our_divergence": sorted(f for f in files if f in diverged),
            }
        )

    prs = []
    for n in pr_numbers[: policy.get("max_prs_to_fetch", 60)]:
        try:
            pr = gh_api(f"repos/{up}/pulls/{n}")
            prs.append(
                {
                    "number": n,
                    "title": pr.get("title", ""),
                    "url": pr.get("html_url", ""),
                    "merged_at": pr.get("merged_at"),
                    "labels": [lb.get("name") for lb in pr.get("labels", [])],
                }
            )
        except RuntimeError:
            prs.append({"number": n, "title": "", "url": "", "merged_at": None, "labels": []})

    return {
        "tag": tag,
        "tag_sha": tag_sha,
        "base_sha": base_sha,
        "upstream_repo": up,
        "fork_repo": policy["fork_repo"],
        "fork_branch": policy["fork_branch"],
        "collected_at": datetime.now(timezone.utc).isoformat(),
        "total_commits": total,
        "collected_commits": len(items),
        "truncated": truncated,
        "commits": items,
        "pull_requests": prs,
        "our_diverged_files": sorted(diverged),
    }


def main() -> int:
    with open(POLICY_PATH) as f:
        policy = json.load(f)

    os.makedirs(COLLECT_DIR, exist_ok=True)
    state = load_state()

    up = policy["upstream_repo"]
    tags = upstream_tags(up, policy["tag_prefix"].rstrip("."))
    log(f"тегов апстрима в линии {policy['tag_prefix']}: {len(tags)}")

    base_sha, base_tag, fork_head = resolve_fork_base(policy, state, tags)
    state["base_sha"] = base_sha
    state["base_tag"] = base_tag
    state["fork_head"] = fork_head
    state["checked_at"] = datetime.now(timezone.utc).isoformat()

    forced = os.environ.get("UPSTREAM_BASE_TAG")
    if forced and forced in tags:
        base_sha = tag_ref_commit(up, tags[forced]["sha"], tags[forced]["type"])
        base_tag = forced
        log(f"база переопределена: {forced}")

    known = set(state.get("tags", {}).keys())
    new_tags = [
        t
        for t in sorted(tags.keys(), key=semver_key, reverse=True)
        if t not in known and semver_key(t) > semver_key(base_tag)
    ]

    if not new_tags:
        log("новых релизов нет — opencode-сессию не запускаем (экономим токены)")
        save_state(state)
        print("STATUS=up-to-date")
        print("NEW_TAGS=")
        return 0

    log(f"новые релизы: {', '.join(new_tags)}")
    diverged, merge_base, our_commits = fork_divergence(
        policy["fork_repo"], policy["upstream_repo"], base_sha, fork_head
    )

    for tag in sorted(new_tags, key=semver_key):
        sha = tag_ref_commit(up, tags[tag]["sha"], tags[tag]["type"])
        log(f"собираю диапазон {base_tag}..{tag}…")
        data = collect_range(policy, base_sha, tag, sha, diverged)
        data["merge_base"] = merge_base
        data["our_commits"] = [
            {"sha": c["sha"], "subject": c["commit"]["message"].splitlines()[0]}
            for c in our_commits
        ]
        path = os.path.join(COLLECT_DIR, f"{tag}.json")
        with open(path, "w") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        log(
            f"{tag}: коммитов {data['collected_commits']} из {data['total_commits']}, "
            f"PR {len(data['pull_requests'])}, файлов расхождения {len(diverged)}"
        )
        state.setdefault("tags", {}).setdefault(tag, {})
        state["tags"][tag].update({"sha": sha, "collected": path, "collected_at": data["collected_at"]})
        print(f"COLLECTED={path}")

    state["last_tag"] = sorted(new_tags, key=semver_key)[-1]
    save_state(state)
    print("STATUS=collected")
    print("NEW_TAGS=" + ",".join(sorted(new_tags, key=semver_key)))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # noqa: BLE001 — детектор не должен ронять пайплайн молча
        log(f"ОШИБКА: {exc}")
        print("STATUS=error")
        sys.exit(1)
