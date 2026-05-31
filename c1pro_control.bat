@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
 
:: ============================================================
::  贝锐向日葵 C1Pro 智能插座控制脚本 (最终完整版)
::  型号: plug-b2 (单孔位)
::  接口: 局域网 HTTP, 端口 6767
::  依赖: curl (Win10 1803+ 自带)
:: ============================================================
 
:: ---------- 配置加载 ----------

:: 默认配置
set "PLUG_IP=192.168.1.100"
set "SN_RAW=37007965269"
set "LOGFILE=%~dp0c1pro_control.log"

:: 尝试加载外部配置文件
if exist "%~dp0config.bat" (
    call "%~dp0config.bat"
)

:: ---------- 配置加载结束 ----------
 
:: 初始化临时文件列表，用于清理 (使用引号保护路径)
set "TMP_FILES="
 
:: 用 PowerShell 生成固定格式时间戳 MMDDHHmm (不受系统区域影响)
for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format 'MMddHHmm'"') do set "TIMESTAMP=%%t"
 
:: 生成鉴权 key = MD5(SN_RAW + "==smart-plug==" + TIMESTAMP)
:: 使用环境变量传递参数，避免转义问题
for /f "delims=" %%h in ('powershell -NoProfile -Command "$s=[System.Text.Encoding]::UTF8.GetBytes($env:SN_RAW + '==smart-plug==' + $env:TIMESTAMP); $m=[System.Security.Cryptography.MD5]::Create().ComputeHash($s); -join ($m | ForEach-Object { $_.ToString('x2') })"') do set "AUTH_KEY=%%h"
 
:: ---------- 函数 ----------
 
:LOG
echo [%date% %time%] %* >> "%LOGFILE%"
goto :eof
 
:CLEANUP
:: 清理所有临时文件 (支持带空格的路径)
if defined TMP_FILES (
    for %%f in ("%TMP_FILES:;=" "%") do (
        if exist "%%~f" del "%%~f" >nul 2>&1
    )
)
goto :eof
 
:ADD_TMP_FILE
:: 注册临时文件以便清理 (使用分号分隔，避免空格问题)
if defined TMP_FILES (
    set "TMP_FILES=%TMP_FILES%;%~1"
) else (
    set "TMP_FILES=%~1"
)
goto :eof
 
:CHECK
curl -s --connect-timeout 3 "http://%PLUG_IP%:6767/plug?_api=get_plug_sn" >nul 2>&1
if errorlevel 1 (
    call :LOG "错误: 无法连接 %PLUG_IP%:6767"
    echo [错误] 无法连接到插座 %PLUG_IP%:6767
    echo         请确认: 1.插座已通电连WiFi  2.IP正确  3.同一局域网
    call :CLEANUP
    exit /b 1
)
exit /b 0
 
:API
:: call :API [接口名] [额外参数]
:: 返回: API_RESULT 变量 (0=成功, 其他=失败)，exit code 与 API_RESULT 一致
set "FULL_URL=http://%PLUG_IP%:6767/plug?_api=%~1&time=%TIMESTAMP%&key=%AUTH_KEY%"
if not "%~2"=="" set "FULL_URL=%FULL_URL%&%~2"
call :LOG "请求: %FULL_URL%"
echo.
 
:: 创建临时文件并注册
set "TMP_FILE=%TEMP%\plug_api_%RANDOM%.txt"
call :ADD_TMP_FILE "%TMP_FILE%"
 
curl -s --connect-timeout 5 -o "%TMP_FILE%" -w "" "%FULL_URL%" 2>nul
 
:: 检查 curl 执行状态
if errorlevel 1 (
    call :LOG "错误: curl 执行失败 (errorlevel=%errorlevel%)"
    echo [错误] 网络请求失败, curl 返回错误
    set "API_RESULT=1"
    call :CLEANUP
    exit /b 1
)
 
:: 检查响应文件是否存在且不为空
if not exist "%TMP_FILE%" (
    call :LOG "错误: 响应文件不存在"
    echo [错误] 插座无响应
    set "API_RESULT=1"
    call :CLEANUP
    exit /b 1
)
 
:: 读取响应内容
set "API_RESPONSE="
for /f "usebackq delims=" %%r in ("%TMP_FILE%") do set "API_RESPONSE=%%r"
 
:: 检查响应是否为空
if "%API_RESPONSE%"=="" (
    call :LOG "错误: 响应内容为空"
    echo [错误] 插座返回空数据
    set "API_RESULT=1"
    call :CLEANUP
    exit /b 1
)
 
:: 输出响应 (使用 type 命令直接输出临时文件，避免特殊字符被 shell 解释)
echo [响应内容]
type "%TMP_FILE%"
echo.
 
:: 使用 PowerShell 带错误处理解析 JSON
set "API_RESULT="
for /f "delims=" %%v in ('powershell -NoProfile -Command "$errorActionPreference='Stop'; try { $json = Get-Content '%TMP_FILE%' -Raw | ConvertFrom-Json; if ($json.PSObject.Properties['result']) { $json.result } else { -1 } } catch { -2 }"') do set "API_RESULT=%%v"
 
:: 处理解析结果并设置正确的 exit code
if "%API_RESULT%"=="" (
    call :LOG "错误: 无法解析响应 JSON"
    echo [错误] 无法解析服务器响应
    set "API_RESULT=-1"
    exit /b 255
) else if "%API_RESULT%"=="-1" (
    call :LOG "错误: JSON 缺少 result 字段"
    echo [错误] 响应格式错误: 缺少 result 字段
    exit /b 254
) else if "%API_RESULT%"=="-2" (
    call :LOG "错误: JSON 解析异常"
    echo [错误] 响应不是有效的 JSON 格式
    exit /b 253
) else if "%API_RESULT%"=="0" (
    call :LOG "成功: %~1 (result=0)"
    echo [成功] 操作完成
    exit /b 0
) else (
    call :LOG "失败: %~1 (result=%API_RESULT%)"
    echo [失败] 错误码: %API_RESULT%
    :: 错误码说明
    if "%API_RESULT%"=="1" echo        参数错误
    if "%API_RESULT%"=="2" echo        设备不在线
    if "%API_RESULT%"=="3" echo        鉴权失败(检查SN或时间)
    if "%API_RESULT%"=="11" echo       无倒计时任务
    exit /b %API_RESULT%
)
 
:USAGE
echo.
echo  贝锐向日葵 C1Pro 智能插座控制
echo  ================================================
echo.
echo  用法: %~nx0 [命令]
echo.
echo  命令:
echo    info       获取插座SN和型号
echo    status     获取当前状态
echo    on         打开插座
echo    off        关闭插座
echo  countdown [秒数] [0关/1开]  设置倒计时
echo    delcount   删除倒计时
echo    getcount   查看倒计时
echo    energy     获取用电信息
echo    version    获取固件版本
echo.
echo  示例:
echo    %~nx0 on
echo  %~nx0 countdown 3600 0    (1小时后关闭)
echo  %~nx0 countdown 1800 1    (30分钟后打开)
echo.
echo  日志: %LOGFILE%
echo  ================================================
goto :eof
 
:IS_NUMBER
:: 检查参数是否为正整数
:: %1 - 要检查的字符串
set "str=%~1"
if not defined str exit /b 1
for /f "delims=0123456789" %%a in ("%str%") do exit /b 1
if "%str%"=="0" exit /b 1
exit /b 0
 
:: ---------- 主入口 ----------
 
if "%~1"=="" goto :USAGE
 
set "CMD=%~1"
 
:: info 不需要预检
if /i "%CMD%"=="info" goto :CMD_INFO
 
call :CHECK
if errorlevel 1 exit /b 1
 
call :LOG "===== 命令: %* ====="
 
if /i "%CMD%"=="status" goto :CMD_STATUS
if /i "%CMD%"=="on" goto :CMD_ON
if /i "%CMD%"=="off" goto :CMD_OFF
if /i "%CMD%"=="countdown" goto :CMD_COUNTDOWN
if /i "%CMD%"=="delcount" goto :CMD_DELCOUNT
if /i "%CMD%"=="getcount" goto :CMD_GETCOUNT
if /i "%CMD%"=="energy" goto :CMD_ENERGY
if /i "%CMD%"=="version" goto :CMD_VERSION
 
echo [错误] 未知命令: %CMD%
goto :USAGE
 
:: ---------- 命令实现 ----------
 
:CMD_INFO
echo [获取插座信息]
 
set "TMP_INFO=%TEMP%\plug_info_%RANDOM%.txt"
call :ADD_TMP_FILE "%TMP_INFO%"
 
curl -s --connect-timeout 5 -o "%TMP_INFO%" -w "" "http://%PLUG_IP%:6767/plug?_api=get_plug_sn" 2>nul
 
:: 检查 curl 执行状态
if errorlevel 1 (
    call :LOG "错误: info curl失败 (errorlevel=%errorlevel%)"
    echo [错误] 网络请求失败
    call :CLEANUP
    exit /b 1
)
 
:: 检查响应是否为空
if not exist "%TMP_INFO%" (
    call :LOG "错误: info 无响应文件"
    echo [错误] 插座无响应, 请检查 IP 地址
    echo        当前配置: %PLUG_IP%
    call :CLEANUP
    exit /b 1
)
 
:: 直接输出临时文件内容，避免特殊字符问题
echo [响应内容]
type "%TMP_INFO%"
echo.
 
:: 读取响应到变量用于日志
set "INFO_RESPONSE="
for /f "usebackq delims=" %%r in ("%TMP_INFO%") do set "INFO_RESPONSE=%%r"
call :LOG "info: %INFO_RESPONSE%"
goto :END
 
:CMD_STATUS
echo [获取插座状态]
call :API get_plug_status
if errorlevel 1 (
    call :LOG "命令失败: status, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:CMD_ON
echo [打开插座]
call :API set_plug_status "index=0&status=1"
if errorlevel 1 (
    call :LOG "命令失败: on, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:CMD_OFF
echo [关闭插座]
call :API set_plug_status "index=0&status=0"
if errorlevel 1 (
    call :LOG "命令失败: off, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:CMD_COUNTDOWN
if "%~2"=="" (
    echo [错误] 用法: %~nx0 countdown [秒数] [0关/1开]
    echo 示例: %~nx0 countdown 3600 0
    call :CLEANUP
    exit /b 1
)
 
:: 验证秒数是否为正整数
call :IS_NUMBER "%~2"
if errorlevel 1 (
    echo [错误] 秒数必须为正整数
    call :CLEANUP
    exit /b 1
)
 
set "CD_SEC=%~2"
set "CD_ACT=%~3"
if "%CD_ACT%"=="" set "CD_ACT=0"
 
:: 验证动作是否为0或1
if not "%CD_ACT%"=="0" if not "%CD_ACT%"=="1" (
    echo [错误] 动作必须为 0 (关) 或 1 (开)
    call :CLEANUP
    exit /b 1
)
 
echo [倒计时: %CD_SEC%秒后 %CD_ACT%(0关/1开)]
call :API plug_cntdown_add "index=0&count=%CD_SEC%&action=%CD_ACT%"
if errorlevel 1 (
    call :LOG "命令失败: countdown, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:CMD_DELCOUNT
echo [删除倒计时]
call :API plug_cntdown_del "index=0"
if errorlevel 1 (
    call :LOG "命令失败: delcount, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:CMD_GETCOUNT
echo [查看倒计时]
call :API plug_cntdown_get "index=0"
if errorlevel 1 (
    call :LOG "命令失败: getcount, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:CMD_ENERGY
echo [获取用电信息]
call :API get_plug_energy
if errorlevel 1 (
    call :LOG "命令失败: energy, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:CMD_VERSION
echo [获取固件版本]
call :API get_plug_version
if errorlevel 1 (
    call :LOG "命令失败: version, exit code=%errorlevel%"
    goto :END_WITH_ERROR
)
goto :END
 
:END_WITH_ERROR
:: 保存当前 errorlevel
set "EXIT_CODE=%errorlevel%"
call :LOG "===== 命令执行失败 ====="
echo.
echo 日志: %LOGFILE%
call :CLEANUP
endlocal
exit /b %EXIT_CODE%
 
:END
call :LOG "===== 完成 ====="
echo.
echo 日志: %LOGFILE%
call :CLEANUP
endlocal
exit /b 0
