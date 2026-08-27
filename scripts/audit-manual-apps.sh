#!/bin/bash
# audit-manual-apps.sh —— 判别 /Applications 与 ~/Applications 里每个 app 的安装来源，
# 找出"手动下载安装"的 app（即可以被 brew cask --adopt 收编的候选）。
#
# 用法:
#   ./audit-manual-apps.sh                # 终端直接看
#   ./audit-manual-apps.sh > audit.txt    # 落盘对照 docs/plans/2026-08-27-cask-adopt-plan.md
#
# 输出四段:
#   A. brew cask 已接管的 app（receipt + 工件）
#   B. App Store 安装的 app（_MASReceipt 判定）
#   C. 手动安装的 app（名字 | bundle id | 版本）← 主要看这段，对照 plan 文档挑 token
#   D. receipt 残留告警（cask 声明的 app 已不在磁盘上）
#
# 设计原则: 与 mac-snapshot.sh 一致，每段独立容错；只陈述事实不做 token 猜测，
# token 对照表统一维护在 docs/plans/2026-08-27-cask-adopt-plan.md。

section() { echo; echo "########## $1 ##########"; }

# cask receipt 的 app 工件列表: "匹配名(无.app)\t完整文件名(带.app)\ttoken"
# 例: "CopyQ\tCopyQ.app\tcopyq"。C 段用第1列比对，D 段用第2列查磁盘。
CASK_ARTIFACTS=$(brew info --cask --json=v2 --installed 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    for c in d['casks']:
        for a in c.get('artifacts') or []:
            if 'app' in a:
                for app in a['app']:
                    fname=app.rstrip('/').split('/')[-1]
                    base=fname[:-4] if fname.endswith('.app') else fname
                    print(base+'\t'+fname+'\t'+c['token'])
except Exception:
    pass" 2>/dev/null)

cask_token_of() {  # 参数: app 名（任意大小写）-> 输出接管它的 token（无则空）
  local low; low=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  echo "$CASK_ARTIFACTS" | awk -F'\t' -v n="$low" 'tolower($1)==n{print $3}'
}

section "hostname"
scutil --get HostName 2>/dev/null || uname -n

section "A. brew cask 接管的 app"
brew list --cask -1 2>/dev/null | sed 's/^/receipt: /' || echo "(未安装: brew)"
echo
echo "$CASK_ARTIFACTS" | grep -v '^$' | awk -F'\t' '{printf "artifact: %-30s (cask %s)\n", $2, $3}'

section "B. App Store 安装的 app (_MASReceipt)"
for app in /Applications/*.app ~/Applications/*.app; do
  [[ -d "$app/Contents/_MASReceipt" ]] && echo "MAS: $(basename "$app" .app)"
done
echo "(done)"

section "C. 手动安装的 app（名字 | bundle id | 版本）"
for app in /Applications/*.app ~/Applications/*.app; do
  [[ -d "$app" ]] || continue
  [[ -d "$app/Contents/_MASReceipt" ]] && continue          # App Store
  [[ -n "$(cask_token_of "$(basename "$app" .app)")" ]] && continue  # cask 工件
  bid=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)
  ver=$(defaults read "$app/Contents/Info" CFBundleShortVersionString 2>/dev/null)
  echo "$(basename "$app" .app) | ${bid:-?} | ${ver:-?}"
done | sort -f
echo "(done)"

section "D. receipt 残留告警（cask 工件不在磁盘 = app 可能被手动卸载）"
# 只查有 app 工件的 cask；ngrok/redis/wechattweak-cli 这类 CLI 型 cask 无工件，跳过
echo "$CASK_ARTIFACTS" | grep -v '^$' | while IFS=$'\t' read -r base fname tok; do
  if [[ ! -d "/Applications/$fname" && ! -d "$HOME/Applications/$fname" ]]; then
    echo "⚠ cask '$tok' 工件 $fname 不在磁盘 —— 确认是否被手动卸载（brew uninstall $tok 清 receipt）"
  fi
done
echo "(done)"

section "done"
echo "audit complete on $(uname -n) —— 对照 docs/plans/2026-08-27-cask-adopt-plan.md 的 token 表逐项决定 转换/保留/删除"
