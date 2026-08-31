@echo off
setlocal
:next
if "%~1"=="" exit /b 0
if "%~1"=="--emit" (
  >"%~2" echo complete=true
  shift
)
shift
goto next
