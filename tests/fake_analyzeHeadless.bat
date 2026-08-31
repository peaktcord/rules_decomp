@echo off
setlocal
for %%I in ("%~1") do set "_project_dir_name=%%~nxI"
if "%_project_dir_name:~0,1%"=="." exit /b 42
:next
if "%~1"=="" exit /b 0
if "%~1"=="--emit" (
  >"%~2" echo complete=true
  shift
)
shift
goto next
