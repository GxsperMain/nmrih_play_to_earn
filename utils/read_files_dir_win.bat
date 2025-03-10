@echo off
setlocal enabledelayedexpansion

del INFO.txt 2>nul

set "BASE_DIR=%CD%"

for /r %%F in (*) do (
    set "REL_PATH=%%F"
    set "REL_PATH=!REL_PATH:%BASE_DIR%=!"
    set "REL_PATH=!REL_PATH:\=/!"

    if "!REL_PATH:~0,1!"=="/" set "REL_PATH=!REL_PATH:~1!"

    echo !REL_PATH! >> INFO.txt
)

echo Success