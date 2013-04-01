@echo off

echo.
echo Deprecated! Use autoit.exe to run script instead of compiling executable file.
echo.

set IN=PuTTYAssist.au3
for /f "tokens=5 delims= " %%i in ('find /i "$VERSION =" %IN%') do (
	set VER=%%i
)
set OUT=PuTTYAssist-%VER:~1,-1%.exe

set REG="HKEY_LOCAL_MACHINE\SOFTWARE\AutoIt v3\AutoIt"
set REG64="HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\AutoIt v3\AutoIt"
reg query %REG% 1>nul 2>&1
if errorlevel 1 set REG=%REG64%
for /f "tokens=1,2,*" %%i in ('reg query %REG% /v InstallDir') do (
	if /i InstallDir equ %%i set INSTALLDIR=%%k
)
set AUT2EXE=%INSTALLDIR%\Aut2Exe\Aut2exe.exe

echo Building PuTTY Assist......
echo Aut2Exe %AUT2EXE%
echo IN      %IN%
echo OUT     %OUT%
echo.

"%AUT2EXE%" /in %IN% /out %OUT% /nopack
if errorlevel 1 (
	echo ERROR %errorlevel%
	REM ~ pause
) else (
	echo DONE!
)
