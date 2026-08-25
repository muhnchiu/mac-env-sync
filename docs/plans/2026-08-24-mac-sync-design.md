# 多台 Mac 环境同步方案设计


- **日期**：2026-08-24
- **范围**：用户名 `<username>` 下的任意台 Mac；当前已知三台实例——
  - Mac mini（hostname `MacMini`）
  - Pro 13（hostname `MacBookPro13`）
  - Pro 14（hostname `MacBookPro14`）
- **基线**：均为 arm64 / macOS 26.x / 用户 `<username>`；框架不限机器数量，新增机器只需追加一台专属配置，不改共享核心。
- **一致性目标**：共享核心 + 各机保留差异（非镜像）
- **状态**：三台全部接入（T1–T10 ✅，2026-08-25）；遗留：Pro 14 的 Windows App 待 App Store 登录后 `mas install 1295203466` 补装

---

## 1. 背景与问题

配置完一台 Mac，需要在其它机器上重复配置；环境差异时还要单独排查。希望用一套版本化的配置让**任意多台**机器收敛到"共享核心 + 显式声明的差异"，换机/重装可一条龙复刻。新增机器时只追加该机专属配置、不改动共享核心。

当前已对比过 Mac mini 与 Pro 13（产物 `snapshots/mini.txt` / `snapshots/pro13.txt`），主要差异点（作为设计依据的实例）：

| 维度 | Mac mini | Pro 13 |
|---|---|---|
| Node 管理 | brew `node` v24 + nvm | nvm v22 |
| Python 管理 | pyenv 3.11.14（重量级包：numpy/scipy/matplotlib/mlx/redis/pydantic/docx/pptx…） | pyenv 3.11.9（近裸装） |
| Java 管理 | jenv + JDK1.8 + brew openjdk | jenv + brew openjdk |
| PATH | 含 jenv shims / php@7.2 / lmstudio / JDK1.8 | 不含 jenv shims / php@7.2；含 `node_modules/bin` / Obsidian |
| 全局 npm 包 | 仅 corepack/npm/openclaw | 一大批（pnpm/yarn/typescript/codex/serve…） |
| brew cask | `antigravity-tools` | `azure-cli-preview` |
| /Applications | IDEA/Warp/Lark/Claude/Codex++/GarageBand/iMovie/XMind | ToDesk/AweSun/Lemon/Cogito/MarkViewer |
| GnuPG 链 | 无 | 全套（gnupg/gpgme/nss/p11-kit…） |
| 额外服务 | 无 | `postgresql@18` / `poppler` |

噪声（不纳入版本控制）：`.zcompdump*`、`.v8flags.*`、`.DS_Store`、`.claude.json.backup.*`（时间戳副本）、`new-zshrc`/`old-zshrc`/`.zshrc.backup` 等残留副本。

---

## 2. 总体架构

三个子系统各司其职：

1. **dotfiles 仓库**（git，GitHub 私有仓库 `<github-user>/dotfiles`）——由 **chezmoi** 管理。承载所有"人写、稳定"的配置与版本声明文件。
2. **分层 Brewfile**——拆 `Brewfile.core` / `Brewfile.MacMini` / `Brewfile.MacBookPro13`（按 hostname 命名），chezmoi 按 hostname 渲染入口 `~/.Brewfile`。
3. **iCloud 同步的 `~/.claude` 记忆**——会话 jsonl 频繁变动，走 iCloud 软链，实现跨机续接思考；不进 git。

**运行时统一性**：由 **mise** 接管 node + python + java，退役 nvm / pyenv / jenv 三个工具。PATH 用"条件化追加"保证同一份 shell 配置在任意台机器都跑得通。

---

## 3. 仓库结构

```
dotfiles/                         # chezmoi source = git 仓库（GitHub 私有）；source 根直接映射 $HOME
├── .gitignore                     # 排除 .zcompdump* .v8flags* .DS_Store *.backup 等
├── README.md
├── .chezmoiignore                 # 排除 shared/ 数据目录 + 各机忽略对方专属文件
├── .chezmoi.toml.tmpl             # chezmoi 自身配置模板（[data] 变量等），生成 ~/.config/chezmoi/chezmoi.toml
├── dot_zprofile.tmpl              # 条件化 PATH + mise activate（共享）
├── dot_zshrc                      # 交互 shell（prompt/fzf/zoxide/别名，共享）
├── dot_zprofile.local.tmpl        # 按 hostname 渲染该机独有的 PATH/环境
├── dot_gitconfig.tmpl             # 按机器的 user/email 差异
├── dot_wezterm.lua
├── dot_npmrc
├── dot_cnpmrc
├── private_dot_gitignore_global
├── dot_Brewfile.tmpl              # 入口：include shared/Brewfile.core + 本机 extras 拼接
├── dot_config/                    # → ~/.config/
│   ├── mise/config.toml           # node/python/java 默认版本（共享）
│   ├── nvim/                      # Neovim 配置
│   └── ghostty/                   # Ghostty 配置
├── dot_claude/                    # → ~/.claude/（Claude Code 实读 ~/.claude/CLAUDE.md，非 ~/.config/claude/）
│   ├── CLAUDE.md                  # 用户级长期记忆（共享）
│   └── settings.json              # Claude Code 设置（共享）
└── shared/                        # 数据目录，不渲染到 $HOME（靠 .chezmoiignore 排除；模板用 {{ include }} 读取）
    ├── machines.toml              # 已知机器清单（文档化，见 3.1）
    ├── Brewfile.core              # 共用
    ├── Brewfile.<hostname>        # 每机一份专属（见 3.1 实例）
    │   …（Brewfile.MacMini / Brewfile.MacBookPro13 / Brewfile.<hostname3> …）
    ├── npm-global.txt  pip-core.txt  pip-<hostname>.txt
    └── bin/refresh-dev            # 重建 npm/pip 全局包的脚本（按路径调用，不被 apply 渲染）
```

> **为什么 dot_ 文件在 source 根、`shared/` 却要 ignore？** chezmoi 把 source 根直接映射 `$HOME`：`dot_zshrc` 在根 → `~/.zshrc`；若放进 `home/` 子目录会渲染成 `~/home/.zshrc`（错误）。`shared/` 不该落进 `$HOME`，故写进 `.chezmoiignore` 排除；但 `dot_Brewfile.tmpl` 里的 `{{ include "shared/..." }}` 直接从 source 读文件，不受 ignore 影响——分层清单拼装照常生效。详见 `docs/manuals/chezmoi-guide.md` §1/§3/§11。

**chezmoi 关键机制**：
- hostname 分流：模板内 `{{- if eq (lower .chezmoi.hostname) "macmini" -}} ... {{- end -}}`（用 `lower` 比较——macOS 会把 `hostname -s` 小写化，如 Pro 13 报 `macbookpro13`，直比 `MacBookPro13` 会落空）
- 敏感文件：文件名加 `private_` 前缀 → 渲染后自动 `chmod 600`
- `.chezmoiignore`：按 hostname 忽略对方专属文件
- 模板文件用 `.tmpl` 后缀，chezmoi 自动渲染
- **新增机器的代价**：建一份 `Brewfile.<hostname>`、在 `dot_zprofile.local.tmpl` 与 `dot_Brewfile.tmpl` 各加一个 hostname 分支、在 `machines.toml` 登记一行——共享核心不动。

### 3.1 机器注册表 `shared/machines.toml`

文档化已知机器与角色，供人查阅（不直接被 chezmoi 渲染逻辑强制依赖）：

```toml
[[machine]]
hostname = "MacMini"
role     = "dev-heavy"        # 开发主力机
arch     = "arm64"
notes    = "LM Studio / JDK1.8 / 重量级 python 包"

[[machine]]
hostname = "MacBookPro13"
role     = "laptop-light"     # 轻量便携 + 远控
arch     = "arm64"
notes    = "GnuPG 链 / postgresql@18 / 远控工具"

[[machine]]
hostname = "<hostname3>"      # Pro 14，hostname 待定后填
role     = "laptop"           # 可与 13 合并同角色，或独立
arch     = "arm64"
notes    = "新增机器示例"
```

> 用 hostname 还是 role 作为分流键？当前以 **hostname** 为准（最精确、无歧义）。若多台机器配置高度相似，可在 `.chezmoi.toml` 给每台设 `data.role`，模板改用 `{{ .role }}` 判断，复用一份 extras。两者可共存。

---

## 4. 版本与包清单（mise + 共享清单）

### 4.1 mise 默认配置 `~/.config/mise/config.toml`

```toml
[tools]
node    = "24"
python  = "3.12"
java    = "temurin-21"

[settings]
experimental = true
```

> 项目级版本覆盖：在该项目目录放 `.mise.toml`，写 `[tools] node = "24"` 即可——这正是 mise 优于 nvm/pyenv/jenv 的地方。

### 4.2 共享包清单

- `shared/npm-global.txt`（一行一个包名，版本无关的"装哪些"）：
  ```
  pnpm
  yarn
  typescript
  ts-node
  cross-env
  depcheck
  npm-check-updates
  nrm
  serve
  @types/node
  @openai/codex
  @agentclientprotocol/claude-agent-acp
  # openclaw   # 视情况从 Mini 引入
  ```
- `shared/pip-core.txt`（所有机器都常用的子集）：
  ```
  pip
  setuptools
  pydantic
  openpyxl
  python-docx
  python-pptx
  PyYAML
  requests
  rich
  typer
  ```
- `shared/pip-<hostname>.txt`（某机专属重量级包，按需存在；以 Mini 为例，文件名 `pip-MacMini.txt`）：
  ```
  numpy
  scipy
  matplotlib
  mlx
  redis
  mysql-connector-python
  pymssql
  PyMySQL
  lxml
  pptx2md
  huggingface_hub
  ```

### 4.3 `shared/bin/refresh-dev`

```bash
#!/usr/bin/env bash
# 装好新 node/python 后重建全局包。强制用 mise 运行时（mise exec），不依赖 ambient PATH。
set -euo pipefail
REPO="$(chezmoi source-path 2>/dev/null || echo "$HOME/.local/share/chezmoi")"
SHARED="$REPO/shared"
# 用 chezmoi 的 hostname（与 Brewfile 分流键一致）；macOS `hostname -s` 会小写化（macbookpro13），
# 与按 chezmoi hostname 命名的 pip-<host>.txt 大小写不一致——APFS 默认大小写不敏感能侥幸匹配，
# 大小写敏感 FS 上会落空。优先取 chezmoi data 的权威值，回退 hostname -s。
HOST="$(chezmoi data 2>/dev/null | grep -o '"hostname": "[^"]*"' | head -1 | sed 's/.*"hostname": "//;s/"$//')"
[[ -z "$HOST" ]] && HOST="$(hostname -s)"

echo "==> npm 全局包（mise node）"
mise exec node -- npm --version >/dev/null 2>&1 && \
  xargs -a "$SHARED/npm-global.txt" -I{} mise exec node -- npm install -g {} || true

echo "==> python 核心 pip 包（mise python）"
mise exec python -- python --version >/dev/null 2>&1 && \
  mise exec python -- python -m pip install -r "$SHARED/pip-core.txt" || true

echo "==> 机器专属 pip 包（pip-<host>.txt 存在则装）"
[[ -f "$SHARED/pip-$HOST.txt" ]] && mise exec python -- python --version >/dev/null 2>&1 && \
  mise exec python -- python -m pip install -r "$SHARED/pip-$HOST.txt" || true

echo "==> done"
```

---

## 5. Shell 与 PATH 统一

目标：**一份 `.zprofile` + 一份 `.zshrc` 在任意台机器都跑得通**，靠条件判断而非分支文件。

### 5.1 `dot_zprofile.tmpl`（登录 shell，PATH 主体）

```zsh
# ===== Homebrew =====
eval "$(/opt/homebrew/bin/brew shellenv)"

# ===== mise（接管 node/python/java，优先级高于系统） =====
# 注入 ~/.local/share/mise/shims
eval "$(~/.local/bin/mise activate zsh)"

# ===== 条件化追加（存在才加，顺序由前到后优先级递减） =====
typeset -U path
[[ -d $HOME/.local/bin ]]            && path=($HOME/.local/bin $path)
[[ -d $HOME/.bun/bin ]]               && path=($HOME/.bun/bin $path)
[[ -d $HOME/.opencode/bin ]]          && path=($HOME/.opencode/bin $path)
[[ -d $HOME/.go/bin ]]                && path=($HOME/.go/bin $path)
[[ -d /opt/homebrew/opt/openjdk@17/bin ]] && path=(/opt/homebrew/opt/openjdk@17/bin $path)
[[ -d /usr/local/mysql/bin ]]         && path=(/usr/local/mysql/bin $path)
[[ -d /usr/local/apache-maven-3.9.12/bin ]] && path=(/usr/local/apache-maven-3.9.12/bin $path)

# ===== 机器独有（交由 dot_zprofile.local 兜底） =====
[[ -r $HOME/.zprofile.local ]] && source $HOME/.zprofile.local
```

> 删除项：原 PATH 里所有 `~/.nvm/...`、`~/.jenv/shims`、`~/.jenv/bin`、`~/.pyenv/shims`、`~/.pyenv/bin` 条目全部不再出现——交给 mise。

### 5.1.1 `dot_zprofile.local.tmpl`（按 hostname 渲染该机独有 PATH/环境）

chezmoi 把它渲染到 `~/.zprofile.local`，由上面的 `source` 行加载。每台机器一个分支，新增机器加一个分支即可：

```zsh
{{- if eq (lower .chezmoi.hostname) "macmini" }}
[[ -d $HOME/.lmstudio/bin ]] && path=($HOME/.lmstudio/bin $path)
[[ -d /Library/Java/JavaVirtualMachines/jdk-1.8.jdk/Contents/Home/bin ]] \
  && path=(/Library/Java/JavaVirtualMachines/jdk-1.8.jdk/Contents/Home/bin $path)
{{- else if eq (lower .chezmoi.hostname) "macbookpro13" }}
# Pro 13 独有的 PATH 在此（当前无）
{{- else if eq (lower .chezmoi.hostname) "<hostname3>" }}
# Pro 14 独有的 PATH 在此
{{- end }}
```

### 5.2 `dot_zshrc`（交互 shell，所有机器一致）

```zsh
# prompt
eval "$(starship init zsh)"          # prompt（已弃用 powerlevel10k/p10k，统一 starship）

# fzf / zoxide / eza
[[ -r /opt/homebrew/opt/fzf/install ]] && source <(fzf --zsh)
eval "$(zoxide init zsh)"
alias ls="eza"  alias cat="bat"  alias lg="lazygit"  alias ld="lazydocker"

# 工具
eval "$(gh copilot alias -- zsh 2>/dev/null || true)"
```

### 5.3 清理项

在每台机器上删除残留：
```bash
rm -f ~/.zshrc.backup ~/.zprofile.bak ~/new-zshrc ~/old-zshrc ~/.python-version
rm -f ~/.zcompdump* ~/.v8flags.* ~/.DS_Store
```
`.gitignore` 必含：`.zcompdump*`、`.v8flags.*`、`.DS_Store`、`*.backup`、`*.bak`。

---

## 6. 分层 Brewfile

> 从 `snapshots/mini.txt` / `snapshots/pro13.txt` 导出的实际差异，结合"共享核心"原则人工裁定。下面是**裁定后的清单**，非纯交集。命名按 `Brewfile.<hostname>`（每机一份专属），新增机器加一份对应文件即可。

### 6.1 `shared/Brewfile.core`（所有机器共用）

```ruby
# ===== taps（共用） =====
tap "homebrew/services"
tap "mongodb/brew"
tap "redis/redis"
tap "exolnet/deprecated"
tap "farion1231/ccswitch"
tap "anomalyco/tap"
tap "probezy/core"
tap "sunnyyoung/tap"

# ===== CLI 工具链 =====
brew "chezmoi"
brew "mise"
brew "gh"
brew "git"
brew "git-filter-repo"
brew "bat"
brew "eza"
brew "fd"
brew "fzf"
brew "ripgrep"
brew "zoxide"
brew "starship"
brew "tmux"
brew "neovim"
brew "tree-sitter"
brew "lazygit"
brew "lazydocker"
brew "macmon"
brew "mas"
brew "maven"
brew "go"
brew "wget"
brew "curl"
brew "ffmpeg"
brew "graphviz"
brew "ranger"
brew "reattach-to-user-namespace"
brew "rtmpdump"
brew "nginx"
brew "jmeter"
brew "cpolar"
brew "unixodbc"
brew "sqlite"

# ===== 语言运行时（由 mise 实际管理，这里不装 nvm/pyenv/jenv/node） =====
# brew "openjdk@17"   # maven 依赖会带 openjdk，无需显式

# ===== cask 共用 =====
cask "cc-switch"
cask "copyq"
cask "lulu"
cask "ngrok"
cask "open-island"
cask "redis"
cask "sequel-ace"
# cask "wechattweak-cli"  # cask 依赖 disabled depends_on macos: :sierra，当前 Homebrew 装不了；已装的保留

# ===== mas 共用 =====
mas "Keynote", id: 409183694
mas "Pages",   id: 409201541
mas "Numbers", id: 409203825
mas "Windows App", id: 1295203466
```

### 6.2 `shared/Brewfile.MacMini`（Mac mini 独有）

```ruby
tap "kilo-org/tap"
tap "lbjlaq/antigravity-manager"

brew "kilo"
brew "merve"
brew "mingw-w64"
brew "ada-url"
brew "simdjson"
brew "simdutf"
brew "fmt"
brew "hdrhistogram_c"
brew "nbytes"
brew "uvwasi"

cask "antigravity-tools"

mas "iMovie",      id: 408981434
mas "GarageBand",  id: 682658836
```

### 6.3 `shared/Brewfile.MacBookPro13`（Pro 13 独有）

```ruby
tap "azure/azure-cli"

# GnuPG 全家桶（某工具链依赖，按需保留）
brew "gnupg"
brew "gpgme"
brew "pinentry"
brew "nss"
brew "p11-kit"
brew "libgcrypt"
brew "libassuan"
brew "libksba"
brew "libgpg-error"
brew "nettle"
brew "libtasn1"
brew "npth"
brew "nspr"
brew "json-c"
brew "libusb"
brew "gpgmepp"
brew "gnutls"

brew "postgresql@18"
brew "poppler"
brew "openjpeg"
brew "direnv"
brew "antidote"
brew "bash"

cask "azure-cli-preview"
```

### 6.4 `shared/Brewfile.<hostname3>`（Pro 14 独有，hostname 确定后填）

> 新机器，专属清单待跑过 `mac-snapshot.sh` 对比后填入。当前可先建空文件占位（仅含注释），避免入口模板渲染失败。

```ruby
# Pro 14 专属，待补充
```

### 6.5 入口 `dot_Brewfile.tmpl`

```ruby
# 由 chezmoi 渲染到 ~/.Brewfile
# hostname 比较用 lower（macOS 会把 hostname -s 小写化，直比大小写敏感的 hostname 会落空）
{{- include "shared/Brewfile.core" -}}

{{- if eq (lower .chezmoi.hostname) "macmini" -}}
{{-   include "shared/Brewfile.MacMini" -}}
{{- else if eq (lower .chezmoi.hostname) "macbookpro13" -}}
{{-   include "shared/Brewfile.MacBookPro13" -}}
{{- else if eq (lower .chezmoi.hostname) "<hostname3>" -}}
{{-   include "shared/Brewfile.<hostname3>" -}}
{{- end -}}

# 新增机器：在此加一个 else if 分支，并建对应 shared/Brewfile.<hostname>
```

---

## 7. ~/.claude 记忆同步（跨机延续思考）

- **用户级记忆** `~/.claude/CLAUDE.md` 与 `settings.json` → 由 chezmoi 管，随仓库走（结构见第 3 节）。
- **会话历史** `~/.claude/projects/`（jsonl，频繁变动）→ iCloud 软链，**不进 git**：

```bash
# 每台需要续接思考的机器各跑一次
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs
mv ~/.claude/projects ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects 2>/dev/null || true
ln -sfn ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects ~/.claude/projects
```

- **续接**：在另一台进入同一工作目录（路径编码一致：`/Users/<username>/workspace` → `-Users-<username>-workspace`），跑 `claude --resume`，可见本机会话列表。
- **纪律**：同一会话不要在多台机器同时写（避免 iCloud 冲突）。
- **安全**：不要把 `.credentials.json` 等敏感文件同步到任何公开仓库。

---

## 8. 迁移注意点（退役旧工具）

在切换到 mise 之前，处理现存的 nvm / pyenv / jenv / brew node：

### 8.1 导出现状（留备份）

```bash
# 在每台机器上各跑
mkdir -p ~/env-migration-backup
brew bundle dump --file=~/env-migration-backup/Brewfile.$(hostname)
nvm ls                                    > ~/env-migration-backup/nvm-versions.txt
npm ls -g --depth=0 2>/dev/null           > ~/env-migration-backup/npm-global.txt
pyenv versions                            > ~/env-migration-backup/pyenv-versions.txt
python -m pip freeze 2>/dev/null          > ~/env-migration-backup/pip-freeze.txt
jenv versions                             > ~/env-migration-backup/jenv-versions.txt
```

### 8.2 退役与重装

```bash
# 1) 卸载旧管理器（保留备份，不删数据目录）
brew uninstall nvm pyenv jenv node          # node formula 仅 Mini 有
# 数据目录 ~/.nvm ~/.pyenv ~/.jenv 暂留作回滚，确认无误后再删

# 2) 由 mise 按共享 config.toml 装版本
mise install            # 装齐 node/python/java

# 3) 重建全局包
~/.local/share/chezmoi/shared/bin/refresh-dev
```

### 8.3 依赖说明

- `maven`（brew formula）自带 `openjdk` 依赖，brew 内部使用不受 mise 影响。
- 开发用的 `JAVA_HOME` 由 mise 设置（`mise activate` 自动导出）。
- 若某个 brew formula 报缺 java，先 `brew install openjdk` 作为系统回退。

---

## 9. 应用流程（换机 / 重装一条龙）

目标机器（任一台 Mac）从零复刻：

```bash
# 1. Homebrew（如未装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. chezmoi + mise
brew install chezmoi mise

# 3. 拉取 dotfiles 并应用
chezmoi init --apply git@github.com:<github-user>/dotfiles.git

# 4. 安装软件（core + 本机 extras，chezmoi 已渲染 ~/.Brewfile）
brew bundle install --file ~/.Brewfile

# 5. ~/.claude 记忆软链（见第 7 节命令）

# 6. mise 装版本 + 重建全局包
mise install
~/.local/share/chezmoi/shared/bin/refresh-dev

# 7. 续接思考
claude --resume
```

---

## 10. 日常维护

- **改配置**：编辑 chezmoi source（`chezmoi edit`）→ `chezmoi apply` → 提交 push。
- **另一台同步**：`chezmoi update`（拉取 + apply）。
- **新增 brew 包**：装完后 `brew bundle dump`，按归属追加到 `Brewfile.core` / `Brewfile.MacMini` / `Brewfile.MacBookPro13`，提交。
- **新增全局 npm/pip 包**：手动追加到 `npm-global.txt` / `pip-core.txt`，另一台 `refresh-dev`。

---

## 11. 执行顺序（建议分批，可勾选）

- [x] **阶段 0 · 准备**：GitHub 私有仓库 `<github-user>/dotfiles`（已就绪）；iCloud 可用（已就绪）；确定第三台（Pro 14）的 hostname。
- [x] **阶段 1 · 导出现状**：每台机器各跑第 8.1 节命令，留备份。
- [x] **阶段 2 · 建 dotfiles 仓库骨架**：先在一台（如 Mac mini）上 `chezmoi init`，按第 3 节建目录结构，填入第 4/5/6 节的配置文件与清单；在 `shared/machines.toml` 登记全部已知机器。
- [x] **阶段 3 · 首次 apply（首台）**：`chezmoi apply` → 验证 `.zshrc/.zprofile/mise 配置` 生效。
- [x] **阶段 4 · 退役旧工具（首台）**：跑第 8.2 节，`brew uninstall nvm pyenv jenv node` → `mise install` → `refresh-dev`。
- [~] **阶段 5 · 同步其余机器**（Pro 13 ✅；Pro 14 待 T9）：在每台其它机器上 `chezmoi init --apply git@github.com:<github-user>/dotfiles.git` → `brew bundle install --file ~/.Brewfile` → 第 4-5 步。新增机器前先跑 `mac-snapshot.sh`，按对比结果填该机专属 `Brewfile.<hostname>` 与 `.chezmoiignore`。
- [x] **阶段 6 · ~/.claude 记忆软链**：每台机器各跑第 7 节命令。
- [x] **阶段 7 · 清理噪声**：每台跑第 5.3 节清理命令；确认 `.gitignore` 生效。
- [ ] **阶段 8 · 验收**（T10 待全局验收）：在任一台上 `claude --resume` 可见其它机器的会话；每台 `which node python java` 均指向 mise shims；`brew bundle check` 通过。
