@echo off

cd /d "%~dp0"

set "target=%UserProfile%\Documents\WindowsPowerShell\Modules\philh_myftp_biz"

rmdir /s /q "%target%"
mkdir "%target%"

xcopy /s /e /y /q * "%target%\"
