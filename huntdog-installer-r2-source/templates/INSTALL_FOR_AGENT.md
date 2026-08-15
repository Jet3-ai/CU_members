# HuntDog r2 Agent 安装与验收协议

你正在安装一个本机微信数据连接器。只处理当前用户明确授权的本机微信数据；不要上传原始聊天、密钥、配置或私有诊断文件。

## 1. 安装

在解压后的包根目录运行：

```bash
HUNTDOG_AGENT_INSTALL=1 ./install.command
```

安装器会自动完成：

1. 校验 macOS 与 arm64 架构。
2. 校验 HuntDog 核心文件 SHA256。
3. 清除本安装包的下载隔离属性。
4. 先在临时位置运行 `huntdog --version`，通过后才替换旧版本。
5. 备份旧核心与旧 Codex Skill，再安装新版本。
6. 运行只读验收并生成：
   - 桌面：`HuntDog安装验收.txt`
   - 私有原始诊断：`~/.huntdog/reports/private/`

## 2. 读取状态

安装后必须读取 `~/Desktop/HuntDog安装验收.txt`，并向用户分别报告：

- `INSTALL_OK`
- `DATABASE_DISCOVERY`
- `KEYS`
- `DECRYPTION_CONTEXT`
- `QUERY`
- `DATA_STATE`

`DATA_STATE` 含义：

- `FULL_READY`：聊天数据库可查询，且当前发现的普通消息库全覆盖。
- `PARTIAL_READY`：可以查询，但至少有一个普通消息库缺密钥或不可解密。只能做覆盖范围内的分析，不得声称全量、精确总数或“没有某类反馈”。
- `NEEDS_INITIALIZATION`：核心已安装，但尚未完成数据库发现或密钥准备。
- `DATA_UNAVAILABLE`：已有配置但查询不可用，需要支持排查。

## 3. 初始化安全门

如果状态是 `NEEDS_INITIALIZATION`：

1. 先向用户说明：初始化会发现微信数据库并扫描本机微信进程内存；macOS 拒绝进程访问时，当前实现可能对 WeChat.app 重新签名，影响自动更新或要求重启微信。
2. 等用户明确同意后，才能运行 `~/.huntdog/bin/huntdog init`。
3. 不得自动运行 `init --force`。
4. 初始化后重新运行 `~/.huntdog/support/verify.sh`，再读取验收报告。

如果状态是 `PARTIAL_READY`，保留现状即可使用覆盖范围内的数据。只有用户明确要求修复覆盖，并理解重新扫描/签名影响后，才讨论 `init --force`。

## 4. 查询边界

正式分析群反馈前：

1. 先确认用户对目标群数据有合法访问与分析授权。
2. 先运行 `doctor` 和 `capabilities`，记录覆盖状态。
3. 解析到准确群名/群 ID，并核对成员与时间范围。
4. 原始消息只留在本机；对外只输出必要的聚合结论与脱敏证据。
