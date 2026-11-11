@echo off
set FLAG=%TEMP%\pecofence_res_mode.flag
if exist "%FLAG%" (
    del "%FLAG%" >nul 2>&1
) else (
    echo 1 > "%FLAG%"
)
