# 第 3 步：启动代理并设置环境变量

## 目标

启动 mihomo 并配置系统代理环境变量，同时确保服务崩溃/重启后能自动恢复。

## 操作

### 3.1 启动代理（优先 systemd）

先尝试用 systemd 托管（崩溃自动重启 + 开机自启）：

```bash
bash scripts/setup-service.sh
```

如果输出 `[OK] mihomo running via systemd`，跳到 3.2。

如果 systemd 不可用（会提示 fallback），改用传统方式：

```bash
bash scripts/start.sh
bash scripts/watchdog.sh start
```

### 3.2 设置环境变量

**重要：必须用 `source`，不能用 `bash`。**

```bash
source scripts/set-proxy-env.sh
```

这会在多个层级注入代理配置：当前 shell、`~/.bashrc`（带端口存活检查）、systemd 环境。

### 3.3 如果用户选了智能分流模式

在第 2 步中如果用户选择了智能分流，现在执行：

```bash
bash scripts/switch-mode.sh rule
```

默认已是全局代理模式（global），无需额外操作。

### 3.4 配置 git 代理

让 git 也走代理：

```bash
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890
```

## 完成标志

```bash
echo $HTTP_PROXY
```

输出 `http://127.0.0.1:7890`。进入下一步：`skills/04-select-node.md`。

## 紧急情况

如果代理导致你无法与用户通信，立即执行紧急回退：

```bash
source scripts/fallback.sh
```

这会停止代理、清除所有层级的代理环境变量、恢复直连，确保你能继续与用户对话。
