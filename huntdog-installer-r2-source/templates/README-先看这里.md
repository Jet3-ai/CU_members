# HuntDog 安装包（macOS Apple 芯片版）

推荐方式：把整个 ZIP 上传给你的 Codex 或其他本机 Agent，并告诉它：

> 请先阅读 `INSTALL_FOR_AGENT.md`，按文件里的步骤安装并验收 HuntDog。未经我确认，不要运行 `huntdog init` 或 `huntdog init --force`。

Agent 会完成安装、校验并生成一份 `HuntDog安装验收.txt`。

安装验收分成两个结果：

- `INSTALL_OK=YES`：HuntDog 已正确安装并能启动。
- `DATA_STATE=...`：微信数据是否已经能被发现、解密和查询。

如果 `INSTALL_OK=YES`，但 `DATA_STATE=NEEDS_INITIALIZATION`，不是“没装上”，而是还没有获得微信数据库密钥。初始化涉及读取本机微信进程，macOS 拒绝时还可能触发微信重新签名，所以必须由你确认后再做。

## 双击备用安装

如果暂时没有 Agent，也可以：

1. 解压 ZIP。
2. 按住 Control 点击 `install.command`，选择“打开”。
3. 等待安装结束，查看桌面上的 `HuntDog安装验收.txt`。

因为当前发布者没有 Apple Developer ID 公证签名，浏览器下载后直接双击可能被 macOS 拦截；Control 点击后选择“打开”是备用入口。安装过程不要求你输入任何命令。

本包只支持 Apple 芯片 Mac（arm64），不支持 Intel Mac 或 Windows。
