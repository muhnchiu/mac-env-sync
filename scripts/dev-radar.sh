#!/bin/bash
# dev-radar.sh —— 每日开发者效率情报抓取
#
# 用法:
#   dev-radar.sh                        # 只抓取（默认）
#
# 数据源（每段独立容错，任一失败不影响其余）:
#   1. VS Code Marketplace 热门扩展（trending）
#   2. GitHub Trending（开发者工具/CLI/shell 相关，近7天）
#   3. Hacker News（developer/coding/CLI 标签搜索）
#   4. Hacker News Show HN（开发工具方向）
#   5. npm trending（下载量增长，开发者工具包）
#   6. Claude Code / Cursor / Copilot 更新动态（RSS/blog）
#
# 输出:
#   ~/.local/state/dev-radar/YYYY-MM-DD.md           抓取数据（结构化 markdown）
#   ~/.local/state/dev-radar/dev-radar.log            运行日志
#
# 依赖: curl / python3
# 代理: 默认 127.0.0.1:7897（GitHub/HN 为国际源）；RADAR_NO_PROXY=1 关闭
# 定时: OpenClaw cron 每天 09:00（agent 抓取后自行分析）

RADAR_DIR="$HOME/.local/state/dev-radar"
TODAY=$(date +%F)
OUT="$RADAR_DIR/$TODAY.md"
LOG="$RADAR_DIR/dev-radar.log"
PROXY="http://127.0.0.1:7897"
[[ "$RADAR_NO_PROXY" == "1" ]] && PROXY=""

MISE_BIN="$(command -v mise || echo /opt/homebrew/bin/mise)"
mkdir -p "$RADAR_DIR"
exec >>"$LOG" 2>&1
echo "===== dev-radar $TODAY $(date +%T) ====="

fetch() { curl -sS --max-time 25 ${PROXY:+--proxy "$PROXY"} "$1" 2>/dev/null; }

{
  echo "# 开发者效率雷达 $TODAY"
  echo
  echo "> dev-radar.sh 抓取；分析版见 ${TODAY}-analysis.md；归档：mac-env-sync/docs/radar-reports/dev/"
  echo

  # 1. GitHub Trending（开发者工具/CLI/shell，近7天，按星标）
  echo "## GitHub 新开发者工具仓库（近7天，星标排序）"
  SINCE7=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "-7 days" +%Y-%m-%d)
  GH_URL="https://api.github.com/search/repositories?q=created:%3E${SINCE7}+cli+OR+terminal+OR+developer-tools+OR+coding+OR+shell+OR+devtools&sort=stars&order=desc&per_page=15"
  if fetch "$GH_URL" > /tmp/devradar-gh.json 2>/dev/null && [[ -s /tmp/devradar-gh.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/devradar-gh.json'))
    for r in d.get('items', [])[:15]:
        name = r.get('full_name', '')
        stars = r.get('stargazers_count', 0)
        desc = (r.get('description') or '')[:70]
        lang = r.get('language', '') or ''
        print(f"- {name} ({stars} stars, {lang}) | {desc}")
    if not d.get('items'):
        print("（无数据）")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 2. Hacker News — developer/coding/CLI 话题
  echo "## Hacker News 开发者话题"
  if fetch "https://hn.algolia.com/api/v1/search?tags=story&query=developer+OR+coding+OR+CLI+OR+terminal+OR+IDE&hitsPerPage=15" > /tmp/devradar-hn.json 2>/dev/null && [[ -s /tmp/devradar-hn.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/devradar-hn.json'))
    for h in d.get('hits', [])[:15]:
        title = h.get('title') or ''
        url = h.get('url') or f"https://news.ycombinator.com/item?id={h.get('objectID')}"
        pts = h.get('points') or 0
        comments = h.get('num_comments') or 0
        if title:
            print(f"- {title} [{pts}分/{comments}评]")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 3. Hacker News Show HN — 开发工具方向
  echo "## Hacker News Show HN（近24h 新品）"
  if fetch "https://hn.algolia.com/api/v1/search_by_date?tags=show_hn&hitsPerPage=20" > /tmp/devradar-shn.json 2>/dev/null && [[ -s /tmp/devradar-shn.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/devradar-shn.json'))
    for h in d.get('hits', [])[:20]:
        title = h.get('title') or ''
        pts = h.get('points') or 0
        if title and pts > 0:
            print(f"- {title} [{pts}分]")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 4. npm 包下载量增长（开发者工具相关，对比本周 vs 上周）
  echo "## npm 开发者工具包下载趋势"
  # Pick interesting dev tool packages
  NPM_PACKAGES="typescript prettier eslint vite esbuild vitest jest playwright @biomejs/biome tsx zx commander"
  LAST_WEEK_END=$(date -u -v-7d +%Y-%m-%d 2>/dev/null || date -u -d "-7 days" +%Y-%m-%d)
  THIS_WEEK_END=$(date -u +%Y-%m-%d)
  LAST_WEEK_START=$(date -u -v-14d +%Y-%m-%d 2>/dev/null || date -u -d "-14 days" +%Y-%m-%d)
  echo "对比: $LAST_WEEK_START ~ $LAST_WEEK_END vs $LAST_WEEK_END ~ $THIS_WEEK_END"
  echo
  for pkg in $NPM_PACKAGES; do
    # npm API: downloads in date range
    URL1="https://api.npmjs.org/downloads/point/$LAST_WEEK_START:$LAST_WEEK_END/$pkg"
    URL2="https://api.npmjs.org/downloads/point/$LAST_WEEK_END:$THIS_WEEK_END/$pkg"
    dl1=$(fetch "$URL1" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('downloads',0))" 2>/dev/null || echo 0)
    dl2=$(fetch "$URL2" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('downloads',0))" 2>/dev/null || echo 0)
    if [[ "$dl1" -gt 0 ]]; then
      change=$(python3 -c "print(f'{(($dl2 - $dl1) / $dl1 * 100):+.1f}%')" 2>/dev/null || echo "?")
      echo "- $pkg: 本周 $dl2 vs 上周 $dl1 ($change)"
    fi
  done
  echo

  # 5. VS Code trending extensions（通过 marketplace API）
  echo "## VS Code Marketplace 热门扩展"
  # VS Code marketplace search API - trending
  VS_API="https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
  if fetch -X POST "$VS_API" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json;api-version=6.1-preview.1" \
    -d '{"filters":[{"criteria":[{"filterType":12,"value":"trending"}],"direction":2,"pageSize":15,"pageNumber":1,"sortBy":4}],"assetTypes":[]}' > /tmp/devradar-vs.json 2>/dev/null && [[ -s /tmp/devradar-vs.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/devradar-vs.json'))
    results = d.get('results', [{}])
    if results:
        exts = results[0].get('extensions', [])
        for e in exts[:15]:
            name = e.get('displayName', '') or e.get('extensionName', '')
            pub = e.get('publisher', {}).get('displayName', '') or e.get('publisher', {}).get('publisherName', '')
            desc = (e.get('shortDescription') or '')[:60]
            inst = 0
            stats = e.get('statistics', [])
            for s in stats:
                if s.get('statisticName') == 'install':
                    inst = s.get('value', 0)
            print(f"- {pub}.{name} ({inst:,} installs) | {desc}")
    else:
        print("（无数据）")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 6. Claude Code / Cursor 更新（通过 GitHub releases）
  echo "## AI 编程工具更新（GitHub Releases）"
  for repo in "anthropics/claude-code" "getcursor/cursor" "openai/openai-copilot"; do
    echo "### $repo"
    if fetch "https://api.github.com/repos/$repo/releases?per_page=3" > /tmp/devradar-rel.json 2>/dev/null && [[ -s /tmp/devradar-rel.json ]]; then
      python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/devradar-rel.json'))
    if isinstance(d, list):
        for r in d[:3]:
            tag = r.get('tag_name', '')
            date = (r.get('published_at') or '')[:10]
            name = (r.get('name') or '')[:60]
            print(f"- {tag} ({date}) | {name}")
    else:
        print("（无 releases）")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
    else
      echo "（抓取失败或仓库不存在）"
    fi
    echo
  done

} > "$OUT"

echo "抓取完成: $OUT ($(wc -l < "$OUT" | tr -d ' ') 行)"
echo "===== done $(date +%T) ====="
