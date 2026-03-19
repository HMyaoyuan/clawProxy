# clawProxy

帮助 AI 编程助手（OpenClaw 等）在 Linux VM 环境中一键配置网络代理，访问 GitHub、Google Scholar 等学术资源。

> **声明**：本项目仅供学术研究与技术学习用途，严禁用于任何违法行为。使用者必须遵守所在国家和地区的法律法规。使用本项目即表示您已阅读并同意 [用户声明](DISCLAIMER.md)。

## 发给 AI 助手的一句话指令

复制下面这段话发给你的 AI 编程助手，它就会自动帮你配置代理：

> 请克隆这个仓库并按照里面的技能指南帮我配置网络代理：`git clone https://github.com/HMyaoyuan/clawProxy.git && cd clawProxy && cat SKILL.md`，按照 SKILL.md 的步骤一步步操作，过程中需要的信息请直接问我。

## 它能做什么

项目包含预编译的代理客户端二进制文件和一套 AI 友好的操作指南。AI 助手会：

1. 自动安装代理客户端（无需联网下载，已内置）
2. **主动问你要** 代理订阅链接
3. **主动问你选** 全局代理（推荐）还是智能分流
4. 启动代理后 **主动展示** 可用节点列表，**问你选哪个**
5. 启动守护进程，**自动监控代理健康** 并在节点故障时自动切换
6. 自动验证代理是否生效并告知结果

### 为什么默认推荐全局代理？

智能分流模式下，部分请求走代理、部分直连，出口 IP 会频繁切换，容易导致服务不稳定甚至会话中断。全局代理确保所有流量通过同一出口，连接更稳定。

### 防失联保留方案

代理环境下最大的风险是节点失效导致 AI 助手与用户失联。本项目内置了三层保护：

1. **守护进程（watchdog）** — 后台每 30 秒检测代理健康，连续失败后自动切换到其他可用节点
2. **自动回退** — 当所有节点都不可用时，守护进程自动切换到直连模式，确保通信不中断
3. **紧急回退脚本** — AI 助手可随时执行 `source scripts/fallback.sh` 一键恢复直连

## 前提条件

- 你拥有一个 **Clash 格式** 的代理订阅链接（从你的代理服务商获取）
- AI 助手运行在 Linux 环境（amd64 或 arm64）

## 项目结构

```
clawProxy/
├── SKILL.md                  # AI 技能入口
├── skills/                   # 分步操作指南
│   ├── 01-setup.md           # 安装代理客户端
│   ├── 02-configure.md       # 获取订阅链接并配置
│   ├── 03-start.md           # 启动代理
│   ├── 04-select-node.md     # 选择节点
│   ├── 05-verify.md          # 验证连接
│   └── 06-troubleshoot.md    # 故障排查
├── scripts/                  # 自动化脚本
│   ├── install.sh            # 安装（优先用内置二进制）
│   ├── configure.sh          # 生成配置
│   ├── start.sh / stop.sh    # 启停代理
│   ├── set-proxy-env.sh      # 设置代理环境变量
│   ├── unset-proxy-env.sh    # 取消代理环境变量
│   ├── switch-mode.sh        # 切换模式（rule/global/direct）
│   ├── select-node.sh        # 查看/切换节点
│   ├── watchdog.sh           # 守护进程（健康检查 + 自动切换节点）
│   ├── fallback.sh           # 紧急回退（一键恢复直连）
│   └── verify.sh             # 验证连接
├── bin/                      # 预编译的 mihomo 二进制（免下载）
│   ├── mihomo-linux-amd64.gz
│   └── mihomo-linux-arm64.gz
├── config/
│   └── config-template.yaml  # 配置模板
└── .env.example              # 配置示例
```

## 技术方案

使用 [mihomo](https://github.com/MetaCubeX/mihomo)（原 Clash Meta）作为代理客户端：

- 二进制已内置在 `bin/` 目录，无需从 GitHub 下载（解决运行环境网络受限的问题）
- 兼容主流 Clash 订阅格式
- 用户态运行，不需要 root 权限
- 本地 HTTP 代理 `7890`，SOCKS5 代理 `7891`，API 控制 `9090`

## 手动使用

```bash
git clone https://github.com/HMyaoyuan/clawProxy.git
cd clawProxy
bash scripts/install.sh                       # 安装
echo 'SUBSCRIBE_URL=你的链接' > .env           # 配置订阅
bash scripts/configure.sh                     # 生成配置
bash scripts/start.sh                         # 启动
source scripts/set-proxy-env.sh               # 设置环境变量
bash scripts/verify.sh                        # 验证
bash scripts/select-node.sh list              # 查看节点
bash scripts/select-node.sh select "节点名"   # 选节点
bash scripts/switch-mode.sh global            # 切全局模式
bash scripts/watchdog.sh start               # 启动守护进程（自动监控+切换节点）
bash scripts/watchdog.sh status              # 查看代理状态
source scripts/fallback.sh                   # 紧急恢复直连（防失联）
bash scripts/watchdog.sh recover             # 从直连恢复代理
```

## 用户声明与免责

使用本项目前，请务必阅读完整的 **[用户声明](DISCLAIMER.md)**。

核心条款摘要：

- 本项目 **仅用于学术研究和技术学习**，旨在帮助研究人员检索 Google Scholar、GitHub、arXiv 等学术信息
- **严禁** 将本项目用于任何违反法律法规的行为
- 使用者必须遵守所在国家和地区的法律法规
- 本项目不提供任何代理服务器、节点或订阅服务，仅是一个配置工具
- 您使用本服务仅用于一般的信息检索，我们不为您通过代理后的任何行为负责

## 许可证

MIT
