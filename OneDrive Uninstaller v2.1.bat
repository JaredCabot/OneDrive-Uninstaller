@rem ============================================================================
@rem  OneDrive TOTAL Uninstaller for Windows 10 & 11
@rem  V2.1 by TERRA Operative - 2026/09/30.
@rem
@rem  Feel free to distribute freely as long as you leave the attribution intact,
@rem  and if you make changes and adaptions, don't be a dick about not attributing
@rem  where due. And most importantly, peace out and keep it real.
@rem
@rem  Run as Administrator.   Optional:  /dryrun  = log what would happen, change nothing.
@rem
@rem  For EVERY user profile (including the Default profile new accounts copy):
@rem    1. Moves Desktop/Documents/Pictures etc. back out of OneDrive.
@rem    2. Renames each OneDrive folder to "<name> (backup)". Nothing is deleted.
@rem    3. Removes OneDrive settings, startup entries, Explorer entries and app files.
@rem  Then removes the machine-wide install, tasks and leftovers, and sets the
@rem  DisableFileSyncNGSC policy so OneDrive can't run.
@rem  Every registry key is exported to a numbered .reg file before it's changed.
@rem  Log and backups go to  %SystemDrive%\OneDrive-Uninstaller\run-N\
@rem
@rem  ponytail: paths containing ^ or %% are not supported (CALL mangles them).
@rem ============================================================================
@echo off
setlocal EnableExtensions DisableDelayedExpansion

for /f %%E in ('echo prompt $E^| cmd') do set "ESC=%%E"

@rem ---- Admin check. fltmc works even when the Server service is disabled. ----
fltmc >nul 2>&1 || (
   call :log "ERROR: Run this script as Administrator - right-click it, Run as administrator." "[91m"
   pause
   exit /b 1
)

@rem ---- Run from a copy in TEMP. cmd re-reads a .bat while it runs, so if the
@rem ---- script lives on a OneDrive Desktop, moving that folder would kill it.
if /i "%~1"=="/relaunched" goto :MAIN
copy /y "%~f0" "%TEMP%\OneDrive-Uninstaller.bat" >nul || goto :MAIN
"%TEMP%\OneDrive-Uninstaller.bat" /relaunched %*

:MAIN
set "ODCLSID={018D5C66-4533-4307-9B53-224DE2ED1FE6}"
set "EXPLORER_KEY=Software\Microsoft\Windows\CurrentVersion\Explorer"
set "ERRORS=0"
set "N=0"
set "DRYRUN="
for %%A in (%*) do if /i "%%~A"=="/dryrun" set "DRYRUN=1"

set "RUN=1"
:NEXTRUN
if exist "%SystemDrive%\OneDrive-Uninstaller\run-%RUN%\" (set /a RUN+=1 & goto :NEXTRUN)
set "OUT=%SystemDrive%\OneDrive-Uninstaller\run-%RUN%"
mkdir "%OUT%" 2>nul
set "LOG=%OUT%\log.txt"
set "STASHLIST=%OUT%\onedrive-folders.txt"
type nul >"%STASHLIST%"

call :log "------ Windows 10/11 OneDrive TOTAL Uninstaller V2.1 ------"
if defined DRYRUN call :log "DRY RUN - nothing will be changed." "[93m"
call :log "Log and registry backups: %OUT%"
call :log "To undo a registry change, double-click its numbered .reg file."
echo.
call :log "WARNING - this removes OneDrive from EVERY account on this PC." "[91m"
echo   - Desktop, Documents, Pictures etc. are moved back out of OneDrive.
echo   - Each OneDrive folder is renamed to "<name> (backup)", not deleted.
echo   - Online-only files can't be moved. First right-click your OneDrive
echo     folder and choose "Always keep on this device".
echo   - Explorer will close. Other users should sign out first.
echo   - OneDrive is blocked from running afterwards.
call :CHECKMANAGED
echo.
choice /c YN /n /m "Continue? [Y/N] "
if errorlevel 2 exit /b 1

if not defined DRYRUN call :STOPONEDRIVE
call :log "" & call :log "=== Moving redirected folders back out of OneDrive ==="
call :FORPROFILES RESCUE
if not defined DRYRUN call :UNINSTALL
call :log "" & call :log "=== Cleaning every user profile ==="
call :FORPROFILES CLEAN
call :MACHINE
call :STASHALL
call :CREDS
call :POLICY
call :FINISH
exit /b 0


@rem ===========================================================================
@rem  Steps
@rem ===========================================================================
:CHECKMANAGED
set "MANAGED="
reg query "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" >nul 2>&1 && set "MANAGED=1"
dsregcmd /status 2>nul | findstr /r /c:"AzureAdJoined *: YES" /c:"DomainJoined *: YES" >nul && set "MANAGED=1"
if not defined MANAGED goto :eof
echo.
call :log "This PC looks work/school managed (domain, Entra ID or OneDrive policy)." "[91m"
call :log "Your organisation may rely on OneDrive and may reinstall it. Check with IT first." "[91m"
goto :eof


:STOPONEDRIVE
call :log "" & call :log "=== Stopping OneDrive and Explorer ==="
@rem Explorer holds FileSyncShell64.dll open, which is what made v2.0 need two runs.
@rem First note every signed-in user whose Explorer we're about to close, as
@rem [DOMAIN\user] lines (usernames can't contain brackets, so find is exact).
@rem CSV split on quotes: field 13 is User Name, and commas inside Mem Usage can't shift it.
set "SHELLUSERS=%OUT%\shell-users.txt"
type nul >"%SHELLUSERS%"
for /f tokens^=13^ delims^=^" %%U in ('tasklist /v /fo csv /nh /fi "imagename eq explorer.exe" 2^>nul') do (
   if /i not "%%U"=="N/A" find /i "[%%U]" "%SHELLUSERS%" >nul || >>"%SHELLUSERS%" echo([%%U]
)
for %%P in (OneDrive.exe OneDriveSetup.exe OneDriveStandaloneUpdater.exe FileCoAuth.exe FileSyncHelper.exe Microsoft.SharePoint.exe explorer.exe) do taskkill /f /im %%P >nul 2>&1
goto :eof


:UNINSTALL
call :log "" & call :log "=== Running the OneDrive uninstallers ==="
for %%S in ("%SystemRoot%\System32\OneDriveSetup.exe" "%SystemRoot%\SysWOW64\OneDriveSetup.exe") do if exist %%S call :RUNSETUP %%S /uninstall
for /d %%V in ("%ProgramFiles%\Microsoft OneDrive\*") do if exist "%%~V\OneDriveSetup.exe" call :RUNSETUP "%%~V\OneDriveSetup.exe" /uninstall /allusers
if defined ProgramFiles(x86) for /d %%V in ("%ProgramFiles(x86)%\Microsoft OneDrive\*") do if exist "%%~V\OneDriveSetup.exe" call :RUNSETUP "%%~V\OneDriveSetup.exe" /uninstall /allusers
goto :eof

:RUNSETUP exe args...
call :log "  %~nx1 %~2 %~3"
"%~1" %~2 %~3
@rem The setup exe can hand off to a child and return early - wait for it.
set "W=0"
:RUNSETUP_WAIT
tasklist /fi "imagename eq OneDriveSetup.exe" 2>nul | find /i "OneDriveSetup.exe" >nul || goto :eof
set /a W+=1
if %W% geq 60 (call :FAIL "OneDriveSetup.exe still running after 60s - continuing anyway" & goto :eof)
ping -n 2 127.0.0.1 >nul
goto :RUNSETUP_WAIT


@rem ---- Per profile, pass 1 (before uninstall): undo Known Folder Move and note
@rem ---- where the OneDrive folders are, while OneDrive's settings still exist.
:RESCUE
set "USF=%R%\%EXPLORER_KEY%\User Shell Folders"
for %%E in (
   "Desktop|Desktop"         "{754AC886-DF64-4CBA-86B5-F7FBF4FBCEF5}|Desktop"
   "Personal|Documents"      "{F42EE2D3-909F-4907-8871-4C22FC0BF756}|Documents"
   "My Pictures|Pictures"    "{0DDD015D-B06C-45D5-8C4C-F59713854639}|Pictures"
   "My Music|Music"          "{A0C69A99-21C8-4671-8703-7934162FCF1D}|Music"
   "My Video|Videos"         "{35286A68-3C57-41A1-BBB1-0EAE73D76C95}|Videos"
   "Favorites|Favorites"
   "{374DE290-123F-4565-9164-39C4925E467B}|Downloads"
   "{7D83EE9B-2244-4E70-B1F5-5393042AF1E4}|Downloads"
) do for /f "tokens=1,2 delims=|" %%N in (%%E) do call :KFMRESET "%%N" "%%O"
for /f "tokens=2,*" %%A in ('reg query "%R%\Software\Microsoft\OneDrive\Accounts" /s /v UserFolder 2^>nul ^| findstr "REG_"') do >>"%STASHLIST%" echo(%%B
for /d %%X in ("%P%\OneDrive" "%P%\OneDrive - *") do >>"%STASHLIST%" echo(%%~X
goto :eof

:KFMRESET valueName localFolder
@rem Only touch values that actually point into OneDrive.
set "L="
for /f "delims=" %%L in ('reg query "%USF%" /v "%~1" 2^>nul ^| findstr /i /c:"OneDrive"') do set "L=%%L"
if not defined L goto :eof
@rem Strip "    <name>    REG_(EXPAND_)SZ    " to get the data, then expand it
@rem with USERPROFILE set to THIS profile (see :WITHPROFILE).
set "D=%L:*_SZ    =%"
call set "SRC=%D%"
call :MOVE "%SRC%" "%P%\%~2"
call :EXPORT "%USF%"
if not defined DRYRUN if not defined BK goto :eof
call :log "  Point %~1 back to %P%\%~2 %BK%"
if defined DRYRUN goto :eof
@rem Not via CALL, so the data stays the literal text %USERPROFILE%\...
reg add "%USF%" /v "%~1" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\%~2" /f >nul 2>&1 || call :FAIL "Could not reset %~1"
@rem Legacy mirror of the above; Windows rebuilds it on demand.
call :REGDEL "%R%\%EXPLORER_KEY%\Shell Folders" "%~1"
goto :eof


@rem ---- Per profile, pass 2 (after uninstall): registry and app files. ----
:CLEAN
call :REGDEL "%R%\Software\Microsoft\OneDrive"
for %%K in (Run RunOnce Explorer\StartupApproved\Run) do for %%V in (OneDrive OneDriveSetup) do call :REGDEL "%R%\Software\Microsoft\Windows\CurrentVersion\%%K" "%%V"
for %%V in (OneDrive OneDriveConsumer OneDriveCommercial) do call :REGDEL "%R%\Environment" "%%V"
call :REGDEL "%R%\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
call :NAMESPACE "%R%\%EXPLORER_KEY%\Desktop\NameSpace" "%C%"
if defined C call :REGDEL "%C%\CLSID\%ODCLSID%"
call :RMDIR "%P%\AppData\Local\Microsoft\OneDrive"
call :RMDIR "%P%\AppData\Roaming\Microsoft\OneDrive"
call :RMFILE "%P%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
call :RMFILE "%P%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*OneDrive*.lnk"
goto :eof


:MACHINE
call :log "" & call :log "=== Machine-wide cleanup ==="
for %%W in ("" "\Wow6432Node") do (
   for %%K in (Run RunOnce Explorer\StartupApproved\Run) do for %%V in (OneDrive OneDriveSetup) do call :REGDEL "HKLM\SOFTWARE%%~W\Microsoft\Windows\CurrentVersion\%%K" "%%V"
   call :NAMESPACE "HKLM\SOFTWARE%%~W\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace" "HKLM\SOFTWARE\Classes%%~W"
   call :REGDEL "HKLM\SOFTWARE\Classes%%~W\CLSID\%ODCLSID%"
   call :REGDEL "HKLM\SOFTWARE%%~W\Microsoft\OneDrive"
   call :REGDEL "HKLM\SOFTWARE%%~W\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
   call :SUBKEYS "HKLM\SOFTWARE%%~W\Microsoft\Windows\CurrentVersion\Explorer\ShellIconOverlayIdentifiers" "OneDrive"
   call :KEYSWITHDATA "HKLM\SOFTWARE%%~W\Microsoft\Active Setup\Installed Components" "OneDriveSetup"
)
call :SUBKEYS "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SyncRootManager" "OneDrive!"
call :RMDIR "%ProgramData%\Microsoft OneDrive"
call :RMDIR "%ProgramFiles%\Microsoft OneDrive"
if defined ProgramFiles(x86) call :RMDIR "%ProgramFiles(x86)%\Microsoft OneDrive"
call :RMDIR "%SystemDrive%\OneDriveTemp"
for %%F in (OneDriveSetup.exe OneDrive.ico) do (
   call :RMFILE "%SystemRoot%\System32\%%F"
   call :RMFILE "%SystemRoot%\SysWOW64\%%F"
)
call :RMFILE "%ProgramData%\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"
call :RMFILE "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup\*OneDrive*.lnk"
@rem Microsoft's tasks are all named "\OneDrive ..." - don't touch anyone else's.
for /f "tokens=1 delims=," %%T in ('schtasks /query /fo csv /nh 2^>nul ^| findstr /i "OneDrive"') do call :DELTASK "%%~T"
goto :eof


:STASHALL
call :log "" & call :log "=== Renaming OneDrive folders to (backup) ==="
for /f "usebackq delims=" %%F in ("%STASHLIST%") do call :STASH "%%F"
goto :eof


:CREDS
call :log "" & call :log "=== Cached OneDrive credentials (the account running this script only) ==="
@rem "target=" isn't localized; the "Target:" label in front of it is.
for /f "tokens=1,* delims==" %%A in ('cmdkey /list 2^>nul ^| findstr /i /c:"target=OneDrive"') do call :DELCRED "%%B"
goto :eof


:POLICY
call :log "" & call :log "=== Blocking OneDrive from running (DisableFileSyncNGSC policy) ==="
if defined DRYRUN goto :eof
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f >nul 2>&1 || call :FAIL "Could not set the policy"
goto :eof


:FINISH
echo.
if "%ERRORS%"=="0" (call :log "OneDrive removal finished with no problems." "[92m") else call :log "Finished with %ERRORS% problem(s) - see above or %LOG%" "[93m"
call :log "Anything that couldn't be moved is still in the (backup) folder(s)."
if defined DRYRUN (pause & goto :eof)
@rem Bring Explorer back BEFORE asking, so closing this window can't leave anyone without a taskbar.
call :RESTARTSHELL
echo.
@rem A reboot also applies the environment-variable and folder changes everywhere.
choice /c YN /n /m "Reboot now to finish (recommended)? [Y/N] "
if errorlevel 2 goto :eof
shutdown /r /t 5
goto :eof


:RESTARTSHELL
call :log "" & call :log "=== Restarting Explorer ==="
for /f "usebackq tokens=1 delims=[]" %%U in ("%SHELLUSERS%") do call :SHELLAS "%%U"
@rem Last resort if no shell came back at all.
ping -n 4 127.0.0.1 >nul
tasklist /fi "imagename eq explorer.exe" 2>nul | find /i "explorer.exe" >nul || start "" explorer.exe
goto :eof

:SHELLAS user
@rem Explorer won't reliably start as the desktop from an admin process, so run it
@rem as that user, un-elevated, in their own session via a one-off interactive task.
@rem <nul: if schtasks ever asks for a password it fails instead of hanging.
set "TN=OneDrive-Uninstaller restart Explorer"
call :log "  Explorer for %~1"
<nul schtasks /create /tn "%TN%" /tr explorer.exe /sc once /st 00:00 /ru "%~1" /it /f >nul 2>&1 || (call :FAIL "Could not restart Explorer for %~1 - sign out and back in" & goto :eof)
schtasks /run /tn "%TN%" >nul 2>&1 || call :FAIL "Could not restart Explorer for %~1 - sign out and back in"
@rem Give the task a moment to launch before removing it.
ping -n 3 127.0.0.1 >nul
schtasks /delete /tn "%TN%" /f >nul 2>&1
goto :eof


@rem ===========================================================================
@rem  Profile enumeration: every real account in ProfileList, plus Default.
@rem  (Local S-1-5-21 and Entra ID S-1-12-1 accounts; .bak entries skipped.)
@rem ===========================================================================
:FORPROFILES action
set "PL=HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
for /f "delims=" %%K in ('reg query "%PL%" 2^>nul ^| findstr /b "HKEY_" ^| findstr /l /i /c:"S-1-5-21-" /c:"S-1-12-1-" ^| findstr /v /l /i /c:".bak"') do (
   for /f "tokens=2,*" %%A in ('reg query "%%K" /v ProfileImagePath 2^>nul ^| findstr "REG_"') do call :WITHPROFILE %1 "%%~nxK" "%%B"
)
for /f "tokens=2,*" %%A in ('reg query "%PL%" /v Default 2^>nul ^| findstr "REG_"') do call :WITHPROFILE %1 "Default" "%%B"
goto :eof

:WITHPROFILE action sid profilePath
@rem Sets P (profile path), R (user hive root), C (user classes root, may be empty).
set "SID=%~2"
set "P=%~3"
if not exist "%P%\NTUSER.DAT" goto :eof
call :log "  Profile: %P%"
set "SAVED_UP=%USERPROFILE%"
set "USERPROFILE=%P%"
set "LOADED="
set "R=HKU\%SID%"
set "C=HKU\%SID%_Classes"
reg query "%R%" >nul 2>&1 && goto :WITHPROFILE_RUN
@rem Not signed in: mount the hive under a per-profile name, so one failed
@rem unload can't block every profile after it.
set "LOADED=1"
set "R=HKU\ODU_%SID%"
set "C=HKU\ODU_%SID%_Classes"
reg load "%R%" "%P%\NTUSER.DAT" >nul 2>&1 || (call :FAIL "Could not load the registry for %P% - skipped" & goto :WITHPROFILE_END)
reg load "%C%" "%P%\AppData\Local\Microsoft\Windows\UsrClass.dat" >nul 2>&1 || set "C="
:WITHPROFILE_RUN
call :%~1
if not defined LOADED goto :WITHPROFILE_END
if defined C call :UNLOAD "%C%"
call :UNLOAD "%R%"
:WITHPROFILE_END
set "USERPROFILE=%SAVED_UP%"
goto :eof

:UNLOAD key
reg unload "%~1" >nul 2>&1 && goto :eof
ping -n 3 127.0.0.1 >nul
reg unload "%~1" >nul 2>&1 || call :FAIL "Could not unload %~1 - a reboot will release it"
goto :eof


@rem ===========================================================================
@rem  Helpers. Every change goes through one of these, so each one logs,
@rem  honours /dryrun, backs up registry keys and reports failures.
@rem ===========================================================================
:EXPORT key
@rem Sets BK to a label for the backup, or empty if the backup failed.
set "BK="
if defined DRYRUN goto :eof
set /a N+=1
set "BK=[backup %N%.reg]"
reg export "%~1" "%OUT%\%N%.reg" /y >nul 2>&1 || (set "BK=" & call :FAIL "Could not back up %~1 - left unchanged")
goto :eof

:REGDEL key value
if "%~2"=="" (reg query "%~1" >nul 2>&1) else reg query "%~1" /v "%~2" >nul 2>&1
if errorlevel 1 goto :eof
call :EXPORT "%~1"
if not defined DRYRUN if not defined BK goto :eof
call :log "  Remove %~1 %~2 %BK%"
if defined DRYRUN goto :eof
if "%~2"=="" (reg delete "%~1" /f >nul 2>&1) else reg delete "%~1" /v "%~2" /f >nul 2>&1
if errorlevel 1 call :FAIL "Could not remove %~1 %~2"
goto :eof

:NAMESPACE nameSpaceKey classesRoot
@rem Personal AND per-tenant business entries: any namespace whose data says OneDrive.
for /f "delims=" %%K in ('reg query "%~1" /s /f OneDrive /d 2^>nul ^| findstr /b "HKEY_"') do (
   call :REGDEL "%%K"
   if not "%~2"=="" call :REGDEL "%~2\CLSID\%%~nxK"
)
goto :eof

:SUBKEYS parentKey text
@rem Delete direct subkeys whose name contains <text>.
for /f "delims=" %%K in ('reg query "%~1" 2^>nul ^| findstr /b "HKEY_" ^| findstr /l /i /c:"%~2"') do call :REGDEL "%%K"
goto :eof

:KEYSWITHDATA parentKey text
@rem Delete subkeys holding a value whose data contains <text>.
for /f "delims=" %%K in ('reg query "%~1" /s /f "%~2" /d 2^>nul ^| findstr /b "HKEY_"') do call :REGDEL "%%K"
goto :eof

:MOVE src dst
if not exist "%~1\" goto :eof
if /i "%~1"=="%~2" goto :eof
call :log "  Move %~1 -> %~2"
if defined DRYRUN goto :eof
@rem /xo: never overwrite a newer local file. Skipped files stay in the backup.
robocopy "%~1" "%~2" /move /e /xj /xo /r:0 /w:0 /np /njh /njs /nfl /ndl >nul
if errorlevel 8 call :FAIL "Some files in %~1 could not be moved (online-only or in use) - they stay in the OneDrive (backup) folder"
goto :eof

:STASH folder
if not exist "%~1\" goto :eof
set "X=%~1"
if /i "%X:~-8%"=="(backup)" goto :eof
if exist "%~1 (backup)\" (call :FAIL "%~1 (backup) already exists - %~1 left in place" & goto :eof)
call :log "  Rename %~1 -> %~nx1 (backup)"
if defined DRYRUN goto :eof
ren "%~1" "%~nx1 (backup)" >nul 2>&1 || call :FAIL "Could not rename %~1 - reboot and run again"
goto :eof

:RMDIR folder
if not exist "%~1\" goto :eof
call :log "  Remove folder %~1"
if defined DRYRUN goto :eof
rd /s /q "%~1" >nul 2>&1
if exist "%~1\" call :FAIL "Could not fully remove %~1 - reboot and run again"
goto :eof

:RMFILE file or wildcard
if not exist "%~1" goto :eof
call :log "  Remove file %~1"
if defined DRYRUN goto :eof
@rem No /r, so no localized Y/N prompt. /a = owner is Administrators, not us.
takeown /a /f "%~1" >nul 2>&1
icacls "%~1" /grant *S-1-5-32-544:F /c /q >nul 2>&1
del /f /q "%~1" >nul 2>&1
if exist "%~1" call :FAIL "Could not remove %~1 - reboot and run again"
goto :eof

:DELTASK taskName
set "T=%~1"
if /i not "%T:~0,10%"=="\OneDrive " goto :eof
schtasks /query /tn "%~1" >nul 2>&1 || goto :eof
call :log "  Remove scheduled task %~1"
if defined DRYRUN goto :eof
schtasks /delete /tn "%~1" /f >nul 2>&1 || call :FAIL "Could not remove task %~1"
goto :eof

:DELCRED target
call :log "  Remove credential %~1"
if defined DRYRUN goto :eof
cmdkey /delete:"LegacyGeneric:target=%~1" >nul 2>&1 || cmdkey /delete:"%~1" >nul 2>&1 || call :FAIL "Could not remove credential %~1"
goto :eof

:FAIL message
set /a ERRORS+=1
call :log "  PROBLEM: %~1" "[91m"
goto :eof

:log message ansiColour
@rem Delayed expansion only while echoing, so & | ! in paths print safely.
set "MSG=%~1"
set "CLR=%~2"
setlocal EnableDelayedExpansion
if defined CLR echo(!ESC!!CLR!!MSG!!ESC![0m
if not defined CLR echo(!MSG!
if defined LOG >>"!LOG!" echo(!MSG!
endlocal
goto :eof
