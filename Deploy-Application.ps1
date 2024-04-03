<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false,
	[switch]$AdminMode = $true,
	[String]$WingetScope  = '',
	[String]$WingetID = '',
	[String]$WingetCM = ''
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    } Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = "$WingetID"
    [String]$appName = 'WingetFW'
    [String]$appVersion = '3.0'
    [String]$appArch = 'User'
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '04/03/2024'
    [String]$appScriptAuthor = 'Kris Spangenberg'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.10.0'
    [String]$deployAppScriptDate = '03/27/2024'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'
		
        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        #Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
		
        ## Show Progress Message (with the default message)
        #Show-InstallationProgress
		
        ## <Perform Pre-Installation tasks here>
		If($AdminMode){
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
			$AppInstaller = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller
			If($AppInstaller.Version -lt "2023.1005.18.0") {
				
				Write-Log -Message "Winget is not installed, trying to install latest version from Github" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
				
				Try {
					
					Write-Log -Message "Creating Winget Packages Folder" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					
					if (!(Test-Path -Path C:\ProgramData\WinGetPackages)) {
						New-Item -Path C:\ProgramData\WinGetPackages -Force -ItemType Directory
					}
					
					#Set-Location C:\ProgramData\WinGetPackages
					
					#Downloading Packagefiles
					Write-Log -Message "Setting ProgressPreference to SilentlyContinue" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					$ProgressPreference = 'SilentlyContinue'
					#Microsoft.UI.Xaml - newest
					Write-Log -Message "Downloading microsoft.ui.xaml.newest.zip from https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/" -OutFile "C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest.zip"
					Write-Log -Message "Exstract C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest.zip" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Expand-Archive C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest.zip -Force
					#Microsoft.VCLibs.140.00.UWPDesktop
					Write-Log -Message "Downloading Microsoft.VCLibs.x64.14.00.Desktop.appx from https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "C:\ProgramData\WinGetPackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
					#Winget
					Write-Log -Message "Downloading Winget.msixbundle from https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "C:\ProgramData\WinGetPackages\Winget.msixbundle"
					Write-Log -Message 'Finding the MicrosoftUIXaml Version and shave the it to $MicrosoftUIXamlVersion' -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					$MicrosoftUIXamlVersion = Get-ChildItem C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest\tools\AppX\x64\Release -recurse | where {$_.name -like "Microsoft.UI.Xaml.*"} | select name
					#Installing dependencies + Winget
					Write-Log -Message "Installing winget and Dependency Package" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Add-ProvisionedAppxPackage -online -PackagePath:C:\ProgramData\WinGetPackages\Winget.msixbundle -DependencyPackagePath C:\ProgramData\WinGetPackages\Microsoft.VCLibs.x64.14.00.Desktop.appx,C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest\tools\AppX\x64\Release\$($MicrosoftUIXamlVersion.name) -SkipLicense
					
					Write-Log -Message "Starting sleep for Winget to initiate" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Start-Sleep 2
				}
				Catch {
					Throw "Failed to install Winget"
					Write-Log -Message "$Error[0].Exception" -Source 'Failed-PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Break
				}
			
			}Else{
				Write-Log -Message "Winget already installed, moving on" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
			}
        }Else{
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
            $AppInstaller = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller
			If($AppInstaller.Version -lt "2023.1005.18.0") {
				Write-Log -Message "Winget is not installed" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
			}Else{
				Write-Log -Message "Winget already installed, moving on" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
			}
        }
		
		
        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'
		
        ## <Perform Installation tasks here>
		
		If($AdminMode){
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
			IF ($WingetID){
				try {
					Write-Log -Message "Installing $($WingetID) via Winget" -Source 'INSTALLATION' -LogType 'CMTrace'
					
					$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_1.21*_x64__8wekyb3d8bbwe"
					if($ResolveWingetPath -EQ $null){
						$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
					}
					if($ResolveWingetPath){
						$WingetPath = $ResolveWingetPath[-1].Path
					}
					
					Execute-Process -Path "$wingetpath\winget.exe" -Parameters "install $WingetID --silent --accept-source-agreements --accept-package-agreements $WingetCM $WingetScope" -WindowStyle 'Hidden'
					
				}
				Catch {
					Throw "Failed to install package $($_)"
				}
			}Else{
				Write-Log -Message "Package $($WingetID) not available" -Source 'INSTALLATION' -LogType 'CMTrace'
			}
		}Else{
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
			IF ($WingetID){
				try {
					Write-Log -Message "Installing $($WingetID) via Winget" -Source 'INSTALLATION' -LogType 'CMTrace'
					
					$ResolveWingetPath = Resolve-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller*\"
					if($ResolveWingetPath -EQ $null){
						$ResolveWingetPath = Resolve-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\"
					}
					if($ResolveWingetPath){
						$WingetPath = $ResolveWingetPath[-1].Path
					}
					
					Execute-Process -Path "$wingetpath\winget.exe" -Parameters "install $WingetID --silent --accept-source-agreements --accept-package-agreements $WingetCM $WingetScope" -WindowStyle 'Hidden'
					
				}
				Catch {
					Throw "Failed to install package $($_)"
				}
			}Else{
				Write-Log -Message "Package $($WingetID) not available" -Source 'INSTALLATION' -LogType 'CMTrace'
			}
		}
		
        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'
		
        ## <Perform Post-Installation tasks here>
		
        ## Display a message at the end of the install
        
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'
		
        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        #Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60
		
        ## Show Progress Message (with the default message)
        #Show-InstallationProgress
		
        ## <Perform Pre-Uninstallation tasks here>
		
		If($AdminMode){
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
			$AppInstaller = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller
			If($AppInstaller.Version -lt "2023.1005.18.0") {
				
				Write-Log -Message "Winget is not installed, trying to install latest version from Github" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
				
				Try {
					
					Write-Log -Message "Creating Winget Packages Folder" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					
					if (!(Test-Path -Path C:\ProgramData\WinGetPackages)) {
						New-Item -Path C:\ProgramData\WinGetPackages -Force -ItemType Directory
					}
					
					#Set-Location C:\ProgramData\WinGetPackages
					
					#Downloading Packagefiles
					Write-Log -Message "Setting ProgressPreference to SilentlyContinue" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					$ProgressPreference = 'SilentlyContinue'
					#Microsoft.UI.Xaml - newest
					Write-Log -Message "Downloading microsoft.ui.xaml.newest.zip from https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/" -OutFile "C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest.zip"
					Write-Log -Message "Exstract C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest.zip" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Expand-Archive -LiteralPath "C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest.zip" -DestinationPath "C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest" -Force
					#Microsoft.VCLibs.140.00.UWPDesktop
					Write-Log -Message "Downloading Microsoft.VCLibs.x64.14.00.Desktop.appx from https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "C:\ProgramData\WinGetPackages\Microsoft.VCLibs.x64.14.00.Desktop.appx"
					#Winget
					Write-Log -Message "Downloading Winget.msixbundle from https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Invoke-WebRequest -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -OutFile "C:\ProgramData\WinGetPackages\Winget.msixbundle"
					Write-Log -Message 'Finding the MicrosoftUIXaml Version and shave the it to $MicrosoftUIXamlVersion' -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					$MicrosoftUIXamlVersion = Get-ChildItem C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest\tools\AppX\x64\Release -recurse | where {$_.name -like "Microsoft.UI.Xaml.*"} | select name
					#Installing dependencies + Winget
					Write-Log -Message "Installing winget and Dependency Package" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Add-ProvisionedAppxPackage -online -PackagePath:C:\ProgramData\WinGetPackages\Winget.msixbundle -DependencyPackagePath C:\ProgramData\WinGetPackages\Microsoft.VCLibs.x64.14.00.Desktop.appx,C:\ProgramData\WinGetPackages\microsoft.ui.xaml.newest\tools\AppX\x64\Release\$($MicrosoftUIXamlVersion.name) -SkipLicense
					
					Write-Log -Message "Starting sleep for Winget to initiate" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Start-Sleep 2
				}
				Catch {
					Write-Log -Message "$_.ScriptStackTrace" -Source 'Failed-PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
					Throw "Failed to install Winget"
					Break
				}
			
			}Else{
				Write-Log -Message "Winget already installed, moving on" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
			}
		}Else{
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
			$AppInstaller = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller
			If($AppInstaller.Version -lt "2023.1005.18.0") {
				Write-Log -Message "Winget is not installed" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
			}Else{
				Write-Log -Message "Winget already installed, moving on" -Source 'PRE-INSTALLATION-WINGET' -LogType 'CMTrace'
			}
		}
		
        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'
		
        ## <Perform Uninstallation tasks here>
		
		If($AdminMode){
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
			IF ($WingetID){
				try {
					Write-Log -Message "Uninstalling $($WingetID) via Winget" -Source 'UNINSTALLATION' -LogType 'CMTrace'
					
					$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
					if ($ResolveWingetPath){
						   $WingetPath = $ResolveWingetPath[-1].Path
					}
					
					Execute-Process -Path "$wingetpath\winget.exe" -Parameters "uninstall $WingetID --silent $WingetCM" -WindowStyle 'Hidden' -ContinueOnError $True
					
				}
				Catch {
					Throw "Failed to uninstall package $($_)"
				}
			}Else{
				Write-Log -Message "Package $($WingetID) not available" -Source 'UNINSTALLATION' -LogType 'CMTrace'
			}
		}Else{
			Write-Log -Message "AdminMode $AdminMode" -Source 'AdminMode' -LogType 'CMTrace'
			IF ($WingetID){
				try {
					Write-Log -Message "Uninstalling $($WingetID) via Winget" -Source 'UNINSTALLATION' -LogType 'CMTrace'
					
					$ResolveWingetPath = Resolve-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller*\"
					if($ResolveWingetPath -EQ $null){
						$ResolveWingetPath = Resolve-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\"
					}
					if ($ResolveWingetPath){
						   $WingetPath = $ResolveWingetPath[-1].Path
					}
					
					Execute-Process -Path "$wingetpath\winget.exe" -Parameters "uninstall $WingetID --silent $WingetCM" -WindowStyle 'Hidden' -ContinueOnError $True
					
				}
				Catch {
					Throw "Failed to uninstall package $($_)"
				}
			}Else{
				Write-Log -Message "Package $($WingetID) not available" -Source 'UNINSTALLATION' -LogType 'CMTrace'
			}
		}
		
        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'
		
        ## <Perform Post-Uninstallation tasks here>
		
		
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'
		
        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        #Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60
		
        ## Show Progress Message (with the default message)
        #Show-InstallationProgress
		
        ## <Perform Pre-Repair tasks here>
		
        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'
		
        ## <Perform Repair tasks here>
		
        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'
		
        ## <Perform Post-Repair tasks here>
		
		
    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
