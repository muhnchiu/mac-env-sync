# Mac 多机环境同步 实施计划

> **For Claude:** REQUIRED SUB-SKILL: 用 superpowers:executing-plans 逐任务执行本计划。

**Goal:** 让多台 Mac（Mac mini / Pro 13 / Pro 14）的软件与配置收敛到"共享核心 + 显式差异"，运行时统一由 mise 管理，跨机可一键复刻、可续接思考。

**Architecture:** chezmoi 管理 dotfiles 仓库（GitHub `<github-user>/dotfiles`，hostname 分流 core/extras）+ Homebrew Bundle 分层装软件 + mise 接管 node/python/java + iCloud 同步 Claude 会话记忆。设计文档见 `2026-08-24-mac-sync-design.md`，操作手册见 `docs/manuals/new-machine-setup.md`。

**Tech Stack:** chezmoi、mise、Homebrew Bundle、mas、iCloud Drive、zsh + oh-my-zsh + starship。

**注：** 本计划为运维型（非纯代码），任务步骤用"预期输出"作为验证，替代 TDD 断言。每任务末尾提交（dotfiles 仓库 `git add/commit/push`；操作型变更记录到本计划勾选状态）。

---

## 已完成（上下文，勿重复）

- [x] **P0** 设计文档 `2026-08-24-mac-sync-design.md` + 采集脚本 `scripts/mac-snapshot.sh`
- [x] **P0** mac-env-sync 项目本体挪入 iCloud，原路径留软链
- [x] **P0** `~/.claude/projects` → iCloud `claude-projects` 软链（跨机续接思考）
- [x] **P0** GitHub 私有仓库 `<github-user>/dotfiles` 已建
- [x] **P1** Mac mini 导出现状备份 → `~/env-migration-backup/`
- [x] **P2** chezmoi source 骨架构建（zprofile/zshrc/zshrc.local/gitconfig/Brewfile.tmpl/mise config/shared Brewfile·清单/refresh-dev/machines.toml/.chezmoiignore/.gitignore/README）
- [x] **P2b** 布局验证（`chezmoi managed` 只含 9 目标、`shared/` 排除、Brewfile include+hostname 分流渲染正确）
- [x] **P3** Mac mini `chezmoi apply` 完成
- [x] **P3** Mac mini `mise install`：node 22.14 / python 3.12.14 / java temurin-21 全部生效
- [x] **P3-fix** mise java 语法 `temurin@21`→`temurin-21`
- [x] **P3-fix** bash_profile 纳入 chezmoi 管理，去掉默认 `export JAVA_HOME=JDK1.8`；`JAVA_HOME` 现跟随 mise，`jdk8` 别名保留
- [x] **P3** dotfiles 推送 GitHub（5 commits，main 分支）
- [x] **P3-upgrade**（2026-08-25）node 默认 22→24：openclaw 2026.7.1-2 要求 node>=22.22.3 或 >=24.15，原 22.14 不够；改 `config.toml` node=24，装 24.19.0，refresh-dev 重装全局包，openclaw launchd service force 重装到 mise（plist 指向 mise node 24，新 PID，connectivity ok）
- [x] **T1** refresh-dev（修为 mise exec 强制走 mise 运行时）
- [x] **T2** php@5.6（最接近 5.5 的可用版，入 Brewfile.MacMini，tap 已 trust）
- [x] **T3** Mac mini 卸载 nvm/pyenv/jenv/node formula（连带损失已补回）；数据目录已清理（openclaw 迁 mise 后无依赖，终止过期 playwright test-server 17h，`rm -rf ~/.nvm ~/.pyenv ~/.jenv` 回收 ~4.6G；clean-env 验证 PATH 无残留、运行时全走 mise）
- [x] **T8** ~/.claude/CLAUDE.md 用户级记忆（mise 工作流 + 代理 + 纪律）入 chezmoi

---

## 待办任务

### Task T1: Mac mini 重建全局 npm/pip 包（refresh-dev）

**Files:** `shared/bin/refresh-dev`（已修为用 `mise exec` 强制走 mise 运行时）
**依赖：** P3 完成（mise 已装 node/python）
**状态：** ✅ 已完成（2026-08-25）

**Step 1:** 运行 refresh-dev
```bash
~/.local/share/chezmoi/shared/bin/refresh-dev
```
**Expected:** 依次装 `npm-global.txt`（pnpm/yarn/typescript/codex…）、`pip-core.txt`、`pip-MacMini.txt`，末尾 `==> done`。

**Step 2:** 验证关键全局包
```bash
pnpm -v; yarn -v; tsc -v; python3 -c "import pydantic, openpyxl; print('pip ok')"
```
**Expected:** 各版本号输出、`pip ok`。

**Step 3:** 提交状态（若有包清单变更）
```bash
cd ~/.local/share/chezmoi && git status   # 无变更则跳过 commit
```

- [x] T1 完成

---

### Task T2: Mac mini php@7.2 决策

**Files:** `shared/Brewfile.core`（删 php@7.2）、`shared/Brewfile.MacMini`（加 php@5.6）、`dot_zprofile.tmpl`（php@7.2→5.6 PATH）
**状态：** ✅ 已完成（2026-08-25）
**决策：** 用 **php@5.6**（shivammathur tap 提供的最接近 PHP 5.5 的可用版本；php@5.5 不存在、无法在 arm64 构建）。放在 `Brewfile.MacMini`（dev 机维护老项目用），core 不含 php。tap 已 `brew trust`。安装前需开本地代理 `export http(s)_proxy=http://127.0.0.1:7897`（下载 GitHub bottle）。
**遗留：** php@5.6 默认 php.ini 引用未装的 redis.so pecl 扩展，`php -v` 有 warning（无害）；需时可 `pecl install redis` 或在 `/opt/homebrew/etc/php/5.6/php.ini` 注释 extension=redis。
**更新（2026-08-25）：** PHP 老项目本地已完全跑不起来，php@5.6 + shivammathur tap 已从两机 Brewfile/zprofile 全部移除并卸载（dotfiles `89b5670`）。T2 决策作废，php 不再纳入同步体系。

**Step 1:** 确认是否需要 PHP
```bash
ls /opt/homebrew/opt/php@7.2/bin 2>&1   # 当前不存在（tap 未 trust）
```
**Expected:** `No such file or directory`（确认未装）。

**Step 2a（不需要 PHP）:** 从 Brewfile.core 删掉 `brew "php@7.2"` 与 PATH 条目
- 改 `shared/Brewfile.core` 删 `brew "php@7.2"`
- 改 `dot_zprofile.tmpl` 删 php@7.2 的两行条件 PATH

**Step 2b（需要 PHP 7.2）:** trust tap 并保留
```bash
brew trust shivammathur/php
brew install php@7.2
```
**Expected:** `/opt/homebrew/opt/php@7.2/bin` 出现，`php -v` 输出 7.2.x。

**Step 3:** apply + 推送
```bash
chezmoi apply -v && cd ~/.local/share/chezmoi && git add -A && git commit -m "tweak: php@7.2 决策" && git push
```

- [x] T2 完成（决策：php@5.6）

---

### Task T3: Mac mini 卸载退役 brew formula（确认无破坏后）

**依赖：** T1 完成、shell 已用 mise 验证稳定一段时间
**Files:** 无（`brew uninstall`）
**状态：** ✅ 已完成（formula 卸载 + 数据目录清理，2026-08-25）

**Step 1:** 再次确认 shell 不依赖旧工具
```bash
zsh -l -i -c 'which node python3 java; echo "nvm=$(command -v nvm); pyenv=$(command -v pyenv); jenv=$(command -v jenv)"'
```
**Expected:** node/python3/java 均指向 mise；nvm/pyenv/jenv 可被 `command -v` 找到（因 formula 还在）但 shell 不调用。

**Step 2:** 卸载 formula（node formula 仅 Mini 有）
```bash
brew uninstall nvm pyenv jenv node
```
**Expected:** 无报错；`brew list | grep -E 'nvm|pyenv|jenv|^node$'` 无输出。
**实际：** ✅ 完成。注意 `brew uninstall` 会连带清掉被卸 formula 的孤立依赖——本次误删了 merve 及 kilo 依赖（ada-url/simdutf/fmt/nbytes/uvwasi/hdrhistogram_c 等），已用 `brew install` 补回，`brew bundle check --no-upgrade` 输出 `The Brewfile's dependencies are satisfied.`。教训：卸载后务必跑一次 `brew bundle check --no-upgrade` 复查并补齐。

**Step 3:**（可选，确认稳定后再做）清理数据目录
```bash
# 仅在确认无需回滚后执行；保留备份 ~/env-migration-backup/
rm -rf ~/.nvm ~/.pyenv ~/.jenv
```
**实际：** ✅ 已执行（2026-08-25）。openclaw 迁 mise node 后无进程依赖 `~/.nvm`；终止过期 playwright test-server 后 `rm -rf ~/.nvm ~/.pyenv ~/.jenv`，回收 ~4.6G（nvm 3.2G + pyenv 1.4G + jenv 20K）。Pro 13 同流程（`~/.nvm` 含 root 属主文件需 `sudo rm -rf`）。clean-env 验证 PATH 无 nvm/pyenv/jenv 残留。

**Step 4:** 验证 shell 仍正常
```bash
zsh -l -i -c 'which node python3 java; mise current' | grep -v WARN
```
**Expected:** 三者仍指向 mise，无 WARN。
**实际：** ✅ node/python3/java 均指向 mise，`mise current` 无 WARN。

- [x] T3 完成（formula ✅ + 数据目录清理 ✅）

---

### Task T4: Pro 13 导出快照与备份

**机器：** Pro 13（hostname `MacBookPro13`）
**依赖：** 无

**Step 1:** 跑采集脚本（经 iCloud 路径，无需 GitHub）
```bash
bash ~/Library/Mobile\ Documents/com~apple~CloudDocs/mac-env-sync/scripts/mac-snapshot.sh > ~/pro13-snapshot.txt
```
**Expected:** 末尾 `snapshot complete on MacBookPro13`。

**Step 2:** 导出退役前备份
```bash
mkdir -p ~/env-migration-backup
brew bundle dump --file=~/env-migration-backup/Brewfile.MacBookPro13 --force
command -v npm >/dev/null && npm ls -g --depth=0 2>/dev/null | sort > ~/env-migration-backup/npm-global.pro13.txt
command -v python3 >/dev/null && python3 -m pip freeze 2>/dev/null | sort > ~/env-migration-backup/pip-freeze.pro13.txt
cp ~/.zshrc ~/env-migration-backup/zshrc.$(date +%Y%m%d).bak
cp ~/.zprofile ~/env-migration-backup/zprofile.$(date +%Y%m%d).bak
cp ~/.gitconfig ~/env-migration-backup/gitconfig.$(date +%Y%m%d).bak
cp ~/.bash_profile ~/env-migration-backup/bash_profile.$(date +%Y%m%d).bak 2>/dev/null
```

- [x] T4 完成

---

### Task T5: Pro 13 拉取 dotfiles 并应用

**机器：** Pro 13
**依赖：** dotfiles 已推送（P3）；T4 完成

**Step 1:** 装 chezmoi/mise/mas
```bash
brew install chezmoi mise mas
```

**Step 2:** 拉取并应用（hostname=MacBookPro13 会渲染 Pro 专属、lmstudio 段为空）
```bash
chezmoi init --apply git@github.com:<github-user>/dotfiles.git
```
**Expected:** 输出各文件 apply diff；`~/.Brewfile`、`~/.zshrc`、`~/.config/mise/config.toml` 等落地。

**Step 3:** 装 brew 软件（core + Pro 专属）
```bash
brew bundle install --file ~/.Brewfile
```
**Expected:** 安装 GnuPG 链/postgresql@18/direnv/antidote/azure-cli-preview 等；末尾 `No failed installs`。

**Step 4:** mise 装版本 + 全局包
```bash
mise install
~/.local/share/chezmoi/shared/bin/refresh-dev
```
**Expected:** node 24 / python 3.12 / java temurin-21 装好；refresh-dev 末尾 `==> done`。

**Step 5:** 验证
```bash
zsh -l -i -c 'which node python3 java; mise current; brew bundle check --file ~/.Brewfile' | grep -v WARN
```
**Expected:** 三者指向 mise shims；`brew bundle check` 输出 `All dependencies are satisfied`。

- [x] T5 完成

---

### Task T6: Pro 13 卸载退役 formula + 建 Claude 软链

**机器：** Pro 13
**依赖：** T5 完成并稳定

**Step 1:** 卸载（Pro 可能无 brew `node` formula，忽略 not installed 报错）
```bash
brew uninstall nvm pyenv jenv node 2>/dev/null; true
```

**Step 2:** 建 Claude 会话记忆软链（若未建）
```bash
mv ~/.claude/projects ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects 2>/dev/null || true
ln -sfn ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects ~/.claude/projects
```
**Step 3:** 验证软链
```bash
ls -ld ~/.claude/projects   # -> .../claude-projects
```

- [x] T6 完成

---

### Task T7: oh-my-zsh + 自定义插件 bootstrap（两台补齐/文档化）

**Files:** 操作手册 `docs/manuals/new-machine-setup.md` 已含；本任务确认脚本化或手动步骤齐备

**背景：** `.zshrc` 依赖 `~/.oh-my-zsh` + custom 插件 `zsh-autosuggestions`/`zsh-syntax-highlighting`，这些是 git clone 不是 brew，新机器需手动装。

**Step 1:** 在任一缺装机器上安装
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```
**Expected:** `~/.oh-my-zsh` 存在，两插件目录存在。

**Step 2:** 验证 shell 加载无插件缺失报错
```bash
zsh -l -i -c 'echo ok'
```
**Expected:** 无 `command not found` / 插件缺失警告。

- [x] T7 完成

---

### Task T8: 长期记忆 CLAUDE.md 纳入 chezmoi（两台共享）

**Files:** Create `dot_claude/CLAUDE.md` 于 chezmoi source
**状态：** ✅ 已完成（2026-08-25）
**内容：** 用户身份、mise 运行时工作流（node/python/java 用 mise exec）、全局包 refresh-dev、国际源下载代理（127.0.0.1:7897）、持久化配置变更流程、纪律。`~/.claude/projects` 是 iCloud 软链，chezmoi 只管 CLAUDE.md 文件本身，不冲突。

**Step 1:** 写共享 CLAUDE.md（含：用户身份 <username>/<github-user>、多机同步方案要点、mise 管运行时、主编辑机 Mac mini 改配置）
**Step 2:** 加入 chezmoi
```bash
mkdir -p ~/.local/share/chezmoi/dot_claude
# 写 ~/.local/share/chezmoi/dot_claude/CLAUDE.md
chezmoi apply -v
git add -A && git commit -m "feat: 共享 ~/.claude/CLAUDE.md 长期记忆" && git push
```
**注意：** `~/.claude/projects` 是 iCloud 软链，chezmoi 只管 `CLAUDE.md` 文件本身，不冲突。

- [x] T8 完成

---

### Task T9: Pro 14 接入（hostname 待定后执行）

**机器：** Pro 14（hostname 占位 `<hostname3>`）
**依赖：** 拿到该机 `scutil --get LocalHostName`
**状态：** ✅ 已完成（2026-08-25，hostname = `MacBookPro14`，在 Pro 14 上由 Claude 会话执行）

**Step 1:** 采集快照
```bash
bash ~/Library/Mobile\ Documents/com~apple~CloudDocs/mac-env-sync/scripts/mac-snapshot.sh > ~/pro14-snapshot.txt
```

**Step 2:** 对比已有 `snapshots/mini.txt` / `snapshots/pro13.txt`，确定 Pro 14 专属要装什么，填：
- `shared/Brewfile.<hostname3>`（专属 formula/cask/mas）
- `dot_Brewfile.tmpl` 加 `else if eq (lower .chezmoi.hostname) "<hostname3>"` 分支（hostname 比较用 lower，避免 macOS 小写化不匹配——见 a8c46f2）
- `dot_zprofile.local.tmpl` 加同名分支（若有独有 PATH，同样用 lower 比较）
- `shared/machines.toml` 登记
- `.chezmoiignore` 按需
- 快照归档：`cp ~/pro14-snapshot.txt` 到 mac-env-sync `snapshots/pro14.txt` 并 git commit（否则像 mini.txt 一样会缺失）

**Step 3:** 提交推送
```bash
cd ~/.local/share/chezmoi && git add -A && git commit -m "feat: 接入 Pro 14 (<hostname3>)" && git push
```

**Step 4:** 在 Pro 14 上走 T5 流程（chezmoi init --apply + brew bundle + mise install + refresh-dev）

- [x] T9 完成（Pro 14 hostname：`MacBookPro14`）

**T9 执行实录（要点，供下次接机参考）：**
- 专属清单（用户确认）：formula `cmake/llvm/rust/protobuf/pipx/yt-dlp/copilot`；cask `github-copilot-for-xcode/miniforge/warp/ghostty`；`dot_zprofile.local.tmpl` 加 miniforge condabin 条件 PATH
- **坑 1（新机器必踩）**：`scutil --get HostName` 未设置（只有 LocalHostName）→ `hostname`/chezmoi 拿到默认值 `Mac`，模板分支全不匹配、Brewfile 渲染不出专属段。修复 `sudo scutil --set HostName MacBookPro14`，已补进 manual §0.1
- **坑 2**：Homebrew 5.x `brew bundle` 预检用 API 解析全部条目，第三方 tap 未克隆时 cpolar/open-island 报 "No available formula" 整体失败（tap 声明在文件头也没用）。先手动 `brew tap` 全部第三方 tap 再跑 bundle。已补进 manual §6
- **core 修复（dotfiles 已推送）**：删废弃 tap `homebrew/services`；注释 `open-island`（cask 全源消失）、`cc-switch`（3.15 限 Monterey）、`redis` cask（限 Sonoma）—— macOS 26 装不了，均留注记；bash_profile `~/.local/bin/env` 加守卫
- **遗留（唯一未闭环）**：`mas install 1295203466`（Windows App）报 MASError 5，需先在 App Store 图形界面登录再重试；另 mas 2.2.2 与 brew bundle 的 `mas get` 调用不兼容（mas 单独用没问题）
- 退役：nvm/powerlevel10k/zsh-autosuggestions formula 卸载（复查无级联损伤）；`~/.nvm` 空目录已删；npm 全局 `n` 已卸；`/usr/local/bin/node` 旧副本按用户决定保留（mise shims 优先级压住）
- 运行时与 mini 完全一致：node 24.19.0 / python 3.12.14 / temurin-21.0.12+8.0.LTS（含 /Library/Java JVM 软链）；refresh-dev `==> done`；T10 本机各项通过（clean-env 零残留、chezmoi diff 空、shell 生态 ok）

---

### Task T10: 全局验收（跨机一致性 + 续接思考）

**Step 1:** 每台机器验收运行时（clean-env，不继承父 PATH）
```bash
env -i HOME=$HOME PATH=/usr/bin:/bin /bin/zsh -l -i -c 'which node python3 java; mise current; echo JAVA_HOME=$JAVA_HOME; echo PATH残留=$(echo $PATH|tr : "\n"|grep -cE "nvm|pyenv|jenv"); brew bundle check --no-upgrade --file ~/.Brewfile' 2>/dev/null | grep -v WARN
```
**Expected:** 三者指向 mise；JAVA_HOME 跟随 mise；PATH 残留=0；brew bundle check satisfied。

**Step 2:** shell 生态（oh-my-zsh + 插件 + starship + php）
```bash
zsh -l -i -c 'echo ok; ls ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions >/dev/null && echo autosug-ok; ls ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting >/dev/null && echo synhl-ok; command -v starship >/dev/null && echo starship-ok'
command -v php >/dev/null && php -v 2>/dev/null | head -1   # 装 php 的机器应 5.6.40
```
**Expected:** `ok` + 三插件/prompt ok；php 机器 5.6.40 无 warning。

**Step 3:** 全局包 + chezmoi 一致性
```bash
pnpm -v; tsc -v; python3 -c "import pydantic;print(\"pip ok\")"
chezmoi diff ~/.Brewfile ~/.zshrc ~/.zprofile ~/.claude/CLAUDE.md 2>/dev/null | head   # 应无 diff（源与落地一致）
```
**Expected:** 全局包版本输出 + pip ok；chezmoi diff 空（源与落地一致）。

**Step 4:** 跨机续接思考
- 在 A 机 `claude` 起一会话 → 退出 → 在 B 机进同目录 `claude --resume`（zsh 包装会自动 `brctl download` 拉最新 jsonl）应见该会话。

**Step 5:** 确认噪声清理
```bash
ls ~/.zshrc.backup ~/.zprofile.bak ~/new-zshrc ~/old-zshrc ~/.nvm ~/.pyenv ~/.jenv 2>/dev/null   # 应无输出
```

- [x] T10 完成（Mini ✅ 本次；Pro 13 ✅ T5/T6 末尾等效验证；Pro 14 ✅ T9 内完成等效验收，仅 Windows App 待 App Store 登录后补装）

---

## 状态速查

| 任务 | 机器 | 状态 |
|---|---|---|
| T1 refresh-dev | Mac mini | ✅ |
| T2 php 决策 | Mac mini | ✅ |
| T3 卸载退役 formula | Mac mini | ✅（含数据目录清理） |
| T4 快照+备份 | Pro 13 | ✅ |
| T5 拉取+应用 | Pro 13 | ✅ |
| T6 卸载+软链 | Pro 13 | ✅ |
| T7 oh-my-zsh bootstrap | 两台 | ✅ |
| T8 CLAUDE.md 共享 | 两台 | ✅ |
| T9 Pro 14 接入 | Pro 14 | ✅（2026-08-25；遗留：Windows App 待 App Store 登录补装） |
| T10 全局验收 | 全部 | ✅（三台全过；Pro 14 见 T9 实录） |
