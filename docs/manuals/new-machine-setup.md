# Mac 新机环境配置操作手册

> 从一台全新的 Mac 到"开发环境就绪 + 跨机同步 + 可续接思考"的完整步骤。
> 适用：新购机器、重装系统后、或为现有机器补齐同步体系。
> 配套：设计文档 `docs/plans/2026-08-24-mac-sync-design.md`、实施计划 `docs/plans/2026-08-24-mac-sync-plan.md`、chezmoi 操作指南 `docs/manuals/chezmoi-guide.md`。

---

## 0. 角色与前置判断

先判断这台机器的角色，决定走哪条流程：

| 角色 | hostname（示例） | 流程 |
|---|---|---|
| **主编辑机**（改配置的源头） | `MacMini` | 全流程 + 额外建/改 dotfiles 仓库 |
| **辅机**（只同步） | `MacBookPro13` / `<hostname3>` | 全流程，但 dotfiles 直接从 GitHub 拉取 |

> 当前主编辑机为 **Mac mini**。新机器一律按**辅机**流程接入（除非你要换主编辑机）。

### 0.1 系统前置（开箱后先做）

1. 完成 macOS 初始设置，登录 Apple ID，**iCloud Drive 同步开启**（System Settings → Apple ID → iCloud → iCloud Drive 开）。
2. 确认本机 hostname（用于 chezmoi 分流）：
   ```bash
   scutil --get LocalHostName
   ```
   记下这个值。若需改名：
   ```bash
   sudo scutil --set LocalHostName <新名字>
   ```
3. 装 Xcode Command Line Tools（Homebrew 依赖）：
   ```bash
   xcode-select --install
   ```
   弹窗点 Install，等完成。

### 0.2 GitHub SSH key（辅机拉取 dotfiles 必须）

```bash
# 1) 生成 key（无 passphrase 方便脚本，或按需设密码）
ssh-keygen -t ed25519 -C "<github-user>@<hostname>" -f ~/.ssh/id_ed25519 -N ""

# 2) 启动 ssh-agent 并加 key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 3) 复制公钥
pbcopy < ~/.ssh/id_ed25519.pub
```
打开 https://github.com/settings/keys → New SSH key → 粘贴 → Add。

验证：
```bash
ssh -T git@github.com
```
**Expected:** `Hi <github-user>! You've successfully authenticated...`

---

## 1. 安装 Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

安装末尾会提示把 brew 加入 PATH 的两行，**照抄执行**（arm64 通常）：
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

验证：
```bash
brew --version
```
**Expected:** `Homebrew 4.x.x`

> 国内网络慢可先设镜像（可选）：
> ```bash
> export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
> export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
> export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
> ```
> 但 dotfiles 的 `.zprofile` 已含 ustc 镜像设置，apply 后即生效，所以这里可跳过。

---

## 2. 安装 chezmoi / mise / mas

```bash
brew install chezmoi mise mas
```

验证：
```bash
chezmoi --version    # chezmoi version 2.x.x
mise --version        # mise 2026.x
mas version            # mas x.x.x（App Store CLI）
```

---

## 3. iCloud 与 Claude 会话记忆软链（跨机续接思考）

让 `~/.claude/projects`（会话 jsonl）随 iCloud 在多机可见，实现 `claude --resume` 跨机续接。

```bash
# 1) 先装 Claude Code（若未装）
#    按 https://docs.claude.com/claude-code 官方方式安装

# 2) 把 projects 目录搬到 iCloud 并软链回来
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs
mv ~/.claude/projects ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects 2>/dev/null || true
ln -sfn ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects ~/.claude/projects
```

验证：
```bash
ls -ld ~/.claude/projects
```
**Expected:** `... -> .../Mobile Documents/com~apple~CloudDocs/claude-projects`

> **纪律：** 同一 Claude 会话**不要在两台机同时开**（iCloud 文件冲突）。

---

## 4. oh-my-zsh + 自定义插件

`.zshrc` 依赖 oh-my-zsh 和两个自定义插件，这些是 git clone 不是 brew，必须手动装：

```bash
# 1) oh-my-zsh（unattended 不改默认 shell 设置流程）
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# 2) 自定义插件
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
```

验证：
```bash
ls ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ls ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```
**Expected:** 两个文件路径都存在。

> 若 oh-my-zsh install 脚本把默认 shell 改成 zsh：`chsh -s /bin/zsh`（如已是 zsh 可跳过）。

> **提示符（starship）无需手动配**：starship 由 Brewfile 装，`~/.config/starship.toml` 已由 chezmoi 管理——`chezmoi init --apply` 后自动落地，各机提示符样式一致。`.zshrc` 里 `ZSH_THEME=""` + `eval "$(starship init zsh)"` 让 oh-my-zsh 只管插件、starship 管提示符。

---

## 5. 拉取 dotfiles 并应用（核心步骤）

### 5A. 辅机流程（绝大多数新机器走这条）

```bash
chezmoi init --apply git@github.com:<github-user>/dotfiles.git
```

chezmoi 会按本机 hostname 渲染对应配置并写入 `$HOME`：
- `~/.zshrc`、`~/.zprofile`、`~/.zprofile.local`、`~/.bash_profile`、`~/.gitconfig`、`~/.gitignore_global`、`~/.Brewfile`、`~/.config/mise/config.toml`、`~/.claude/CLAUDE.md`

验证已落地：
```bash
ls -la ~/.zshrc ~/.zprofile ~/.Brewfile ~/.config/mise/config.toml ~/.claude/CLAUDE.md
```

> **apply 会覆盖现有 .zshrc/.zprofile**。若本机已有自定义配置想保留，先备份：
> ```bash
> mkdir -p ~/env-migration-backup
> cp ~/.zshrc ~/.zprofile ~/.bash_profile ~/.gitconfig ~/env-migration-backup/ 2>/dev/null
> ```

### 5B. 主编辑机首次建仓库（仅 Mac mini 走过一次，新主编辑机才需）

```bash
chezmoi init                              # 初始化空 source（~/.local/share/chezmoi）
cd ~/.local/share/chezmoi
git remote add origin git@github.com:<github-user>/dotfiles.git
# 按 docs/plans/2026-08-24-mac-sync-design.md 第 3-6 节填入文件
git add -A && git commit -m "init: dotfiles baseline" && git push -u origin main
```

---

## 6. 安装 Homebrew 软件（core + 本机专属）

apply 后 `~/.Brewfile` 已由 chezmoi 按 hostname 拼好（core + 本机专属）：

```bash
brew bundle install --file ~/.Brewfile
```

**Expected:** 安装各 formula/cask/mas；末尾 `Success` 或列出 `Succeeded: ...`。

> 若提示 `mas` 需登录 App Store：打开 App Store 登录 Apple ID 后重跑。
> 某些 cask（如 wechattweak-cli）可能需手动确认。

验证：
```bash
brew bundle check --file ~/.Brewfile
```
**Expected:** `All dependencies are satisfied`

---

## 7. 安装运行时（mise 按 config.toml 装版本）

```bash
mise install
```

`mise install` 读 `~/.config/mise/config.toml`，装 `node=24` / `python=3.12` / `java=temurin-21`。

**Expected:** 三个版本依次 `✓ installed`；java 会提示创建 `/Library/Java/JavaVirtualMachines/...` 软链（可能要 sudo）。

验证运行时走 mise：
```bash
zsh -l -i -c 'which node python3 java; mise current' | grep -v WARN
```
**Expected：**
```
node     -> /Users/<username>/.local/share/mise/installs/node/24/bin/node
python3  -> /Users/<username>/.local/share/mise/installs/python/3.12/bin/python3
java     -> /Users/<username>/.local/share/mise/installs/java/temurin-21/bin/java
node 24.x / python 3.12.x / java temurin-21.x
```

> 若 `java` 仍是系统/JDK1.8：检查 `~/.bash_profile` 是否被 chezmoi 管理且不含 `export JAVA_HOME=...JDK1.8`（参见设计文档 bash_profile 章节）。

---

## 8. 重建全局 npm/pip 包

```bash
~/.local/share/chezmoi/shared/bin/refresh-dev
```

脚本读 `shared/npm-global.txt`、`pip-core.txt`、`pip-<hostname>.txt`（按本机 hostname），装全局包。

**Expected:** 末尾 `==> done`。

验证：
```bash
pnpm -v; yarn -v; tsc -v
python3 -c "import pydantic, openpyxl; print('pip ok')"
```

---

## 9. 全量验收清单

在新开终端（确保加载新配置）逐条跑：

```bash
# 1) 运行时全走 mise
which node python3 java
echo "JAVA_HOME=$JAVA_HOME"     # 应指向 mise 的 temurin-21，非 jdk-1.8

# 2) mise 状态干净（无 WARN）
mise current

# 3) brew 软件齐全
brew bundle check --file ~/.Brewfile

# 4) 关键工具可用
node -v; python3 --version; java -version 2>&1 | head -1
mvn -v 2>&1 | head -1           # 若装了 maven
# （php 已移除——老项目本地不再跑；若将来需要再按设计文档第 8 节评估装回）

# 5) shell 无报错加载
zsh -l -i -c 'echo shell-ok'

# 6) Claude 跨机续接
ls -ld ~/.claude/projects        # -> iCloud claude-projects
claude --resume                  # 应见其它机器的会话
```

**全绿则配置完成。**

---

## 10. 故障排查

| 现象 | 排查 |
|---|---|
| `chezmoi init --apply` 报 SSH 权限被拒 | 回 0.2 配 GitHub SSH key；`ssh -T git@github.com` 验证 |
| `brew bundle` 卡在下载 | 镜像问题；确认 `.zprofile` 的 ustc 镜像生效（开新终端），或临时 `export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles` |
| `mise install` 报 `no metadata found for version temurin@21` | java 语法错误，应为 `temurin-21`（连字符）。改 `~/.config/mise/config.toml`（在 source 里改 `dot_config/mise/config.toml` 再 `chezmoi apply`） |
| `which node` 不指向 mise | 开**新**终端；检查 `.zprofile` 有 `eval "$(mise activate zsh)"` 且在 brew shellenv 之后；`mise doctor` |
| `JAVA_HOME` 指向 jdk-1.8 | `~/.bash_profile` 仍有无条件 `export JAVA_HOME=...JDK1.8`；确认 chezmoi 版已去掉（`chezmoi cat ~/.bash_profile` 检查） |
| oh-my-zsh 插件 `command not found` | 回第 4 步 clone 两个插件 |
| `claude --resume` 看不到别机会话 | iCloud 未同步完；`brctl download` 触发，或等几分钟；确认 `~/.claude/projects` 是软链 |
| `chezmoi update` 冲突 | 辅机上直接改了 source。`cd ~/.local/share/chezmoi && git status`，`git stash` 或 `git reset --hard origin/main` 后重跑 |
| `brew list` 仍有 nvm/pyenv/jenv | 卸载退役 formula 见实施计划 T3/T6 |

---

## 11. 日常维护速查

```bash
# 辅机拉取最新配置
chezmoi update

# 主编辑机改配置
chezmoi edit            # 编辑 source
chezmoi apply -v        # 应用本机
chezmoi diff            # 预览改动
cd ~/.local/share/chezmoi && git add -A && git commit -m "tweak" && git push

# 新增 brew 包：装完后判定归属，追加到 shared/Brewfile.{core,<hostname>}，提交 push
# 换运行时默认版本：改 ~/.local/share/chezmoi/dot_config/mise/config.toml，chezmoi apply + mise install + refresh-dev
# 装新 node/python 后重建全局包：~/.local/share/chezmoi/shared/bin/refresh-dev
```

---

## 12. 新机快速版（已读完上文，照抄）

```bash
# 0) 前置：iCloud 登录、SSH key、xcode-select --install
# 1) Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
# 2) chezmoi/mise/mas
brew install chezmoi mise mas
# 3) Claude 软链
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs
mv ~/.claude/projects ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects 2>/dev/null || true
ln -sfn ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects ~/.claude/projects
# 4) oh-my-zsh + 插件
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
# 5) dotfiles
chezmoi init --apply git@github.com:<github-user>/dotfiles.git
# 6) brew 软件
brew bundle install --file ~/.Brewfile
# 7) 运行时
mise install
# 8) 全局包
~/.local/share/chezmoi/shared/bin/refresh-dev
# 9) 验收：which node python3 java；mise current；brew bundle check --file ~/.Brewfile
```
