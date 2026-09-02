#!/bin/bash
# app-radar.sh —— 每日软件情报抓取
#
# 用法:
#   app-radar.sh                        # 只抓取（默认）
#   RADAR_NO_ANALYZE=0 ./app-radar.sh  # 抓取 + 内嵌分析（不推荐，慢）
#
# 数据源（每段独立容错，任一失败不影响其余）:
#   1. Hacker News 首页（Algolia API）
#   2. HN 当日 Show HN（Algolia API）
#   3. Product Hunt 当日榜（RSS）
#   4. 少数派 sspai.com（RSS）
#   5. 小众软件 appinn.com（RSS）
#
# 输出:
#   ~/.local/state/app-radar/YYYY-MM-DD.md           抓取数据（结构化 markdown）
#   ~/.local/state/app-radar/app-radar.log           运行日志
#
# 依赖: curl / python3
# 代理: 默认 127.0.0.1:7897（HN/PH 为国际源）；RADAR_NO_PROXY=1 关闭
# 定时: OpenClaw cron 每天 08:30（job app-radar-daily-v2，agent 抓取后自行分析）

RADAR_DIR="$HOME/.local/state/app-radar"
TODAY=$(date +%F)
OUT="$RADAR_DIR/$TODAY.md"
ANALYSIS="$RADAR_DIR/$TODAY-analysis.md"
LOG="$RADAR_DIR/app-radar.log"
PROXY="http://127.0.0.1:7897"
[[ "$RADAR_NO_PROXY" == "1" ]] && PROXY=""

# launchd 环境无用户 PATH，显式解析 mise
MISE_BIN="$(command -v mise || echo /opt/homebrew/bin/mise)"
mkdir -p "$RADAR_DIR"
exec >>"$LOG" 2>&1
echo "===== app-radar $TODAY $(date +%T) ====="

fetch() { curl -sS --max-time 25 ${PROXY:+--proxy "$PROXY"} "$1" 2>/dev/null; }

# parse <hn|rss> <源名> <URL> —— 抓取落临时文件，python3 解析为 markdown 段
parse() {
  local kind="$1" name="$2" url="$3" tmp
  tmp=$(mktemp) || return 1
  if ! fetch "$url" > "$tmp" || [[ ! -s "$tmp" ]]; then
    printf '## %s\n\n（抓取失败）\n' "$name"
    rm -f "$tmp"; return 0
  fi
  python3 - "$kind" "$name" "$tmp" <<'PYEOF'
import sys, json, re, html
import xml.etree.ElementTree as ET

kind, name, path = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(path, encoding="utf-8", errors="replace").read()
out = ["## " + name, ""]

def clean(s, n=140):
    s = re.sub(r"<[^>]+>", "", s or "")
    s = html.unescape(s).strip().replace("\n", " ")
    return s[:n] + ("…" if len(s) > n else "")

def emit(t, l, extra=""):
    if t and l:
        line = f"- [{html.unescape(t)}]({l})"
        if extra: line += " — " + extra
        out.append(line)

try:
    if kind == "hn":
        for h in json.loads(data).get("hits", [])[:25]:
            url = h.get("url") or f"https://news.ycombinator.com/item?id={h.get('objectID')}"
            emit(h.get("title"), url, f"{h.get('points') or 0}分/{h.get('num_comments') or 0}评")
    else:
        root = ET.fromstring(data)
        ATOM = "{http://www.w3.org/2005/Atom}"
        nodes = list(root.iter("item")) or list(root.iter(ATOM + "entry"))
        for it in nodes[:20]:
            t = it.findtext("title") or it.findtext(ATOM + "title") or ""
            l = it.findtext("link") or ""
            if not l:
                le = it.find(ATOM + "link")
                l = le.get("href") if le is not None else ""
            d_ = it.findtext("description") or it.findtext(ATOM + "summary") or ""
            emit(t, l, clean(d_))
except Exception as e:
    out.append(f"（解析失败: {e}）")

print("\n".join(out))
PYEOF
  rm -f "$tmp"
}

{
  echo "# 软件雷达 $TODAY"
  echo
  echo "> app-radar.sh 抓取；分析版见 ${TODAY}-analysis.md；台账：mac-env-sync/docs/manuals/app-inventory.md"
  echo
  parse hn "Hacker News 首页" "https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=25"
  echo
  parse hn "HN Show HN（近24h 新品）" "https://hn.algolia.com/api/v1/search_by_date?tags=show_hn&hitsPerPage=25"
  echo
  parse rss "Product Hunt 今日" "https://www.producthunt.com/feed"
  echo
  parse rss "少数派" "https://sspai.com/feed"
  echo
  parse rss "小众软件" "https://www.appinn.com/feed/"
} > "$OUT"

echo "抓取完成: $OUT ($(wc -l < "$OUT" | tr -d ' ') 行)"

# 默认只抓取不内嵌分析（嵌套 openclaw agent CLI 会新建完整会话，极慢）
RADAR_NO_ANALYZE=${RADAR_NO_ANALYZE:-1}

echo "===== done $(date +%T) ====="
# 分析由 cron agent 在会话内完成（脚本只负责抓取 + 推送归档）
