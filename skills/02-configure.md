# 第 2 步：获取用户信息并配置

## 目标

向用户收集代理配置信息，生成 mihomo 配置文件。

## 操作

### 2.1 向用户询问订阅链接

**你必须主动向用户发送如下消息（可根据语境调整措辞）：**

> 要配置代理，我需要你提供一个 **Clash 格式的代理订阅链接**（通常是 https:// 开头的一个 URL，从你的代理服务商那里获取）。
>
> 请把链接发给我。

等待用户回复后，将链接写入 `.env` 文件：

```bash
echo 'SUBSCRIBE_URL=用户提供的链接' > .env
```

**注意**：URL 中可能含特殊字符，用单引号包裹整行。不要在对话中回显完整链接。

### 2.2 询问连接模式

**向用户询问偏好的连接模式：**

> 你希望用哪种连接模式？
>
> 1. **全局代理（推荐）** - 所有流量都走代理，避免 IP 切换导致服务不稳定
> 2. **智能分流** - 国内网站直连，海外网站走代理
> 3. **不确定** - 我帮你选全局代理

根据用户回答：
- 全局代理 / 不确定 → 使用默认配置（mode: global），无需额外操作
- 智能分流 → 在第 3 步启动后执行 `bash scripts/switch-mode.sh rule`

记住用户的选择，在第 3 步执行。

### 2.3 生成配置

```bash
bash scripts/configure.sh
```

### 预期输出

```
[INFO] Subscription URL loaded
[OK] Configuration generated at config/config.yaml
```

## 完成标志

```bash
ls -la config/config.yaml
```

文件存在且大小不为 0。进入下一步：`skills/03-start.md`。
