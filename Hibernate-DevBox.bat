@echo off
REM Hibernate-DevBox.bat
REM Wrapper script to hibernate DevBox from toast notification

powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Hibernate-DevBox.ps1"
