# README #



### What is this repository for? ###


This is the code repo for the SCCM Client Install through Windows 10 Dynamic Provisioning Process.

This is the first version of the process as I intend to perfect the process.


This is still a work in progress, so I will make changes to the readme and code as I do more testing.

### How do I get set up? ###


Software Requirements:

* Windows 1703 ADK - https://go.microsoft.com/fwlink/p/?LinkId=845542

* CAB Maker - https://1drv.ms/u/s!Am50kiwM8EPrwCofxI7rHPnEByvh

* SCCM Powershell Cmdlets - https://www.microsoft.com/en-us/download/details.aspx?id=46681


Hardware Requirements:

* A New Laptop or Desktop to test the process

* Empty USB Stick


Deployment Instructions:

* Use WCD to build the provisioning package

* Copy the package and associated .cat file to the root directory of the usb stick.

* Only packages with OOBE elements needs a new computer for testing


### Contribution guidelines ###


* Feel free to contribute to this project and make improvements.

* I ask that you fork a new branch for each new feature.

* Once a new feature is ready for testing, I can test it and will initiate a pull request.

* If testing is successful, I will merge it into the master branch.


### Who do I talk to? ###


For any issues or idea, feel free to contact me 


### The Provisioning Process ###


1.	OOBE “Out of Box Experience” is hidden 

2.	Local Admin User Account is setup for testing

3.	The Device is joined to the domain

4.	Windows 10 Pro is upgraded to Windows 10 Enterprise

5.	SCCM Client is installed onto the device and sync’d to SCCM Server

6.	After SCCM Client is installed, the device automatically added to a collection.

7.	Once the machine is added to the collection, a task sequence starts to finish the machine setup and configuration.


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

:This part is still in testing

Sleep 60

powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -File AddLocalMachineToCollection.ps1 >> %LOGFILE%


### The rest below is still in beta testing ###


### Part D: Creating the WCD Package Part 3 (Adding the machine to the collection) ###


Introduction: (10,000 FT Overview)


The last part of the process is adding the machine to the sccm collection.


It took a while to figure this part out due to the fact that you can’t add a machine into a collection that doesn’t have the client installed.

The gist of this process is during the batch file process, once the sccm client has been installed, we tell the process to sleep for “x” number of seconds to allow the client time to talk to the sccm server and fully configure. 

Once the configuration has finished and the sleep period ends, a powershell script runs that will add the machine to the collection and allow any required task sequence to run on the machine.


One thing to note is that you must have an admin account setup in sccm with the required permissions in order for the powershell script to remote into the server and add the machine to the collection.


### The Powershell Code ###


#Variables

$Computer = $env:computername

$SCCMServer = "sccmserver name"

$SiteCode = "your site code"

$CollectionID = "CollectionID"

#$ADCredentials = New-Object System.Management.Automation.PSCredential (“domain\username”, (ConvertTo-SecureString “password” -AsPlainText -Force))


$pw = convertto-securestring -AsPlainText -Force -String Password

$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "domain\username",$pw


#Initiate the Remote CM Session

$session = New-PSSession -ComputerName $sccmServer -Credential $cred -ConfigurationName Microsoft.PowerShell32

Invoke-Command -Session $session -ScriptBlock { Import-Module -Name "$(split-path $Env:SMS_ADMIN_UI_PATH)\ConfigurationManager.psd1"; Set-Location -path "$(Get-PSDrive -PSProvider CMSite):\" -verbose }

Import-PSSession -Session $session -Module ConfigurationManager -AllowClobber


$PSD = Get-PSDrive -PSProvider CMSite

CD "$($PSD)"


#Add Local Machine to Collection

Add-CMDeviceCollectionDirectMembershipRule -CollectionID $CollectionID -ResourceId $(Get-CMDevice -Name $Computer).ResourceID 



### References ###


https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-install-icd

https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provision-pcs-with-apps

https://docs.microsoft.com/en-us/windows/configuration/provisioning-packages/provisioning-script-to-install-app
