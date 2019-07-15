# README #



### What is this repository for? ###


This is the code repo for the SCCM Client Install through Windows 10 Dynamic Provisioning Process.

This is the third version of the process as I iterated it a few times to tweak different issues.


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
  
### Why Dynamic Provisioning? ###

* Any store bought Windows device (Desktop,Laptop,Tablet) can be made Enterprise Ready in a matter of minutes.

* Required Software is installed on a new machine in Minutes VS. Microsoft inTune which takes up to 24 hours to install required apps.

* Less time to maintain than traditional Imaging/OSD through SCCM

* Totally Vendor Agnostic

* No Need to Update Drivers or Driver Sets

### The Provisioning Process ###

1. The Machine is Unboxed. (New Machines Only)

2. The Provisioning USB is Plugged into the Machine.

3. The Machine is Turned On and the Package is Automatically Read.

4.	OOBE “Out of Box Experience” is bypassed.

5.	The Device is joined to the domain

6.	Windows 10 Pro is upgraded to Windows 10 Enterprise

7.	SCCM Client is installed onto the device and sync’d to SCCM Server

8.  Google Chrome is Installed.(To interface with Web Server)

9. Pre-Configured Windows 10 Start Menu files are Copied to the Default User Folder.

10. The Service Account Auto-Login and Reboot Registry keys are imported.

11. The Scheduled Task to add the machine to the collection is created.

### ICD Provisioning Ends ###

### POST-PROVISIONING SETUP ###

12.	The Machine Auto-Logs into the Domain Joined Service Account.

13. The System waits for 1:30 mins for SCCM to Configure and sync with Site Server.

14. The System then reboots and Auto-Logins back into Domain Service Account.

15. The Scheduled Task Runs and Google Chrome is automatically opened to the Web Server address.

16. The local machine name is passed to the site server.

17. The Machine is then added to the Provisioning SCCM Collection via the Add local machine to collection Powershell code.

18. The machine retrives the SCCM policy then starts downloading the task sequence. 

19.	The Enterprise Software and Configure Task Sequence completes to finish the machine setup, install required software and complete the configuration.

20. Finally, an Anti-Virus WQL Query is checked against the collection and if the Task Sequence is successful AND the Anti-Virus software is installed, the machine name is automatically cleansed from the collection. (This prevents the TS from being re-ran on the machine.)


### Part A: File Compression ###


In order to successfully install the SCCM Client by Windows 10 Dynamic Provisioning (WCD), the SCCM Client installer: “CCMSetup.exe”, along with all the dependancies that must be packaged into a CAB file for easy reading and extraction.

This can be done one of two ways:

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


## The Process: ##

In order to include the CAB file into the WICD package, I chose DeviceContext in the ProvisioningCommands menu. 


ProvisioningCommands (Top Level Menu)

-	DeviceContext

•	CommandFiles = sccmclient.cab  

                 = sccm-install.bat

                 = sccmclient.cab


•	CommandLine = cmd /c sccm-install.bat


### The Batch File Code ###

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

### Part D: Creating the WCD Package Part 3 (Adding the Machine to the Collection) ###


## Introduction: (10,000 FT Overview) ##


The last part of the process is adding the machine to the sccm collection.

It took a while to figure this part out, due to the fact that you can’t add a machine into a collection that doesn’t have the client installed. (No Client = No Record in SCCM DB)

The gist of this process is during the batch file process, once the SCCM client has been installed, a scheduled task is created to run the Add to Collection Script and the machine reboots.

Once the machine has rebooted and logged in, a Google Chrome session opens and runs the url of our web server that is located on the SCCM Server.

By using a web server to communicate with SCCM, we simplify the process and eliminate the need for a coded credentials in the provisioning package. 

Lastly, we set the computer to auto-login to the SCCM Service Account, so the process is automated.

### Server-Side Powershell Code ###

*Note* $args[1] pulls the machine name from the client machine running the provisioning package.
$Computer = $args[1]
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

$Computer | Out-String 

### AutoLogin Registry Code ###

Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon]
"DefaultUserName"="Domain\ServiceAccount"
"AutoAdminLogon"="1"
"DefaultPassword"="Password"
"DefaultDomain"="constoco.com"

### Post-Process Clean ###

Once the task sequence finishes, the collection is evaluted for having McAfee Agent installed,
and the machines are removed collection once evaluated. 


### References ###


https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-install-icd

https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provision-pcs-with-apps

https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-script-to-install-app

