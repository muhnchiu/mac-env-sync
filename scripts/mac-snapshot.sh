#!/bin/bash
# mac-snapshot.sh —— 采集当前 Mac 的环境快照，用于多机差异对比。
#
# 用法:
#   ./mac-snapshot.sh > snapshot.txt          # 本机采集
#   bash -s < mac-snapshot.sh                 # 远端通过 ssh 执行
#
# 设计原则: 每段独立容错，缺工具只标注"未安装"，不中断整个脚本。

run() {  # 描述 -> 命令：有则输出排序结果，无则标注未安装
  local label="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    "$@"
  else
    echo "(未安装: $1)"
  fi
}

section() { echo; echo "########## $1 ##########"; }

section "hostname"
scutil --get ComputerName 2>/dev/null
scutil --get LocalHostName 2>/dev/null
uname -n

section "macOS version"
sw_vers

section "arch"
uname -m

section "brew formulae"
command -v brew >/dev/null 2>&1 && brew list --formula -1 | sort || echo "(未安装: brew)"

section "brew casks"
command -v brew >/dev/null 2>&1 && brew list --cask -1 | sort || echo "(未安装: brew)"

section "brew taps"
command -v brew >/dev/null 2>&1 && brew tap | sort || echo "(未安装: brew)"

section "brew leaves (顶层包)"
command -v brew >/dev/null 2>&1 && brew leaves | sort || echo "(未安装: brew)"

section "mas (App Store apps)"
command -v mas >/dev/null 2>&1 && mas list | sort || echo "(未安装: mas, 可 brew install mas)"

section "/Applications"
ls /Applications 2>/dev/null | sort

section "~/Applications"
ls ~/Applications 2>/dev/null | sort

section "mise tools"
command -v mise >/dev/null 2>&1 && mise list --installed 2>/dev/null || echo "(未安装: mise)"

section "PATH"
echo "$PATH" | tr ':' '\n'

section "shells"
cat /etc/shells 2>/dev/null
echo "default shell: $SHELL"

section "node global"
command -v npm >/dev/null 2>&1 && npm ls -g --depth=0 2>/dev/null | sort || echo "(未安装: npm)"

section "python"
command -v python3 >/dev/null 2>&1 && { python3 --version; command -v pip3 >/dev/null 2>&1 && pip3 list --format=freeze 2>/dev/null | sort; } || echo "(未安装: python3)"

section "dotfiles in \$HOME"
ls -la ~ 2>/dev/null | grep '^[-l]' | awk '{print $NF}' | sort

section "done"
echo "snapshot complete on $(uname -n)"
