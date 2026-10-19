#!/bin/bash
# memory-monitor.sh —— 内存监控与定时释放（确定性决策版）
#
# 为什么用脚本而不是写在 cron prompt 里：
#   旧版把「时段判断 + 是否关应用」的决策交给 flash 级模型现场推理，
#   2026-10-12 ~ 10-19 实测 8 天内 7 次在工作时间误关 Edge
#   （模型自述 "misapplied the time-of-day branch"，明知 14:32 是工作时间仍执行 quit）。
#   现在时段/阈值判断与关闭动作全部由本脚本确定性完成，LLM 只负责转发输出。
#
# 策略（对齐 2026-10 版 memory-monitor 约定）:
#   可用内存 = (Pages free + inactive + speculative) × page_size
#   占比 > 20%                → 正常，输出 NO_REPLY（静默）
#   10% ~ 20%                 → 偏高，静默
#   < 10%                     → 告警档
#   < 5%                      → 紧急档（文案加 🔴）
#   工作时间 09:00–19:00（含） → 只输出告警文案，绝不关闭任何应用
#   非工作时间 19:01–08:59    → 自动释放：先关 Edge；仍 <15% 再关 VS Code Insiders
#   绝不触碰 AnyDesk/Tailscale/ToDesk/Ghostty/node(OpenClaw)/sshd
#   （脚本只可能 quit Edge / VS Code Insiders 两个应用，天然满足）
#
# 用法:
#   memory-monitor.sh                                  # 正常运行，输出结论文本
#   MM_FAKE_TIME=1432 MM_FAKE_PCT=3 ./memory-monitor.sh --dry-run   # 调试/回归
#
#   MM_FAKE_TIME=HHMM   模拟当前时间（Asia/Shanghai 语义）
#   MM_FAKE_PCT=N       模拟可用内存占比（调试用）
#   --dry-run           只打印将执行的动作，不真正 quit
#
# 日志: ~/Library/Logs/memory-monitor.log
# 定时: OpenClaw cron 每 30 分钟（job memory-monitor；agent 跑本脚本并把 stdout 转发飞书，
#       脚本输出 NO_REPLY 时 agent 原样回复以触发投递抑制）

set -uo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

LOG="$HOME/Library/Logs/memory-monitor.log"
EDGE_APP="Microsoft Edge"
# VS Code 两个发行版都可能装着（Insiders / 稳定版），按实际运行的关；
# 注意 pgrep -f "Visual Studio Code" 会同时命中两者，必须先查 Insiders
CODE_INSIDERS="Visual Studio Code - Insiders"
CODE_STABLE="Visual Studio Code"

mkdir -p "$(dirname "$LOG")"

# ---------- 取时间（分钟粒度，Asia/Shanghai 语义） ----------
if [ -n "${MM_FAKE_TIME:-}" ]; then
  NOW="${MM_FAKE_TIME}"
else
  NOW=$(TZ=Asia/Shanghai date +%H%M)
fi

# ---------- 算可用内存占比 ----------
avail_pct() {
  local page_size free_p inact_p spec_p memsize
  page_size=$(vm_stat | awk 'NR==1 {gsub(/\./,""); print $8}')
  free_p=$(vm_stat | awk '/Pages free/ {gsub(/\./,""); print $3}')
  inact_p=$(vm_stat | awk '/Pages inactive/ {gsub(/\./,""); print $3}')
  spec_p=$(vm_stat | awk '/Pages speculative/ {gsub(/\./,""); print $3}')
  memsize=$(sysctl -n hw.memsize)
  echo $(( (free_p + inact_p + spec_p) * page_size * 100 / memsize ))
}

PCT="${MM_FAKE_PCT:-$(avail_pct)}"

# ---------- 关闭动作（唯一出口，工作时间永远不会走到这里） ----------
quit_app() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] 将执行: osascript -e 'quit app \"$1\"'"
    PCT=99  # 演练语义：视同关闭后内存恢复，后续分支与真实运行一致
  else
    osascript -e "quit app \"$1\"" 2>/dev/null
    sleep 10
  fi
}

is_running() {
  pgrep -f "$1" | head -1
}

log_line() {
  printf '%s pct=%s tier=%s window=%s action=%s\n' \
    "$(date '+%F %T')" "$PCT" "$1" "$2" "$3" >> "$LOG"
}

# ---------- 分档 ----------
# 工作时间: 0900–1900 含；非工作时间: 1901–0859
if [ "$NOW" -ge 0900 ] && [ "$NOW" -le 1900 ]; then
  WINDOW="work"
else
  WINDOW="off"
fi

if [ "$PCT" -ge 20 ]; then
  log_line normal "$WINDOW" none
  echo "NO_REPLY"
  exit 0
fi

if [ "$PCT" -ge 10 ]; then
  log_line elevated "$WINDOW" none
  echo "NO_REPLY"
  exit 0
fi

MARK="⚠️"
[ "$PCT" -lt 5 ] && MARK="🔴"

# ---------- 工作时间：只告警，绝不关闭 ----------
if [ "$WINDOW" = "work" ]; then
  log_line alert "$WINDOW" alert-only
  cat <<EOF
${MARK} 内存偏低（可用 ${PCT}%，<10%）工作时间告警，请人工处理；建议手动关闭高占用应用（如 Edge / VS Code），勿关 AnyDesk/Tailscale/ToDesk/Ghostty/node(OpenClaw)/sshd。

当前占用最高的 5 个进程：
$(ps -eo pid,rss,comm | sort -k2 -rn | head -6)
EOF
  exit 0
fi

# ---------- 非工作时间：自动释放 ----------
CLOSED=()

# 关 VS Code（优先 Insiders，其次稳定版）；输出 1=有版本被处理，0=都没跑
quit_vscode() {
  if is_running "$CODE_INSIDERS" >/dev/null; then
    echo "${MARK} 内存不足（可用 ${PCT}%），非工作时间自动关闭 VS Code Insiders 释放内存"
    log_line critical "$WINDOW" quit-vscode-insiders
    quit_app "$CODE_INSIDERS"
    CLOSED+=("VS Code Insiders")
    return 1
  elif is_running "$CODE_STABLE" >/dev/null; then
    echo "${MARK} 内存不足（可用 ${PCT}%），非工作时间自动关闭 VS Code 释放内存"
    log_line critical "$WINDOW" quit-vscode-stable
    quit_app "$CODE_STABLE"
    CLOSED+=("VS Code")
    return 1
  fi
  return 0
}

if is_running "$EDGE_APP" >/dev/null; then
  echo "${MARK} 内存不足（可用 ${PCT}%），非工作时间自动关闭 Microsoft Edge 释放内存"
  log_line critical "$WINDOW" quit-edge
  quit_app "$EDGE_APP"
  CLOSED+=("Microsoft Edge")
  [ "$DRY_RUN" = "1" ] || PCT=$(avail_pct)
  if [ "$PCT" -le 15 ]; then
    quit_vscode && true
  fi
else
  # Edge 没在跑：直接尝试 VS Code；quit_vscode 返回 0 表示没有版本在运行
  quit_vscode || true
  [ "${#CLOSED[@]}" -gt 0 ] || log_line critical "$WINDOW" nothing-to-close
fi

# ---------- 结果段 ----------
echo ""
if [ "${#CLOSED[@]}" -gt 0 ]; then
  echo "${MARK} 自动释放完成：已关闭 ${CLOSED[*]}，当前可用内存 ${PCT}%"
else
  echo "${MARK} 内存不足（可用 ${PCT}%），未发现可关闭的目标应用（Edge / VS Code 均未运行）"
fi
echo ""
echo "当前占用最高的 5 个进程："
ps -eo pid,rss,comm | sort -k2 -rn | head -6
