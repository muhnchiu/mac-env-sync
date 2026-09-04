#!/bin/bash
# sec-radar.sh —— 每日安全漏洞情报抓取
#
# 用法:
#   sec-radar.sh                        # 只抓取（默认）
#
# 数据源（每段独立容错，任一失败不影响其余）:
#   1. NVD 最近高危漏洞（CVSS >= 7.0，API）
#   2. GitHub Security Advisories（全局，近7天）
#   3. GitHub Security Advisories（已装依赖相关：Java/Spring/Nginx/MySQL/Node）
#   4. CISA KEV（已知被利用漏洞目录，RSS）
#   5. Hacker News Security 标签（社区讨论热度）
#
# 输出:
#   ~/.local/state/sec-radar/YYYY-MM-DD.md           抓取数据（结构化 markdown）
#   ~/.local/state/sec-radar/sec-radar.log            运行日志
#
# 依赖: curl / python3
# 代理: 默认 127.0.0.1:7897（NVD/GitHub 为国际源）；RADAR_NO_PROXY=1 关闭
# 定时: OpenClaw cron 每天 08:15（agent 抓取后自行分析）

RADAR_DIR="$HOME/.local/state/sec-radar"
TODAY=$(date +%F)
OUT="$RADAR_DIR/$TODAY.md"
LOG="$RADAR_DIR/sec-radar.log"
PROXY="http://127.0.0.1:7897"
[[ "$RADAR_NO_PROXY" == "1" ]] && PROXY=""

MISE_BIN="$(command -v mise || echo /opt/homebrew/bin/mise)"
mkdir -p "$RADAR_DIR"
exec >>"$LOG" 2>&1
echo "===== sec-radar $TODAY $(date +%T) ====="

fetch() { curl -sS --max-time 25 ${PROXY:+--proxy "$PROXY"} "$1" 2>/dev/null; }
# NVD 不走代理（代理可能导致超时）
fetch_noproxy() { curl -sS --max-time 25 "$1" 2>/dev/null; }

# NVD API 的 pubStartDate 用 UTC，往前推 24h
NVD_END=$(date -u +%Y-%m-%dT%H:%M:%S.000)
NVD_START=$(date -u -v-24H +%Y-%m-%dT%H:%M:%S.000 2>/dev/null || date -u -d "-24 hours" +%Y-%m-%dT%H:%M:%S.000)

{
  echo "# 安全漏洞雷达 $TODAY"
  echo
  echo "> sec-radar.sh 抓取；分析版见 ${TODAY}-analysis.md；归档：mac-env-sync/docs/radar-reports/sec/"
  echo

  # 1. NVD 最近 24h 高危漏洞（CVSS >= 7.0）
  echo "## NVD 最近 24h 高危漏洞（CVSS >= 7.0）"
  NVD_URL="https://services.nvd.nist.gov/rest/json/cves/2.0?resultsPerPage=40&pubStartDate=${NVD_START}&pubEndDate=${NVD_END}"
  if fetch_noproxy "$NVD_URL" > /tmp/secradar-nvd.json 2>/dev/null && [[ -s /tmp/secradar-nvd.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/secradar-nvd.json'))
    vulns = d.get('vulnerabilities', [])
    # Filter: only show CVSS >= 7.0, skip rejected CVEs
    filtered = []
    for v in vulns:
        cve = v.get('cve', {})
        # Skip rejected
        descs = cve.get('descriptions', [])
        desc = next((d['value'] for d in descs if d['lang'] == 'en'), '')
        if desc.startswith('Rejected reason'): continue
        metrics = cve.get('metrics', {})
        score = 0
        if 'cvssMetricV31' in metrics and metrics['cvssMetricV31']:
            score = metrics['cvssMetricV31'][0].get('cvssData', {}).get('baseScore', 0)
        elif 'cvssMetricV30' in metrics and metrics['cvssMetricV30']:
            score = metrics['cvssMetricV30'][0].get('cvssData', {}).get('baseScore', 0)
        elif 'cvssMetricV2' in metrics and metrics['cvssMetricV2']:
            score = metrics['cvssMetricV2'][0].get('cvssData', {}).get('baseScore', 0)
        if score >= 7.0:
            filtered.append((cve.get('id', ''), score, desc[:120]))
    if not filtered:
        print("（近 24h 无 CVSS >= 7.0 的新漏洞）")
    for cid, score, desc in filtered[:20]:
        print(f"- {cid} (CVSS {score}) | {desc}{'...' if len(desc) >= 120 else ''}")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 2. GitHub Security Advisories（全局，近 7 天）
  echo "## GitHub Security Advisories（全局近 7 天）"
  SINCE7=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "-7 days" +%Y-%m-%dT%H:%M:%SZ)
  GH_URL="https://api.github.com/advisories?published_at=${SINCE7}&per_page=20&sort=published_at&direction=desc"
  if fetch "$GH_URL" > /tmp/secradar-ghsa.json 2>/dev/null && [[ -s /tmp/secradar-ghsa.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/secradar-ghsa.json'))
    if not isinstance(d, list) or not d:
        print("（近 7 天无新 GitHub Security Advisory）")
    else:
        for a in d[:20]:
            aid = a.get('ghsa_id', '')
            summary = (a.get('summary') or '')[:100]
            sev = a.get('severity', '')
            cvss = a.get('cvss', {})
            score = cvss.get('score', '') if isinstance(cvss, dict) else ''
            eco = ', '.join(a.get('references', [{}]) and [e for e in a.get('cwes', [])][:3] or [])
            print(f"- {aid} [{sev}] CVSS {score} | {summary}")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 3. GitHub Security Advisories（Java/Spring/Nginx/MySQL 相关）
  echo "## 与项目依赖相关的 GitHub Security Advisories"
  # Search for advisories affecting Java ecosystem
  for eco in maven npm pip; do
    echo "### $eco 生态"
    GH_ECO_URL="https://api.github.com/advisories?ecosystem=${eco}&per_page=10&sort=published_at&direction=desc"
    if fetch "$GH_ECO_URL" > /tmp/secradar-eco.json 2>/dev/null && [[ -s /tmp/secradar-eco.json ]]; then
      python3 - "$eco" <<'PYEOF'
import json, sys
eco = sys.argv[1]
try:
    d = json.load(open('/tmp/secradar-eco.json'))
    if not isinstance(d, list) or not d:
        print("（无新公告）")
    else:
        for a in d[:10]:
            aid = a.get('ghsa_id', '')
            summary = (a.get('summary') or '')[:80]
            sev = a.get('severity', '')
            vulns = a.get('vulnerabilities', [])
            pkg_names = ', '.join(v.get('package', {}).get('name', '') for v in vulns[:3])
            print(f"- {aid} [{sev}] {pkg_names} | {summary}")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
    else
      echo "（抓取失败）"
    fi
    echo
  done

  # 4. CISA KEV（已知被利用漏洞目录）
  echo "## CISA KEV（已知被利用漏洞，最近更新）"
  if fetch "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json" > /tmp/secradar-cisa.json 2>/dev/null && [[ -s /tmp/secradar-cisa.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/secradar-cisa.json'))
    vulns = d.get('vulnerabilities', [])
    # Sort by dateAdded descending, take last 10
    vulns.sort(key=lambda v: v.get('dateAdded', ''), reverse=True)
    for v in vulns[:10]:
        vid = v.get('cveID', '')
        vendor = v.get('vendorProject', '')
        product = v.get('product', '')
        vuln_name = v.get('vulnerabilityName', '')[:60]
        date = v.get('dateAdded', '')
        print(f"- {date} | {vid} | {vendor}/{product} | {vuln_name}")
    if not vulns:
        print("（无数据）")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi
  echo

  # 5. Hacker News Security 标签
  echo "## Hacker News Security 讨论"
  if fetch "https://hn.algolia.com/api/v1/search_by_date?tags=story&query=security+OR+vulnerability+OR+CVE+OR+breach&hitsPerPage=15" > /tmp/secradar-hn.json 2>/dev/null && [[ -s /tmp/secradar-hn.json ]]; then
    python3 - <<'PYEOF'
import json
try:
    d = json.load(open('/tmp/secradar-hn.json'))
    for h in d.get('hits', [])[:15]:
        title = h.get('title') or ''
        url = h.get('url') or f"https://news.ycombinator.com/item?id={h.get('objectID')}"
        pts = h.get('points') or 0
        comments = h.get('num_comments') or 0
        if title:
            print(f"- {title} [{pts}分/{comments}评] {url}")
except Exception as e:
    print(f"（解析失败: {e}）")
PYEOF
  else
    echo "（抓取失败）"
  fi

} > "$OUT"

echo "抓取完成: $OUT ($(wc -l < "$OUT" | tr -d ' ') 行)"
echo "===== done $(date +%T) ====="
