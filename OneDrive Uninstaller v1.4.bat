@rem OneDrive Complete uninstaller batch process for Windows 10.
@rem Run as administrator to completely delete all OneDrive components and files.
@rem Written by TERRA Operative - 2020/03/02. V1.4
@rem Feel free to distribute freely as long as you leave this entire file unchanged and intact,
@rem and if you do make changes and adaptions, don't be a dick about not attributing where due.
@rem And most importantly, peace out and keep it real.

@echo OFF

@REM Set variables for coloured text
SETLOCAL EnableDelayedExpansion
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set "DEL=%%a"
)

   echo ------Windows 10 OneDrive Uninstaller V1.4------
   echo.
   
@rem This code block detects if the script is being running with admin privileges. If it isn't it pauses and then quits.
NET SESSION >nul 2>&1
IF %ERRORLEVEL% EQU 0 (


   echo        Administrator Privileges Detected!
   echo.
) ELSE (

   echo.
   call :colorEcho 0C "########### ERROR - ADMINISTRATOR PRIVILEGES REQUIRED #############"
   echo.
   call :colorEcho 0C "#                                                                 #"
   echo.
   call :colorEcho 0C "#"
   call :colorEcho 07 "    This script must be run as administrator to work properly."
   call :colorEcho 0C "    #"
   echo.
   call :colorEcho 0C "#"
   call :colorEcho 07 "    If you're seeing this after double clicking on the icon,"
   call :colorEcho 0C "     #"
   echo.
   call :colorEcho 0C "#"
   call :colorEcho 07 "  then right click on the icon and select 'Run As Administrator'"
   call :colorEcho 0C " #"
   echo.
   call :colorEcho 0C "#                                                                 #"
   echo.
   call :colorEcho 0C "###################################################################"
   echo.
   echo.

   PAUSE
   EXIT /B 1
)

   echo -----------------------------------------------
   call :colorEcho 0C "                    WARNING"
   echo.
   call :colorEcho 0C "  This script will completely and permanently"
   echo.
   call :colorEcho 0C "      remove OneDrive from your computer."
   echo.
   call :colorEcho 0C "        Make sure all OneDrive documents"   
   echo.
   call :colorEcho 0C "       that are stored locally are fully"
   echo.
   call :colorEcho 0C "          backed up before proceeding."   
   echo.
   echo -----------------------------------------------
   echo.

   SET /P M=  Press 'Y' to continue or any other key to exit. 
	if %M% ==Y goto PROCESSKILL
	if %M% ==y goto PROCESSKILL

   EXIT /B 1


@rem The following is based on info from here written by 'LK':
@rem https://techjourney.net/disable-or-uninstall-onedrive-completely-in-windows-10/


@rem Terminate any OneDrive process
:PROCESSKILL
   echo.
   echo Terminating OneDrive process.
   
taskkill /f /im OneDrive.exe


@rem Detect if OS is 32 or 64 bit
reg Query "HKLM\Hardware\Description\System\CentralProcessor\0" | find /i "x86" > NUL && set OS=32BIT || set OS=64BIT

if %OS%==32BIT GOTO 32BIT
if %OS%==64BIT GOTO 64BIT


@rem Uninstall OneDrive app
:32BIT
   echo.
   echo This is a 32-bit operating system.
   echo Removing OneDrive setup files.
   
%SystemRoot%\System32\OneDriveSetup.exe /uninstall
GOTO CLEAN

:64BIT
   echo.
   echo This is a 64-bit operating system.
   echo Removing OneDrive setup files.
   
%SystemRoot%\SysWOW64\OneDriveSetup.exe /uninstall
GOTO CLEAN


@rem Clean and remove OneDrive remnants
:CLEAN
   echo.
   echo Removing remaining OneDrive folders.
   
   rd "%UserProfile%\OneDrive" /s /q
   rd "%LocalAppData%\Microsoft\OneDrive" /s /q
   rd "%ProgramData%\Microsoft OneDrive" /s /q
   rd "C:\OneDriveTemp" /s /q
   del "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" /s /f /q
   
   echo.
   call :colorEcho 0C "If you see 'access denied' errors here, reboot and run this batch file again."
   echo.
   echo.
   echo 'The system cannot find the file specified.' errors are ok, it means the files are already gone.
   echo.



@rem Delete and remove OneDrive in file explorer folder tree registry key
   echo -----------------------------------------------
   echo.
   echo Removing OneDrive registry keys.
   
   REG Delete "HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f
   REG Delete "HKEY_CLASSES_ROOT\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /f
   REG ADD "HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" /v System.IsPinnedToNameSpaceTree /d "0" /t REG_DWORD /f

   echo.
   echo.
   echo 'The system was unable to find the specified registry key or value.' errors are ok,
   echo it means the Registry entries already don't exist.
   echo.
   echo -----------------------------------------------
   echo.
   echo OneDrive Uninstall and cleaning completed.
   echo.

   PAUSE
   echo So long and thanks for all the fish...
   PING -n 2 127.0.0.1>nul
   EXIT /B 1

   
@rem Settings for text colour

:colorEcho
echo off
<nul set /p ".=%DEL%" > "%~2"
findstr /v /a:%1 /R "^$" "%~2" nul
del "%~2" > nul 2>&1i