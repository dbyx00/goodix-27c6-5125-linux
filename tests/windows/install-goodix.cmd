@echo off
setlocal
set LOG=C:\goodix-test.log
echo ==== Goodix test %DATE% %TIME% ==== > "%LOG%"
echo Script dir: %~dp0 >> "%LOG%"

rem Do not let Windows Update replace this OEM driver.
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" /v SearchOrderConfig /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f >> "%LOG%" 2>&1

echo ==== pnputil add-driver ==== >> "%LOG%"
pnputil /add-driver "%~dp0gfusb.inf" /install >> "%LOG%" 2>&1

echo ==== devices ==== >> "%LOG%"
pnputil /enum-devices /class Biometric >> "%LOG%" 2>&1
pnputil /enum-drivers | findstr /i "goodix gfusb" >> "%LOG%" 2>&1

echo ==== done ==== >> "%LOG%"
endlocal
