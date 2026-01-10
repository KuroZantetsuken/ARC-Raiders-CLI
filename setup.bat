@echo off
setlocal

echo ARC Raiders CLI - Setup
echo -----------------------

REM Check for uninstall flag
if /i "%1"=="-Uninstall" (
    goto :uninstall
)

REM Get the script's directory
set "ScriptPath=%~dp0"
set "ScriptPath=%ScriptPath:~0,-1%"

echo [*] Adding '%ScriptPath%' to User PATH...

REM PowerShell command to safely add the directory to the user's PATH
powershell -Command "$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User'); if (-not ($UserPath -like '*%ScriptPath%*')) { $NewPath = $UserPath + ';%ScriptPath%'; [Environment]::SetEnvironmentVariable('Path', $NewPath, 'User'); echo '[+] PATH updated successfully.'; echo '[!] NOTE: You must restart your terminal for this to take effect.'; } else { echo '[+] Current directory is already in PATH.'; }"

echo.
echo Setup Complete!
echo You can now type 'arc ^<query^>' from any new terminal window.
echo To uninstall: setup.bat -Uninstall
pause
goto :eof

:uninstall
echo [*] Uninstalling...

REM Get the script's directory for removal
set "ScriptPath=%~dp0"
set "ScriptPath=%ScriptPath:~0,-1%"

echo [*] Removing '%ScriptPath%' from User PATH...

REM PowerShell command to safely remove the directory from the user's PATH
powershell -Command "$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User'); $PathParts = $UserPath -split ';'; $NewParts = $PathParts | Where-Object { $_ -ne '%ScriptPath%' -and $_ -ne '' }; $CleanPath = $NewParts -join ';'; [Environment]::SetEnvironmentVariable('Path', $CleanPath, 'User'); echo '[-] Removed from PATH.'"

echo.
echo Uninstallation Complete.
echo You may delete this folder now.
pause
goto :eof
