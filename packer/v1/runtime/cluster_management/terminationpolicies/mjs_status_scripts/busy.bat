REM Copyright 2024 The MathWorks, Inc.

@echo off
setlocal EnableDelayedExpansion

REM Set the log file path
set "LOG_FILE=C:\ProgramData\MathWorks\mjs_status_transitions.log"

REM Get the current date and time
set CURRENT_DATETIME=%DATE% %TIME%

REM Check if the log file exists
if not exist "%LOG_FILE%" (
    REM Log file does not exist, create it and write the initial busy message
    echo MJS busy since: %CURRENT_DATETIME% > "%LOG_FILE%"
) else (
    REM Log file exists, check the last non-empty line for "busy" keyword
    set "LAST_LINE="
    for /F "tokens=* delims=" %%i in ('type "%LOG_FILE%"') do (
        if not "%%i"=="" set "LAST_LINE=%%i"
    )
    
    REM Check if the last line contains the word "busy"
    set BUSY_FOUND=false
    for %%a in (!LAST_LINE!) do (
        if /i "%%a"=="busy" set BUSY_FOUND=true
    )
    
    if not !BUSY_FOUND! == true (
        REM "busy" keyword not found, log the busy message
        echo MJS busy since: %CURRENT_DATETIME% >> "%LOG_FILE%"
    )
    REM If "busy" is found, do nothing
)

endlocal