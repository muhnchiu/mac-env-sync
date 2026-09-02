#!/bin/bash
# ai-radar.sh —— 每日 AI 模型与工具情报抓取 + openclaw 分析
#
# 用法:
#   ai-radar.sh                        # 抓取 + 分析（默认）
#   RADAR_NO_ANALYZE=1 ./ai-radar.sh  # 只抓取不分析
#
# 数据源（每段独立容错，任一失败不影响其余）:
#   1. Hugging Face Papers（当日热门论文，标题+作者）
#   2. Hugging Face 模型榜（sort=downloads，热门开源模型）
#   3. GitHub 新 AI/LLM 仓库（created:近7天，sort=stars）
#   4. OpenRouter 模型列表（重点筛免费模型）
#   5. TechCrunch AI 频道（RSS）
#   6. arXiv cs.LG 最新论文（RSS，LLM/深度学习）
#
# 输出:
#   ~/.local/state/ai-radar/YYYY-MM-DD.md           抓取数据（结构化 markdown）
#   ~/.local/state/ai-radar/YYYY-MM-DD-analysis.md  openclaw 分析结果
#   ~/.local/state/ai-radar/ai-radar.log           运行日志
#
# 依赖: curl / python3（分析由 OpenClaw cron agent 在会话内完成，不再内嵌 CLI 嵌套会话）
# 代理: 默认 127.0.0.1:7897（HN/HF 为国际源）；RADAR_NO_PROXY=1 关闭
# 定时: OpenClaw cron 每天 08:45（job ai-radar-daily，agent 抓取后自行分析）

# 默认只抓取不内嵌分析（嵌套 openclaw agent CLI 会新建完整会话，极慢）
RADAR_NO_ANALYZE=${RADAR_NO_ANALYZE:-1}

RADAR_DIR="$HOME/.local/state/ai-radar"
TODAY=$(date +%F)
OUT="$RADAR_DIR/$TODAY.md"
ANALYSIS="$RADAR_DIR/$TODAY-analysis.md"
LOG="$RADAR_DIR/ai-radar.log"
PROXY="http://127.0.0.1:7897"
[[ "$RADAR_NO_PROXY" == "1" ]] && PROXY=""

# launchd 环境无用户 PATH，显式解析 mise
MISE_BIN="$(command -v mise || echo /opt/homebrew/bin/mise)"
mkdir -p "$RADAR_DIR"
exec >>"$LOG" 2>&1
echo "===== ai-radar $TODAY $(date +%T) ====="

fetch() { curl -sS --max-time 25 ${PROXY:+--proxy "$PROXY"} "$1" 2>/dev/null; }

# ---------- 各数据源抓取（每段独立容错） ----------
{
  echo "# AI 模型与工具雷达 $TODAY"
  echo
  echo "> ai-radar.sh 抓取；分析版见 ${TODAY}-analysis.md；归档：mac-env-sync/docs/radar-reports/ai/"
  echo

  # 1. Hugging Face Papers
  echo "## Hugging Face Papers（今日热门）"
  if fetch "https://huggingface.co/api/papers?limit=10" > /tmp/airadar-hfp.json 2>/dev/null && [[ -s /tmp/airadar-hfp.json ]]; then
    python3 - <<'PYEOF'
import json, re
try:
    d = json.load(open('/tmp/airadar-hfp.json'))
    papers = d if isinstance(d, list) else d.get('papers', [])
    if not papers:
        print("（无数据）")
    for p in papers[:10]:
        title = p.get('title', '')
        authors = ', '.join(a['name'] for a in p.get('authors', [])[:5])
        print(f"- {title} — {authors}")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 2. Hugging Face 热门模型
  echo "## Hugging Face 热门模型（近30天下载量）"
  if fetch "https://huggingface.co/api/models?limit=30&full=true" > /tmp/airadar-hfm.json 2>/dev/null && [[ -s /tmp/airadar-hfm.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/airadar-hfm.json'))
    if not isinstance(d, list):
        print("（无数据）")
    else:
        for m in d[:20]:
            created = m.get('createdAt', '') or ''
            dt = created[:10][5:] if len(created) >= 10 else '?'  # 取 MM-DD
            mid = m.get('modelId', '') or m.get('id', '')
            dl = m.get('downloads', 0)
            tags = m.get('pipeline_tag', '-')
            print(f"- {dt} | {mid} | {tags} | {dl} 下载")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 3. GitHub 新 AI 仓库
  echo "## GitHub 新 AI 仓库（近7天，星标排序）"
  SINCE7=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d "-7 days" +%Y-%m-%d)
  if fetch "https://api.github.com/search/repositories?q=created:%3E${SINCE7}+ai+OR+llm+OR+gpt&sort=stars&order=desc&per_page=10" > /tmp/airadar-gh.json 2>/dev/null && [[ -s /tmp/airadar-gh.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/airadar-gh.json'))
    for r in d.get('items', [])[:10]:
        name = r.get('full_name', '')
        stars = r.get('stargazers_count', 0)
        desc = (r.get('description') or '')[:60]
        print(f"- {name} ⭐{stars} | {desc}")
    if not d.get('items'):
        print("（无数据）")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 4. OpenRouter 模型列表（筛免费）
  echo "## OpenRouter 免费模型（最新）"
  if fetch "https://openrouter.ai/api/v1/models" > /tmp/airadar-or.json 2>/dev/null && [[ -s /tmp/airadar-or.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/airadar-or.json'))
    models = d.get('data', [])
    free = [m for m in models if ':free' in m.get('id', '')]
    # 只看免费的，且按 name 排序取前 15
    seen = set()
    out = []
    for m in free[:20]:
        mid = m.get('id', '')
        if mid in seen: continue
        seen.add(mid)
        out.append(f"- {mid} | {m.get('name', '')}")
    if out:
        for line in out[:15]: print(line)
    else:
        print("（今日无新免费模型）")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 5. TechCrunch AI 频道
  echo "## TechCrunch AI 频道"
  if fetch "https://techcrunch.com/category/artificial-intelligence/feed/" > /tmp/airadar-tc.xml 2>/dev/null && [[ -s /tmp/airadar-tc.xml ]]; then
    python3 - <<'PYEOF'
import xml.etree.ElementTree as ET
try:
    root = ET.fromstring(open('/tmp/airadar-tc.xml', encoding='utf-8', errors='replace').read())
    for item in list(root.iter('item'))[:10]:
        t = item.findtext('title', '')
        d = (item.findtext('pubDate', '') or '')[:16]
        if t: print(f"- {t} [ {d} ]")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 6. arXiv cs.LG 最新
  echo "## arXiv cs.LG 最新论文"
  if fetch "https://rss.arxiv.org/rss/cs.LG" > /tmp/airadar-arx.xml 2>/dev/null && [[ -s /tmp/airadar-arx.xml ]]; then
    python3 - <<'PYEOF'
import xml.etree.ElementTree as ET
try:
    root = ET.fromstring(open('/tmp/airadar-arx.xml', encoding='utf-8', errors='replace').read())
    for item in list(root.iter('item'))[:8]:
        t = item.findtext('title', '')
        if t: print(f"- {t[:90]}")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi

} > "$OUT"

echo "抓取完成: $OUT ($(wc -l < "$OUT" | tr -d ' ') 行)"

# ---------- 分析阶段（默认跳过；由 cron agent 在会话内自行分析） ----------
# 如需脚本内分析：RADAR_NO_ANALYZE=0 ./ai-radar.sh
if [[ "$RADAR_NO_ANALYZE" != "1" ]]; then
  PROMPT_FILE="$RADAR_DIR/prompt-$TODAY.md"
  cat > "$PROMPT_FILE" <<EOF
你是 AI 模型与工具雷达分析员。今天是 $TODAY。

请阅读今日抓取数据：$OUT

输出一份 markdown 日报，要求：
1. 【重点动态】从数据中挑 3-8 条最有价值的，偏好：
   - 新发布/新开源的大模型（含官方 API 上线）
   - 免费模型（开源权重、免费用例、OpenRouter :free）
   - 价格/能力变化（降价、上下文升级、推理增强）
   - AI 工具生态（agent 框架、推理工具、AI 编程、多模态）
2. 每条给：一句话价值判断 + 与我当前模型栈的关联（百炼/OpenAI/Agnes，哪些值得试）
3. 【开源模型新趋势】如果有新开源权重模型，说明其参数量/许可证/运行门槛（是否能在本地 Mac 跑）
4. 【建议动作】哪些值得我切到主力/试用/收藏
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