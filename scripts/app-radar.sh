#!/bin/bash
# app-radar.sh —— 每日软件情报抓取 + openclaw 分析
#
# 用法:
#   app-radar.sh                        # 抓取 + 分析（默认）
#   RADAR_NO_ANALYZE=1 ./app-radar.sh  # 只抓取不分析
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
#   ~/.local/state/app-radar/YYYY-MM-DD-analysis.md  openclaw 分析结果
#   ~/.local/state/app-radar/app-radar.log           运行日志
#
# 依赖: curl / python3 / mise(->node->openclaw，仅分析阶段需要)
# 代理: 默认 127.0.0.1:7897（HN/PH 为国际源）；RADAR_NO_PROXY=1 关闭
# 定时: ~/Library/LaunchAgents/com.qiuwenbo.app-radar.plist 每天 08:30

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

# ---------- 分析阶段（openclaw，可跳过） ----------
# RADAR_AGENT 默认 main（openclaw agents list 可查）；RADAR_MODEL 可临时换模型
if [[ "$RADAR_NO_ANALYZE" != "1" ]]; then
  PROMPT_FILE="$RADAR_DIR/prompt-$TODAY.md"   # 勿用点开头文件名（openclaw 曾误报非 UTF-8）
  cat > "$PROMPT_FILE" <<EOF
你是我的软件雷达分析员。今天是 $TODAY。

请阅读今日抓取数据：$OUT
并对照我的三机软件台账：$HOME/workspace/mac-env-sync/docs/manuals/app-inventory.md（6 大类，含已装清单与已退役记录）

输出一份 markdown 日报，要求：
1. 【今日最值得关注】挑 5-10 条，偏好：开发者工具、开源、免费、有官方 brew cask 的 macOS 软件
2. 每条给：一句话价值判断 + 是否有官方 cask（token 名，可验证）
3. 【与已装重复】对照台账，指出哪些新品与我已装软件功能重叠、是否值得替换
4. 【建议动作】哪些值得我按"台账→Brewfile→push"流程收编试用
语言用中文，直接输出日报正文，不要寒暄。
EOF
  OPENCLAW_ARGS=(agent --agent "${RADAR_AGENT:-main}" --message-file "$PROMPT_FILE")
  [[ -n "$RADAR_MODEL" ]] && OPENCLAW_ARGS+=(--model "$RADAR_MODEL")
  if "$MISE_BIN" exec node -- openclaw "${OPENCLAW_ARGS[@]}" > "$ANALYSIS.raw" 2>"$RADAR_DIR/openclaw-stderr.log"; then
    python3 - "$ANALYSIS.raw" "$ANALYSIS" <<'PYEOF'
import sys, json
raw = open(sys.argv[1]).read()
try:
    d = json.loads(raw)
    text = d.get("reply") or d.get("text") or d.get("message") or ""
except Exception:
    text = raw
open(sys.argv[2], "w").write(text if text.strip() else raw)
PYEOF
    echo "分析完成: $ANALYSIS ($(wc -c < "$ANALYSIS" | tr -d ' ') 字节)"
  else
    echo "⚠ openclaw 分析失败（gateway 未运行或未配置路由？），跳过。stderr 见 $RADAR_DIR/openclaw-stderr.log"
  fi
  rm -f "$PROMPT_FILE"
fi

echo "===== done $(date +%T) ====="
