# README #



### What is this repository for? ###


This is the code repo for the SCCM Client Install through Windows 10 Dynamic Provisioning Process.

This is the first version of the process as I intend to perfect the process.


This is still a work in progress, so I will make changes to the readme and code as I do more testing.

### How do I get set up? ###


Software Requirements:

* Windows 1709 ADK (or higher) - https://go.microsoft.com/fwlink/p/?LinkId=845542

* CAB Maker - https://1drv.ms/u/s!Am50kiwM8EPrwCofxI7rHPnEByvh

* SCCM Powershell Cmdlets - https://www.microsoft.com/en-us/download/details.aspx?id=46681


Hardware Requirements:

* A New Laptop or Desktop to test the process

* Empty USB Stick

* A Wired Ethernet Connection


Deployment Instructions:

* Use ICD to build the provisioning package

* Copy the package and associated .cat file to the root directory of the usb stick.

* Only packages with OOBE elements needs a new computer for testing;
  Otherwise, a used computer can be used for a refresh.


### Contribution guidelines ###


* Feel free to contribute to this project and make improvements.

* I ask that you fork a new branch for each new feature.

* Once a new feature is ready for testing, I can test it and will initiate a pull request.

* If testing is successful, I will merge it into the master branch.


### Who do I talk to? ###


For any issues or idea, feel free to contact me 


### The Provisioning Process ###

1. The Machine is Unboxed. (New Machines Only)

2. The Provisioning USB is Plugged into the Machine.

3. The Machine is Turned On and the Package is Automatically Read.

4.	OOBE “Out of Box Experience” is bypassed.

5.	Local Admin User Account is setup for testing & troubleshooting.

6.	The Device is joined to the domain

7.	Windows 10 Pro is upgraded to Windows 10 Enterprise

8.	SCCM Client is installed onto the device and sync’d to SCCM Server

9. Google Chrome is Installed.

10. Pre-Configured Windows 10 Start Menu files are Copied to the Default User Folder.

11. The Service Account Auto-Login and Reboot Registry keys are imported.

12. The Scheduled Task to add the machine to the collection is created.

### ICD Provisioning Ends ###

### POST-PROVISIONING SETUP ###

13.	The Machine Auto-Logs into the Domain Joined Service Account.

14. The System waits for 1:30 mins for SCCM to Configure.

15. The System then reboots and Auto-Logins back into Domain Service Account.

16. The Scheduled Task Runs and Google Chrome is automatically opened to the Web Server.

17. The Machine is then added to the Provisioning SCCM Collection.

18.	Lastly, a task sequence starts to finish the machine setup, install software and complete the configuration.


### Part A: File Compression ###


In order to successfully install the SCCM Client by Windows 10 Dynamic Provisioning (WCD), the SCCM Client installer “CCMSetup.exe” along with all the dependancies must be packaged

into a CAB file for easy reading and extraction.

This can be one of two ways:


A.	Using the makecab command line

B.	Using a CAB packaging software (Due to issues with makecab, I used CAB Maker.)


### Part B: Creating the WCD Package Part 1 (Computer Setup)


For my package, I selected the “Advanced Provisioning” option along with “All Windows Desktop Editions” .


To create the actual package, I used the following settings:


A.  Hide OOBE 

-	OOBE -> HideOobe = True


B.	Create a Local Account

-	Users -> UserName =  TestUser, 

-   Password = TestPassword, 

-	UserGroup = Admin


C.	Join The Machine to the Domain and AD

-	ComputerAccount  

•	Account = Domain account used to join the domain

•	AccountOU = OU=SubOU,OU=TopOU,DC=subdomain,DC=domain,DC=extension

•	ComputerName = PREFIX-%SERIAL% (Uses asset tag to name computer)

•	DomainName = CompanyDomainName.com

•	Password = Password used to join to domain


D.	Upgrade to Windows 10 Enterprise Edition

-	UpgradeEditionWithProductKey = NPPR9-FWDCX-D2C8J-H872K-2YT43 (KMS Key)


### Part C: Creating the WCD Package Part 2 (Installing SCCM Client) ###


Introduction: (10,000 FT Overview)

In order to allow the SCCM Client to install successfully during the process, I had to combine all the files and dependencies into a single CAB file for easy compression and extraction. 

The files that were included in the CAB are the entirety of the Client folder from the SCCM Client including both the x86 and x64 folders. 

Once I had the files compressed into a CAB File, I wrote a batch file to extract the contents, run ccmsetup.exe with the required switches and log the process with each step for easy troubleshooting. 


The Process:

In order to include the CAB file into the WICD package, I chose DeviceContext in the ProvisioningCommands menu. 


ProvisioningCommands (Top Level Menu)

-	DeviceContext

•	CommandFiles = sccmclient.cab  

                 = sccm-install.bat

                 = AddLocalMachineToCollection.ps1


•	CommandLine = cmd /c sccm-install.bat


### The Batch File Code ###


set LOGFILE=%SystemDrive%\install_sccm_client.log


echo Expanding installer_assets.cab >> %LOGFILE%

expand -r sccmclient.cab -F:* . >> %LOGFILE%

echo result: %ERRORLEVEL% >> %LOGFILE%

echo Installing SCCM-Client >> %LOGFILE%

Ccmsetup.exe  >> %LOGFILE%

echo result: %ERRORLEVEL% >> %LOGFILE%

echo Adding Local Machine to Collection Via Web Server >> %LOGFILE%

start iexplore.exe http://webserver/RunScriptWithArgument?argument=%COMPUTERNAME% >> %LOGFILE%

echo Adding AutoLogin to local test account >> %LOGFILE%
regedit.exe /S autologin-prov.reg >> %LOGFILE%


### Part D: Creating the WCD Package Part 3 (Adding the machine to the collection) ###


Introduction: (10,000 FT Overview)


The last part of the process is adding the machine to the sccm collection.


It took a while to figure this part out due to the fact that you can’t add a machine into a collection that doesn’t have the client installed.

The gist of this process is during the batch file process, once the sccm client has been installed, a scheduled task is created to run the Collection Add Script.

Once the configuration has finished and the sleep period ends, an Internet Explorer session opens and runs the url of our web server that is located on the SCCM Server.

By using a web server to communicate with SCCM, we simplify the process and eliminate the need for a coded credentials in the provisioning package. 

Lastly, we set the computer to auto-login to the test account, so the process is automated.

I am still tweaking the code below but it currently works as intended.

### Server-Side Powershell Code ###

#Variables
# $args[1] pulls the location machine name from machine running the provisioning package.
$Computer1 = $args[1]
$SCCMServer = "localhost"
$SiteCode = "SITECODE"
$CollectionID = "Collection ID"

$pw = convertto-securestring -AsPlainText -Force -String Account_Password
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "cdm_inc\service_account_username",$pw

#Initiate the Remote CM Session
$session = New-PSSession -ComputerName $sccmServer -Credential $cred -ConfigurationName Microsoft.PowerShell32
Invoke-Command -Session $session -ScriptBlock { Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"; Set-Location -path "$(Get-PSDrive -PSProvider CMSite):\" -verbose }
Import-PSSession -Session $session -Module ConfigurationManager -AllowClobber


#Add Local Machine to Collection
Add-CMDeviceCollectionDirectMembershipRule -CollectionID $CollectionID -ResourceId $(Get-CMDevice -Name $Computer1).ResourceID

$Computer1 | Out-String 

### AutoLogin Registry Code ###

Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon]
"DefaultUserName"="TestUser"
"AutoAdminLogon"="1"
"DefaultPassword"="Password"

### Post-Process Clean ###

Once the task sequence runs, a clean script is triggered that removes any scheduled tasks,
left-over files, etc that was used during the provisioning process.


### References ###


https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-install-icd

https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provision-pcs-with-apps

https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-script-to-install-app
