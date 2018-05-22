set LOGFILE=%SystemDrive%\Windows\Logs\install_sccm_client.log
set curTimestamp=%date:~7,2%_%date:~3,3%_%date:~10,4%_%time:~0,2%_%time:~3,2%
echo Provisioning Starting Time: %curTimestamp% >> %LOGFILE%
echo Creating Logs Folder >> %LOGFILE%
mkdir C:\Logs >> %LOGFILE%
echo Expanding sccmclient.cab >> %LOGFILE%
expand -r sccmclient.cab -F:* . >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%
echo Installing SCCM Client Software >> %LOGFILE%
Ccmsetup.exe >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%

echo Installing Google Chrome
googlechromestandaloneenterprise64.msi /qn >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%

echo Copying Start Menu Configuration >> %LOGFILE%
copy DefaultLayouts.xml C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\StartMenu.xml >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%
copy LayoutModification.xml C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%
 
echo Creating Scheduled Task >> %LOGFILE%
powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -File AddLocalMachineToCollection.ps1 >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%

echo Adding AutoLogin to local test account >> %LOGFILE%
regedit.exe /S autologin.reg >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%

echo Running GP Update >> %LOGFILE%
gpupdate /force >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%

echo Provisioning Completed at:%curTimestamp%  >> %LOGFILE%
