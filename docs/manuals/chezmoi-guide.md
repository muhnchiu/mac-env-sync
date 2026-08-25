# chezmoi 操作指南

> chezmoi 是管理 dotfiles（配置文件）的工具，是本项目"多机环境同步"的底层引擎。
> 本文档讲清 **chezmoi 怎么用、为什么这么用**，并贴合本项目 `<github-user>/dotfiles` 仓库的真实结构。
>
> 配套关系（别读错文档）：
> - 本文：chezmoi 的**操作机制与命令**（概念 / 命令 / 模板 / 同步 / 坑）。
> - `docs/manuals/new-machine-setup.md`：从零到就绪的**完整新机流程**（装 brew → 装 chezmoi → apply → 装软件）。
> - `docs/plans/2026-08-24-mac-sync-design.md`：方案**原理与设计**（为什么分层 Brewfile、为什么退役 nvm/pyenv/jenv）。
> - `README.md`：项目总览与日常速查。

---

## 1. 心智模型（先理解这一节，命令才不会用错）

chezmoi 有三处位置，关系是**单向渲染**：

| 位置 | 是什么 | 本机路径 |
|---|---|---|
| **source 目录** | 真相来源：你手写/编辑的模板，文件名编码状态 | `~/.local/share/chezmoi` |
| **target 目录** | 渲染后生效的真身，即 `$HOME` | `/Users/<username>` |
| **state 数据库** | 记录上次写入的权限/内容，供 diff/apply 判断是否被外部改动过 | `~/.config/chezmoi/chezmoistate.boltdb` |

核心规则（已用实验验证，见 §11）：

- **source 的根目录直接映射 `$HOME`**。`source/dot_zshrc` → `~/.zshrc`；`source/dot_config/nvim/init.lua` → `~/.config/nvim/init.lua`。
- 放在子目录里的 dot 文件会渲染到同名子目录：`source/home/dot_zshrc` → `~/home/.zshrc`（**错**，见 §11 坑 1）。**dot_ 文件必须放在 source 根。**
- source 里**所有**非 `.` 开头的文件/目录都会被渲染到 target，除非写进 `.chezmoiignore`。因此只被 `{{ include }}` 读取、不该落进 `$HOME` 的数据目录（本项目的 `shared/`）必须显式忽略。
- `chezmoi edit` 改的是 **source**，不是 target。直接 `vim ~/.zshrc` 改的是 target，下次 `apply` 会被 source 覆盖。

一句话：**source 是真相，target 是渲染结果；永远在 source 上编辑。**

---

## 2. 文件名编码规则

source 里的文件名前缀即语义，chezmoi 据此决定 target 的名字、权限、是否模板：

| 前缀 | 含义 | 示例 → target |
|---|---|---|
| `dot_` | 目标以 `.` 开头 | `dot_zshrc` → `~/.zshrc` |
| `private_` | 权限 `0600` | `private_dot_ssh/config` → `~/.ssh/config` (0600) |
| `executable_` | 权限 `0755` | `executable_bin/x` → `~/.local/bin/x` (0755) |
| `empty_` | 内容为空也创建文件 | `empty_dot_editorconfig` → `~/.editorconfig` |
| `…​.tmpl` | 当作模板渲染 | `dot_gitconfig.tmpl` → `~/.gitconfig` |
| `.chezmoiignore` | 忽略列表 | 不渲染 |
| `.chezmoi.toml.tmpl` | chezmoi 自身配置模板 | 生成 `~/.config/chezmoi/chezmoi.toml` |

前缀可叠加：`private_dot_gitconfig.tmpl` = 模板 + 权限 0600。

目录的 `dot_` 前缀同理：`dot_config/` → `~/.config/`。

---

## 3. 本项目 dotfiles 仓库结构（chezmoi 正确形式）

> ⚠️ **易错点**：chezmoi 把 source 根直接映射 `$HOME`，把 dot_ 文件放进 `home/` 子目录会渲染成 `~/home/.zshrc`（已实验验证，见 §11 坑①）。下列是 chezmoi 正确形式：dot_ 文件在 **source 根**，`shared/` 用 `.chezmoiignore` 排除。（设计文档 §3 结构图已据此修正。）

```
~/.local/share/chezmoi/            # = dotfiles git 仓库（GitHub: <github-user>/dotfiles）
├── .gitignore
├── .chezmoiignore                 # 至少含 shared/（见下），并按 hostname 忽略它机专属
├── .chezmoi.toml.tmpl             # chezmoi 自身配置（如 [data] 变量），生成 ~/.config/chezmoi/chezmoi.toml
├── dot_zprofile.tmpl              # 登录 shell：PATH + mise activate（共享，条件化追加）
├── dot_zshrc                      # 交互 shell（共享）
├── dot_zprofile.local.tmpl        # 按 hostname 渲染该机独有 PATH
├── dot_gitconfig.tmpl             # 按机器 user/email
├── dot_Brewfile.tmpl              # 入口：include shared/Brewfile.core + 本机专属
├── private_dot_gitignore_global
├── dot_p10k.zsh  dot_wezterm.lua  dot_npmrc  dot_cnpmrc
├── dot_config/                    # → ~/.config/
│   ├── mise/config.toml           # node/python/java 默认版本（共享）
│   ├── nvim/  ghostty/
│   └── claude/CLAUDE.md  settings.json
└── shared/                         # ⚠️ 数据目录，不渲染到 $HOME（靠 .chezmoiignore 排除）
    ├── machines.toml              # 机器注册表（文档用）
    ├── Brewfile.core              # 共用
    ├── Brewfile.MacMini  Brewfile.MacBookPro13  Brewfile.<hostname3>
    ├── npm-global.txt  pip-core.txt  pip-<hostname>.txt
    └── bin/refresh-dev            # 重建全局包脚本（apply 不渲染它，直接用路径调用）
```

**`shared/` 为什么不渲染却能用？**
- `.chezmoiignore` 里写一行 `shared` → chezmoi 不把它渲染到 `~/shared/`。
- `dot_Brewfile.tmpl` 里 `{{ include "shared/Brewfile.core" }}` 直接从 source 读文件内容拼进模板——`include` 读的是 source 文件，不受 ignore 影响（已验证）。
- `shared/bin/refresh-dev` 用绝对路径调用：`~/.local/share/chezmoi/shared/bin/refresh-dev`，不需要它被渲染进 `$HOME`。

---

## 4. 首次接入（简版，详流程见 new-machine-setup.md）

### 4.1 主编辑机建仓（Mac mini，仅一次）
```bash
chezmoi init                              # 建空 source（~/.local/share/chezmoi）
cd ~/.local/share/chezmoi
git remote add origin git@github.com:<github-user>/dotfiles.git
# 按 §3 在 source 根创建文件（内容抄设计文档第 3-6 节，dot_ 放根、shared/ 放根并写进 .chezmoiignore）
chezmoi apply -v                          # 渲染到本机
git add -A && git commit -m "init: dotfiles baseline" && git push -u origin main
```

### 4.2 辅机拉取（Pro 13 / Pro 14，每台一次）
```bash
chezmoi init --apply git@github.com:<github-user>/dotfiles.git   # 克隆 + 按本机 hostname 渲染 + apply
```
> `init --apply` 会覆盖本机现有 `~/.zshrc` 等。想保留先备份：`mkdir -p ~/env-migration-backup && cp ~/.zshrc ~/.zprofile ~/env-migration-backup/`。

---

## 5. 日常四件套（80% 时间用这四条）

```bash
chezmoi status        # 列出 source 与 target 不一致的文件（只看清单）
chezmoi diff          # 打印具体差异内容（只看，不改）
chezmoi apply         # 把 source 状态写回 $HOME（执行改动）
chezmoi edit ~/.zshrc # 用 $EDITOR 打开 source 里的 dot_zshrc（不是 target）
```

典型循环（在主编辑机）：
```
chezmoi edit ~/.zshrc → 改 → 保存 → chezmoi diff → 确认 → chezmoi apply → git commit & push
```

> ⚠️ `chezmoi apply` 会**覆盖** target 上你手改的改动。apply 前一定先 `chezmoi diff` 确认差异方向。

---

## 6. 常用命令速查

| 命令 | 作用 |
|---|---|
| `chezmoi add ~/.vimrc` | 把 target 文件首次纳入管理（生成 source 文件，文件名按编码规则） |
| `chezmoi add --recursive ~/.config/nvim` | 递归纳入整个目录 |
| `chezmoi forget ~/.vimrc` | 停止管理某文件（只从 source 移除，**不删 target**） |
| `chezmoi remove ~/.vimrc` | 从 source 和 target **都删除** |
| `chezmoi edit` | 用编辑器打开整个 source 目录 |
| `chezmoi cat ~/.gitconfig` | 打印该文件的**渲染后**内容（不写盘，看模板结果） |
| `chezmoi cd` | 进 source 目录；退出 shell 自动回原目录 |
| `chezmoi source-path` | 打印 source 目录绝对路径 |
| `chezmoi data` | 查看模板可用变量（`.chezmoi.*` + `[data]` 里自定义的） |
| `chezmoi doctor` | 体检：编辑器、source、git 等环境检查 |
| `chezmoi update` | 辅机用：`git pull` source + `apply` |
| `chezmoi execute-template < f.tmpl` | 手动渲染模板，调试用 |
| `chezmoi git -- status` | 对 source 仓库跑任意 git 子命令（`--` 后接 git 参数） |

---

## 7. 模板：跨机器差异

文件名加 `.tmpl` 即当模板处理。模板用 Go template 语法。

### 7.1 内置变量（`chezmoi data` 可查）
```
.chezmoi.os          darwin
.chezmoi.arch        arm64
.chezmoi.hostname    MacMini / MacBookPro13
.chezmoi.username    <username>
.chezmoi.sourceDir   /Users/<username>/.local/share/chezmoi
```

### 7.2 hostname 分流（本项目核心机制）

`dot_zprofile.local.tmpl`（渲染到 `~/.zprofile.local`）：
```go
{{- if eq .chezmoi.hostname "MacMini" }}
[[ -d $HOME/.lmstudio/bin ]] && path=($HOME/.lmstudio/bin $path)
{{- else if eq .chezmoi.hostname "MacBookPro13" }}
# Pro 独有 PATH（当前无）
{{- else if eq .chezmoi.hostname "<hostname3>" }}
# Pro 14 独有 PATH
{{- end }}
```

`dot_Brewfile.tmpl`（渲染到 `~/.Brewfile`，用 `include` 拼分层清单）：
```go
{{- include "shared/Brewfile.core" -}}
{{- if eq .chezmoi.hostname "MacMini" -}}
{{-   include "shared/Brewfile.MacMini" -}}
{{- else if eq .chezmoi.hostname "MacBookPro13" -}}
{{-   include "shared/Brewfile.MacBookPro13" -}}
{{- else if eq .chezmoi.hostname "<hostname3>" -}}
{{-   include "shared/Brewfile.<hostname3>" -}}
{{- end -}}
```

### 7.3 自定义变量（`chezmoi.toml`）
`~/.config/chezmoi/chezmoi.toml`（可由 source 里的 `.chezmoi.toml.tmpl` 首次生成）：
```toml
[data]
    name = "<username>"
    email = "you@example.com"
```
模板里即可 `{{ .name }}` / `{{ .email }}`（如 `dot_gitconfig.tmpl`）。

### 7.4 调试模板
```bash
chezmoi data                              # 看当前机器所有变量值
chezmoi cat ~/.zprofile.local             # 看渲染后内容（不写盘）
chezmoi execute-template < dot_Brewfile.tmpl   # 手动渲染，看 include 拼接结果
```

---

## 8. Git 同步（source 仓库本身）

source 目录本身是个 git 仓库（`<github-user>/dotfiles`）。chezmoi 帮你跑 git，但也可以手动。

### 8.1 主编辑机：改完推送
```bash
chezmoi edit ~/.zshrc
chezmoi apply -v
chezmoi git -- add -A
chezmoi git -- commit -m "tweak: zshrc 别名"
chezmoi git -- push
# 或直接 cd 进去手动操作：
chezmoi cd && git add -A && git commit -m "..." && git push
```

### 8.2 辅机：拉取并应用
```bash
chezmoi update          # = git pull + apply
```

### 8.3 关联新 remote（仅主编辑机首次）
```bash
chezmoi cd
git remote add origin git@github.com:<github-user>/dotfiles.git
```

> 纪律：**只在主编辑机改 source**，辅机只 `chezmoi update`。辅机上直接改 source 会导致 `chezmoi update` 冲突。

---

## 9. 敏感文件

- **权限保护**：文件名加 `private_` 前缀 → 渲染后自动 `chmod 600`。如 `private_dot_ssh/config`。
- **加密存储**（密钥类，连内容都不想明文进 git）：用 age/gpg 加密。
  ```bash
  brew install age
  chezmoi edit --encrypt ~/.ssh/config   # source 存为 .age 密文，apply 时解密
  ```
- **绝不进仓库**：`.credentials.json`、`.netrc` 等写进 `.chezmoiignore`，连 source 都不放。

---

## 10. 新增一台机器的 chezmoi 侧改动

新机器（如 Pro 14，hostname 确定后）接入，在 source 里改这 5 处（共享核心不动）：

1. **`shared/Brewfile.<hostname3>`**：建该机专属清单（先跑 `mac-snapshot.sh` 对比后填；可先建空占位文件避免模板渲染失败）。
2. **`dot_Brewfile.tmpl`**：加一个 `else if eq .chezmoi.hostname "<hostname3>"` 分支 include 上面的专属文件。
3. **`dot_zprofile.local.tmpl`**：加一个该机 hostname 分支（若有独有 PATH）。
4. **`shared/machines.toml`**：登记一行。
5. **`.chezmoiignore`**：按需忽略该机不该有的它机专属文件。

提交 push 后，新机走 `chezmoi init --apply git@github.com:<github-user>/dotfiles.git` 即可（见 new-machine-setup §5A）。

---

## 11. 常见坑

| 坑 | 原因 / 解决 |
|---|---|
| **① `home/` 子目录里的 dot 文件不生效** | chezmoi 把 source 根映射 `$HOME`，`home/dot_zshrc` 渲染成 `~/home/.zshrc`。**dot_ 文件必须放 source 根。**（设计文档 §3 原把 dot_ 画在 `home/` 下，已修正；见本文 §3 警告） |
| **② apply 覆盖了手动改动** | 你直接改了 target（`vim ~/.zshrc`）而 source 没更新，apply 把 target 改回 source。养成只在 source 上编辑的习惯（`chezmoi edit`）。 |
| **③ `shared/` 跑进 `~/shared/`** | `shared/` 默认会被渲染。必须在 `.chezmoiignore` 里写 `shared` 排除。`{{ include "shared/..." }}` 不受影响，仍能读。 |
| **④ 忘了 commit / push** | source 的改动不进 git 就不会同步。改完务必 `chezmoi git -- add -A && commit && push`。 |
| **⑤ `chezmoi update` 冲突** | 辅机上直接改了 source。`chezmoi cd && git status`，`git stash` 或 `git reset --hard origin/main` 后重跑 `chezmoi update`。 |
| **⑥ `add` 了不该上传的文件** | `chezmoi add ~/.config` 会把整个目录纳进去，易夹带敏感/噪声。逐个 add，或在 `.chezmoiignore` / `.gitignore` 先排除。 |
| **⑦ `dot_Brewfile.tmpl` include 报找不到** | 路径相对 source 根，写成 `shared/Brewfile.core`（不带前导 `./`）；确认 `shared/` 确实在 source 根下。 |
| **⑧ 模板没渲染、原样输出 `{{ }}`** | 文件名漏了 `.tmpl` 后缀；chezmoi 只对 `.tmpl` 文件做渲染。 |

---

## 12. 验收 / 体检

随时跑这些确认环境健康：

```bash
chezmoi doctor                       # 环境体检（编辑器、source、git）
chezmoi status                       # source 与 target 是否一致
chezmoi diff                         # 具体差异（apply 前必看）
chezmoi data | grep -A2 chezmoi      # 当前机器的 hostname/os/arch
chezmoi cat ~/.Brewfile              # 渲染后的 Brewfile（看 hostname 分流对不对）
ls ~/.zshrc ~/.zprofile ~/.Brewfile ~/.config/mise/config.toml   # 关键文件已落地
```

**全绿则 chezmoi 侧配置完成。** 运行时 / brew / 全局包的验收见 `new-machine-setup.md` §9。
