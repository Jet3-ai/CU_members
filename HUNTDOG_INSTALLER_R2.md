# HuntDog macOS arm64 安装包 r2

发布文件：

- `HuntDog-CyberUnion-macos-arm64-0.4.0-r2.zip`
- `HuntDog-CyberUnion-macos-arm64-0.4.0-r2.sha256`

推荐把 ZIP 上传给本机 Agent，并要求它先阅读包内 `INSTALL_FOR_AGENT.md`。用户无需手动输入终端命令。

## 这版修复了什么

旧加密安装包能够解密并复制文件，但其中的 PyInstaller 可执行文件漏打 `zstandard` 运行依赖，首次执行会报 `ModuleNotFoundError: zstandard`。r2 把核心启动测试放在替换旧版本之前，损坏或缺依赖的核心无法再被标记成安装成功。

r2 还把两件事分开验收：

- 软件是否正确安装并能启动：`INSTALL_OK`
- 微信数据是否已发现、具备密钥、可解密、可查询，以及是否全覆盖：`DATA_STATE`

安装器不会自动执行 `huntdog init` 或 `huntdog init --force`。初始化可能扫描微信进程内存；macOS 拒绝访问时，当前实现还可能重新签名 WeChat.app，因此必须由用户明确确认。

## 已完成的发布检查

- Bash 语法与 Python 构建脚本检查
- 临时 HOME 首次安装与重复安装
- 核心 `--version` / `--help` 启动检查
- ZIP 完整性与 `ditto -x -k` 解压
- `.command`、安装脚本和核心可执行权限
- SHA256 校验
- 本机授权微信环境的只读链路：数据库发现、已有密钥读取、解密上下文、消息查询、覆盖度判断
- 个人路径与本机账号痕迹扫描

注意：发布者当前没有 Apple Developer ID 公证签名。浏览器下载后直接双击可能被 Gatekeeper 拦截；Agent 安装为首选，Control 点击后选择“打开”为备用方式。
