@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_bin.ps1" %*
exit /b %ERRORLEVEL%
