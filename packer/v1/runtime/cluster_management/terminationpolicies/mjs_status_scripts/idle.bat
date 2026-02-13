REM Copyright 2024 The MathWorks, Inc.

@echo off
setlocal EnableDelayedExpansion

REM Set the log file path
set "LOG_FILE=C:\ProgramData\MathWorks\mjs_status_transitions.log"

REM Get the current date and time
set CURRENT_DATETIME=%DATE% %TIME%

REM Check if the log file exists
if not exist "%LOG_FILE%" (
    REM Log file does not exist, create it and write the initial idle message
    echo MJS idle since: %CURRENT_DATETIME% > "%LOG_FILE%"
) else (
    REM Log file exists, check the last non-empty line for "idle" keyword
    set "LAST_LINE="
    for /F "tokens=* delims=" %%i in ('type "%LOG_FILE%"') do (
        if not "%%i"=="" set "LAST_LINE=%%i"
    )
    
    REM Check if the last line contains the word "idle"
    set IDLE_FOUND=false
    for %%a in (!LAST_LINE!) do (
        if /i "%%a"=="idle" set IDLE_FOUND=true
    )
    
    if not !IDLE_FOUND! == true (
        REM "idle" keyword not found, log the idle message
        echo MJS idle since: %CURRENT_DATETIME% >> "%LOG_FILE%"
    )
    REM If "idle" is found, do nothing
)

REM End of the script
endlocal