# 第 5 步：验证代理连接

## 目标

确认代理已正常工作。

## 操作

```bash
bash scripts/verify.sh
```

## 预期输出（成功）

```
[TEST] Testing proxy connection...
[OK] Google connectivity: OK
[OK] Current IP: xx.xx.xx.xx
[OK] Proxy is working correctly!
```

## 如果成功

**向用户报告：**

> 代理配置完成！当前出口 IP 为 xx.xx.xx.xx，可以正常访问 Google 和 GitHub 了。
> 我已启动了后台守护进程，会自动监控代理状态。如果节点出现问题会自动切换，确保不会中断。

后续你的所有网络请求（curl、wget、git 等）都会自动走代理。

## 如果失败

阅读 `skills/06-troubleshoot.md` 排查问题。

## 后续管理

告知用户以下常用操作（在需要时使用）：

- 停止代理：`bash scripts/stop.sh && source scripts/unset-proxy-env.sh`
- 切换模式：`bash scripts/switch-mode.sh <rule|global|direct>`
- 切换节点：`bash scripts/select-node.sh select "节点名称"`
- 查看代理状态：`bash scripts/watchdog.sh status`
- 紧急恢复直连：`source scripts/fallback.sh`
- 从直连恢复代理：`bash scripts/watchdog.sh recover && source scripts/set-proxy-env.sh`
- 重启终端后需重新执行第 3 步
