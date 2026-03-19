# 第 3 步：启动代理并设置环境变量

## 目标

启动 mihomo 并配置系统代理环境变量，同时启动守护进程保障连接稳定。

## 操作

### 3.1 启动代理

```bash
bash scripts/start.sh
```

预期输出：`[OK] mihomo started (PID: xxxxx)`

### 3.2 设置环境变量

**重要：必须用 `source`，不能用 `bash`。**

```bash
source scripts/set-proxy-env.sh
```

### 3.3 如果用户选了智能分流模式

在第 2 步中如果用户选择了智能分流，现在执行：

```bash
bash scripts/switch-mode.sh rule
```

默认已是全局代理模式（global），无需额外操作。

### 3.4 启动守护进程

启动后台守护进程，每 60 秒通过代理访问 baidu.com 检测连通性。如果连 baidu 都不通，说明代理彻底不可用，守护进程会自动切换节点；如果所有节点都失效，立即回退到直连模式，确保你不会与用户失联。

```bash
bash scripts/watchdog.sh start
```

预期输出：`[OK] Watchdog started (PID: xxxxx)`

### 3.5 配置 git 代理

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

这会停止代理、清除所有代理环境变量、恢复直连，确保你能继续与用户对话。
