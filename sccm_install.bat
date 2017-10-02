set LOGFILE=%SystemDrive%\install_sccm_client.log
echo Expanding installer_assets.cab >> %LOGFILE%
expand -r sccmclient.cab -F:* . >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%
echo Installing SCCM-Client >> %LOGFILE%
Ccmsetup.exe /switches >> %LOGFILE%
echo result: %ERRORLEVEL% >> %LOGFILE%
