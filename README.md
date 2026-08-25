# mac-env-sync

多台 Mac 环境同步方案的项目仓库。当前已知实例：Mac mini / MacBook Pro 13 / MacBook Pro M4 Pro；框架按"任意台 Mac"设计，新增机器只追加专属配置、不改共享核心。

- **设计文档**：`docs/plans/2026-08-24-mac-sync-design.md`（必读，完整原理与分阶段执行清单）
- **chezmoi 操作指南**：`docs/manuals/chezmoi-guide.md`（chezmoi 机制/命令/模板/同步/坑，贴合本项目 dotfiles 结构）
- **采集脚本**：`scripts/mac-snapshot.sh`（多机差异对比用）

---

## 1. 机器清单与角色

| 机器 | hostname | 角色 | 定位 | 备注 |
|---|---|---|---|---|
| Mac mini | `MacMini` | **主编辑机**（primary） | 固定、常开、软件最全，作为 dotfiles 的"事实来源" | chezmoi source 在此首次编写并 push |
| MacBook Pro 13 | `MacBookPro13` | 辅机（auxiliary） | 便携 + 远控，从仓库同步 | GnuPG 链 / postgresql@18 / 远控工具 |
| MacBook Pro M4 Pro | `<hostname3>`（待定） | 辅机（auxiliary） | 便携高性能，从仓库同步 | 新增机器，hostname 确定后填 |

### "主编辑机"是什么意思

不是性能高低，而是**工作流约定**：

- **主编辑机**：在这台机器上跑 `chezmoi edit` 改配置、`chezmoi apply` 验证、`git push` 推到 GitHub。配置变更的源头都在这里。
- **辅机**：跑 `chezmoi update`（拉取 + apply）即可，**不在辅机上直接改 chezmoi source**，避免和主编辑机的改动冲突。

约定 Mac mini 为主编辑机，因为它固定、常开、装得最全，最适合做"改完即验"的基准机。任何时候都可在任一机临时改，但记得改完 `git push`，回主编辑机再同步一次。

---

## 2. 两个仓库别搞混（重要）

本项目里有**两个不同的 git 仓库**，分别走不同同步通道：

| 仓库 | 内容 | 同步方式 | 位置 |
|---|---|---|---|
| **`mac-env-sync`**（本项目） | 设计文档 + 采集脚本 | **iCloud**（方便无 GitHub 的机器也能看文档） | iCloud Drive `mac-env-sync/`，原路径有软链 |
| **`dotfiles`**（待建） | 实际配置文件（chezmoi source） | **GitHub 私有仓库** | GitHub `<github-user>/dotfiles`，本机 chezmoi source 目录 |

> `mac-env-sync` 只是"说明书 + 工具脚本"，**不包含**你实际的 `.zshrc` 等配置。真正生效的配置在 `dotfiles` 仓库里，由 chezmoi 管理。

---

## 3. 两条 iCloud 软链（已设置）

机器上现有两条指向 iCloud 的软链，作用不同：

```bash
# 软链 1：项目本体（iCloud 存真身，工作区留软链方便习惯路径访问）
/Users/<username>/workspace/mac-env-sync
  -> ~/Library/Mobile Documents/com~apple~CloudDocs/mac-env-sync

# 软链 2：Claude 会话记忆（跨机续接思考）
~/.claude/projects
  -> ~/Library/Mobile Documents/com~apple~CloudDocs/claude-projects
```

- **软链 1** 的作用：让 `mac-env-sync` 项目随 iCloud 在多台机器可见，无需 GitHub。
- **软链 2** 的作用：让 `claude --resume` 的会话历史（jsonl）随 iCloud 在多台机器可见，实现跨机续接思考。
- **共同纪律**：同一个文件**不要在两台机器同时写**。会话历史尤其如此——同一会话只在一台机上跑，避免 iCloud 冲突。

> 若在新机器上重建这两条软链，命令见第 5 节。

---

## 4. 完整搭建命令（在一台"新机器"上从零复刻）

> 前置：已装 Homebrew、iCloud 已登录。机器分两类：主编辑机（Mac mini）首次建仓库走第 4.1 节；辅机同步走第 4.2 节。

### 4.1 主编辑机首次搭建（Mac mini，仅一次）

```bash
# 0) 装基础工具
brew install chezmoi mise mas

# 1) 初始化 chezmoi source 目录（默认 ~/.local/share/chezmoi）
chezmoi init
cd ~/.local/share/chezmoi

# 2) 关联已建好的 GitHub 私有仓库 <github-user>/dotfiles
git remote add origin git@github.com:<github-user>/dotfiles.git

# 3) 按设计文档第 3/4/5/6 节，在 source 目录里创建文件结构（dot_ 文件放根，映射 $HOME）：
#    dot_zprofile.tmpl  dot_zshrc  dot_zprofile.local.tmpl
#    dot_Brewfile.tmpl  dot_config/mise/config.toml  dot_config/claude/...
#    shared/Brewfile.core  shared/Brewfile.MacMini  shared/Brewfile.MacBookPro13
#    shared/npm-global.txt  shared/pip-core.txt  shared/bin/refresh-dev
#    shared/machines.toml   .chezmoiignore（含 shared）   .gitignore
#    （内容直接抄 docs/plans/2026-08-24-mac-sync-design.md 对应章节）

# 4) 导出本机现状作备份，再退役旧工具（见设计文档第 8 节）
mkdir -p ~/env-migration-backup
brew bundle dump --file=~/env-migration-backup/Brewfile.$(hostname -s)
nvm ls > ~/env-migration-backup/nvm-versions.txt 2>/dev/null || true
npm ls -g --depth=0 > ~/env-migration-backup/npm-global.txt 2>/dev/null || true
pyenv versions > ~/env-migration-backup/pyenv-versions.txt 2>/dev/null || true
python -m pip freeze > ~/env-migration-backup/pip-freeze.txt 2>/dev/null || true
jenv versions > ~/env-migration-backup/jenv-versions.txt 2>/dev/null || true

# 5) 应用配置到本机
chezmoi apply -v

# 6) 退役旧运行时管理器，交由 mise
brew uninstall nvm pyenv jenv           # 主编辑机执行；node formula 仅 Mini 有，一并 brew uninstall node
mise install                             # 按共享 config.toml 装齐 node/python/java
chmod +x ~/.local/share/chezmoi/shared/bin/refresh-dev
~/.local/share/chezmoi/shared/bin/refresh-dev   # 重建全局 npm/pip 包

# 7) 安装 brew 软件（chezmoi 已渲染 ~/.Brewfile）
brew bundle install --file ~/.Brewfile

# 8) 建 Claude 记忆软链（见第 5 节软链 2 命令）

# 9) 提交并推送
cd ~/.local/share/chezmoi
git add -A && git commit -m "init: dotfiles baseline" && git push -u origin main
```

### 4.2 辅机同步（MacBook Pro 13 / M4 Pro，每台各一次）

```bash
# 0) 装基础工具
brew install chezmoi mise mas

# 1) 拉 dotfiles 并应用（chezmoi 会按本机 hostname 渲染对应配置）
chezmoi init --apply git@github.com:<github-user>/dotfiles.git

# 2) 退役旧工具（同主编辑机第 5 步）
brew uninstall nvm pyenv jenv            # node formula 若有也一并卸
mise install
~/.local/share/chezmoi/shared/bin/refresh-dev

# 3) 安装本机专属 + 共享 brew 软件
brew bundle install --file ~/.Brewfile

# 4) 建 Claude 记忆软链（见第 5 节软链 2 命令）

# 5) 续接思考（验证会话已跨机可见）
claude --resume
```

### 4.3 新增一台全新机器（如 M4 Pro）

```bash
# 1) 先采集快照，产出差异（在主编辑机上对比）
bash "/Users/<username>/workspace/mac-env-sync/scripts/mac-snapshot.sh" > m4pro.txt
#   或直接走 iCloud 路径：
bash ~/Library/Mobile\ Documents/com~apple~CloudDocs/mac-env-sync/scripts/mac-snapshot.sh > m4pro.txt

# 2) 对照已有 mini.txt / pro.txt，确定 M4 Pro 专属要装什么，
#    在 dotfiles 仓库新增 shared/Brewfile.<hostname3>，
#    在 dot_Brewfile.tmpl 加一个 else if 分支，
#    在 dot_zprofile.local.tmpl 加一个 hostname 分支（若有独有 PATH），
#    在 shared/machines.toml 登记一行。提交 push。

# 3) 在 M4 Pro 上走第 4.2 节辅机同步流程即可。
```

---

## 5. 两条 iCloud 软链的重建命令

在任一台新机器上执行（iCloud 登录后）：

```bash
# 软链 1：项目本体（mac-env-sync 走 iCloud）
#   前提：iCloud 已把 mac-env-sync 同步到本机
ln -sfn ~/Library/Mobile\ Documents/com~apple~CloudDocs/mac-env-sync \
        /Users/<username>/workspace/mac-env-sync

# 软链 2：Claude 会话记忆
mv ~/.claude/projects ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects 2>/dev/null || true
ln -sfn ~/Library/Mobile\ Documents/com~apple~CloudDocs/claude-projects ~/.claude/projects
```

> 验证软链是否生效：`ls -ld ~/.claude/projects`、`ls -ld /Users/<username>/workspace/mac-env-sync`，应显示 `->` 指向 iCloud 路径。

---

## 6. 日常维护命令速查

### 改配置（在主编辑机 Mac mini 上）

```bash
chezmoi edit            # 用编辑器改 chezmoi source（默认 ~/.local/share/chezmoi）
chezmoi apply -v        # 应用到本机
cd ~/.local/share/chezmoi && git add -A && git commit -m "tweak: ..." && git push
```

### 辅机拉取最新配置

```bash
chezmoi update          # = git pull + apply
```

### 新增 brew 包

```bash
# 装完包后，判断归属（共享 or 某机专属），手动追加到对应文件：
#   共享 → shared/Brewfile.core
#   Mini 专属 → shared/Brewfile.MacMini
#   Pro 专属 → shared/Brewfile.MacBookPro13
# 然后提交 push；辅机 chezmoi update 后 brew bundle install --file ~/.Brewfile
```

### 新增全局 npm / pip 包

```bash
# 手动追加到 ~/.local/share/chezmoi/shared/npm-global.txt 或 pip-core.txt
# 任一台装了新 node/python 版本后，一条命令重建：
~/.local/share/chezmoi/shared/bin/refresh-dev
```

### 换 node/python/java 默认版本

```bash
# 改 ~/.local/share/chezmoi/dot_config/mise/config.toml 的 [tools]
chezmoi apply -v
mise install          # 装新版本
refresh-dev           # 重建全局包
```

### 验收检查（随时跑）

```bash
which node python java          # 三者都应指向 ~/.local/share/mise/shims（或 mise 注入路径）
brew bundle check --file ~/.Brewfile   # 应输出 "All dependencies are satisfied"
claude --resume                 # 应看到跨机会话列表
```

---

## 7. 故障排查

| 现象 | 排查 |
|---|---|
| `chezmoi update` 报冲突 | 多半是辅机上直接改了 source。`cd ~/.local/share/chezmoi && git status`，stash 或 reset 后重跑 `chezmoi update` |
| iCloud 软链"未下载"打不开 | iCloud 对小文件按需下载。`brctl download <path>` 或在 Finder 里点开触发下载；首次等几秒 |
| `which node` 不指向 mise | 检查 `.zprofile` 里 `eval "$(~/.local/bin/mise activate zsh)"` 是否在 Homebrew 之后、其它路径之前；`mise doctor` |
| `brew bundle check` 报缺包 | `brew bundle install --file ~/.Brewfile` 补齐 |
| 某会话在另一台看不到 | 确认软链 2 已建；该会话 jsonl 是否已 iCloud 同步（看 `~/.claude/projects/` 内文件） |
| 残留 `.zcompdump*`/`.v8flags.*` 又冒出来 | 正常，是机器自生成；`.gitignore` 已忽略，不影响仓库 |

---

## 8. 关键纪律（时间久了也要记得的）

1. **只在主编辑机改 chezmoi source**，改完 `git push`；辅机只 `chezmoi update`。
2. **同一会话不在两台机同时写**（Claude jsonl 会冲突）。
3. **`dotfiles` 仓库（实际配置）走 GitHub，不走 iCloud**；`mac-env-sync`（本项目/文档）走 iCloud。两者别混。
4. **新增机器**：先 `mac-snapshot.sh` 采集 → 填专属 `Brewfile.<hostname>` + 模板分支 + `machines.toml` 登记 → push → 新机走辅机同步流程。共享核心不动。
5. **退役过的工具**：nvm / pyenv / jenv / brew `node` formula 已全部退役，运行时统一由 mise 管。别再手装 node/python/java。
6. **敏感文件**：`.credentials.json` 等绝不进任何仓库；chezmoi 里用 `private_` 前缀保护敏感配置。
7. **备份**：退役旧工具前先跑设计文档第 8.1 节导出现状到 `~/env-migration-backup/`，留作回滚依据。

---

## 9. 文件结构（本项目）

```
mac-env-sync/
├── README.md                          # 本文件
├── docs/
│   ├── plans/
│   │   ├── 2026-08-24-mac-sync-design.md   # 完整设计文档（原理）
│   │   └── 2026-08-24-mac-sync-plan.md    # 实施计划（任务 checklist，持续更新）
│   └── manuals/
│       ├── chezmoi-guide.md                 # chezmoi 操作指南（机制/命令/模板/同步/坑）
│       └── new-machine-setup.md            # 新机操作手册（从装 chezmoi 起的详细步骤）
└── scripts/
    └── mac-snapshot.sh                # 环境采集脚本（多机差异对比）
```

> 实际配置仓库（`dotfiles`）的结构见设计文档第 3 节，不在此项目内。
