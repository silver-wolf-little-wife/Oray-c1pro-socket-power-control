# 贝锐向日葵 C1Pro 智能插座控制脚本

通过局域网 HTTP API 控制贝锐向日葵 C1Pro 智能插座（型号 plug-b2）的 Windows 批处理脚本。

## 功能特性

- ✅ 开关控制（远程打开/关闭插座）
- ✅ 状态查询（获取当前开关状态）
- ✅ 倒计时功能（定时开关）
- ✅ 用电信息（获取能耗数据）
- ✅ 固件版本查询
- ✅ 设备信息获取
- ✅ 完整的日志记录
- ✅ 友好的错误提示

## 系统要求

- Windows 10 1803+ 或更高版本（自带 curl）
- 与插座处于同一局域网
- PowerShell（用于时间戳生成和 JSON 解析）

## 快速开始

### 1. 配置脚本

编辑 `c1pro_control.bat` 文件顶部的配置区：

```batch
:: 插座局域网 IP (路由器管理页面查看)
set "PLUG_IP=192.168.1.100"

:: 插座 SN 码, 去掉前导0
set "SN_RAW=37007965269"
```

### 2. 获取设备 SN 码

首次使用前，运行以下命令获取插座 SN：

```cmd
c1pro_control.bat info
```

响应示例：
```json
{"sn":"037007965269","model":"plug-b2"}
```

将返回的 SN 码去掉前导零后填入配置区（如 `037007965269` → `37007965269`）。

### 3. 开始使用

```cmd
c1pro_control.bat status    # 查看状态
c1pro_control.bat on        # 打开插座
c1pro_control.bat off       # 关闭插座
```

## 命令列表

| 命令 | 说明 | 示例 |
|------|------|------|
| `info` | 获取插座 SN 和型号 | `c1pro_control.bat info` |
| `status` | 获取当前开关状态 | `c1pro_control.bat status` |
| `on` | 打开插座 | `c1pro_control.bat on` |
| `off` | 关闭插座 | `c1pro_control.bat off` |
| `countdown` | 设置倒计时任务 | `c1pro_control.bat countdown 3600 0` |
| `delcount` | 删除倒计时任务 | `c1pro_control.bat delcount` |
| `getcount` | 查看倒计时状态 | `c1pro_control.bat getcount` |
| `energy` | 获取用电信息 | `c1pro_control.bat energy` |
| `version` | 获取固件版本 | `c1pro_control.bat version` |

### 倒计时命令详解

```cmd
c1pro_control.bat countdown [秒数] [动作]
```

- **秒数**：倒计时时长（正整数）
- **动作**：`0` = 关闭，`1` = 打开

**示例：**
```cmd
c1pro_control.bat countdown 3600 0   # 1小时后关闭
c1pro_control.bat countdown 1800 1   # 30分钟后打开
```

## 鉴权机制

脚本使用 MD5 哈希生成动态鉴权密钥：

```
key = MD5(SN_RAW + "==smart-plug==" + TIMESTAMP)
```

其中 `TIMESTAMP` 格式为 `MMddHHmm`（如 `05311430` 表示 5月31日14:30）。

⚠️ **注意**：如果鉴权失败（错误码 3），请检查：
- SN 码是否正确（已去掉前导零）
- 系统时间是否准确
- 时区设置是否正确

## 错误码说明

| 错误码 | 说明 | 解决方案 |
|--------|------|----------|
| 1 | 参数错误 | 检查命令格式 |
| 2 | 设备不在线 | 确认插座通电并连接 WiFi |
| 3 | 鉴权失败 | 检查 SN 码和时间同步 |
| 11 | 无倒计时任务 | 先设置倒计时再查询 |

## 日志文件

所有操作记录保存在脚本同目录下的 `c1pro_control.log` 文件中：

```
[2025-05-31 14:30:15] ===== 命令: on =====
[2025-05-31 14:30:15] 请求: http://192.168.1.100:6767/plug?_api=set_plug_status&...
[2025-05-31 14:30:16] 成功: set_plug_status (result=0)
[2025-05-31 14:30:16] ===== 完成 =====
```

## 常见问题

### Q: 无法连接到插座？

检查以下几点：
1. 插座是否已通电并连接 WiFi
2. IP 地址是否正确（在路由器管理页面查看）
3. 电脑与插座是否在同一局域网

### Q: 鉴权失败怎么办？

1. 确认 SN 码已去掉前导零
2. 检查系统时间是否准确
3. 确保时区设置正确

### Q: 如何查看插座 IP 地址？

- 登录路由器管理页面，查看已连接设备列表
- 使用向日葵官方 App 查看设备信息

## 技术细节

- **通信协议**：HTTP
- **端口**：6767
- **数据格式**：JSON
- **依赖工具**：curl（网络请求）、PowerShell（时间戳/JSON处理）

## 许可证

本项目仅供学习和个人使用。

## 相关链接

- [贝锐向日葵官网](https://sunlogin.oray.com/)
- [C1Pro 产品页面](https://sunlogin.oray.com/device/c1pro)