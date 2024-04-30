<#
.SYNOPSIS
   Installtion script for sshnpd on Windows
.DESCRIPTION
    Usage: install_sshnpd [options]

    Sshnp Version: 5.1.0
    Repository: https://github.com/atsign-foundation/sshnoports
    Script Version: 0.1.0

    General options:
      -u, --update                Update all services instead of installing
          --rename                Rename device for client/device pair with the new name
      -l, --local <path>          Install using local zip/tgz
      -r, --repo <path>           Install using local repo
      -h, --help                  Display this help message

    Installation options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -d, --device <address>      Device address (e.g. @alice_device)
      -n, --name <device name>    Name of the device
      -v, --version <version>     Version to install (default: latest)
          --args <args>           Additional arguments to sshnpd ("-v" by default)
          Possible args:
            -s, --[no-]sshpublickey      Update authorized_keys to include public key from sshnp
            -u, --[no-]un-hide           When set, makes various information visible to the manager atSign - e.g. username, version, etc
            -v, --[no-]verbose           More logging

    Rename options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -n, --name <device name>    New name of the device
.PARAMETER install_sshnpd OP
    The operation to perform. Default is "install".
    Rename options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -n, --name <device name>    New name of the device
.EXAMPLE
    Usage: install_sshnpd [options]

    General options:
      -u, --update                Update all services instead of installing
          --rename                Rename device for client/device pair with the new name
      -l, --local <path>          Install using local zip/tgz
      -r, --repo <path>           Install using local repo
      -h, --help                  Display this help message

    Installation options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -d, --device <address>      Device address (e.g. @alice_device)
      -n, --name <device name>    Name of the device
      -v, --version <version>     Version to install (default: latest)
          --args <args>           Additional arguments to sshnpd ("-v" by default)
          Possible args:
            -s, --[no-]sshpublickey      Update authorized_keys to include public key from sshnp
            -u, --[no-]un-hide           When set, makes various information visible to the manager atSign - e.g. username, version, etc
            -v, --[no-]verbose           More logging

    Rename options:
      -c, --client <address>      Client address (e.g. @alice_client)
      -n, --name <device name>    New name of the device
#>
#Prints the help message via get-help install_sshnpd-windows.ps1 
param(
    # [Parameter(Mandatory=$true, HelpMessage="Specify the manager atsign.")]
    # [ValidateNotNullOrEmpty()]
    [string]$CLIENT_ATSIGN,
    [string]$DEVICE_MANAGER_ATSIGN,
    # [Parameter(Mandatory=$true, HelpMessage="Specify the device atsign.")]
    # [ValidateNotNullOrEmpty()]
    [string]$DEVICE_ATSIGN,
    # [Parameter(Mandatory=$true, HelpMessage="Specify the device name.")]
    # [ValidateNotNullOrEmpty()]
    [string]$DEVICE_NAME,
    # [Parameter(Mandatory=$true, HelpMessage="Specify install type, client device or both.")]
    # [ValidateNotNullOrEmpty()]
    [string]$INSTALL_TYPE,
    [string]$HOST_ATSIGN,
    [string]$VERSION
)

### --- IMPORTANT ---
#Make sure to change the values in the help message.
#The help message must be at the top of the script, so no variables.

# SCRIPT METADATA
$script_version = "0.1.0"
$sshnp_version = "5.1.0"
$repo_url = "https://github.com/atsign-foundation/sshnoports"
# END METADATA

#Required for service stuff, if you want to debug comment it out
# if(!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
#     Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList "-File `"$($MyInvocation.MyCommand.Path)`"  `"$($MyInvocation.MyCommand.UnboundArguments)`""
#     Exit
# }


function Norm-Atsign {
    param([string]$str)
    $atsign = "@$($str -replace '"', '' -replace '^@', '')"
    return $atsign
}

function Norm-Version {
    param([string]$str)
    $version = "tags/v$($str -replace '"', '' -replace '^tags/', '' -replace '^v', '')"
    return $version
}

function Norm-InstallType {
    param([string]$str)
    $str = $str.ToLower()
    switch -regex ($str) {
        "^d.*" { return "device" }
        "^c.*" { return "client" }
        "^b.*" { return "both" }
        default { return $null }
    }
}


function Check-BasicRequirements {
    $requiredCommands = @("attrib", "Expand-Archive", "Select-String", "Select-Object", "Start-Service","Test-Path", "New-Item", "Get-Command", "New-Object", "Invoke-WebRequest", "New-Service")
    
    foreach ($command in $requiredCommands) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            Write-Host "[X] Missing required dependency: $command"
        }
    }
}

function Make-Dirs {
    Write-Host $env:HOME
    if (-not (Test-Path "$env:HOME\.atsign")) {
        New-Item -Path "$env:HOME\.atsign" -ItemType Directory -Force
    }
    if(-not (Test-Path "$env:HOME\.atsign\keys")){
        New-Item -Path "$env:HOME\.atsign\keys" -ItemType Directory -Force
    }
    if (-not (Test-Path "$env:HOME\.ssh")) {
        New-Item -Path "$env:HOME\.ssh" -ItemType Directory -Force
    }

    if(-not (Test-Path $ARCHIVE_PATH)){
        New-Item -Path "$ARCHIVE_PATH" -ItemType Directory -Force
    }
    if(-not (Test-Path $INSTALL_PATH)){
        New-Item -Path "$INSTALL_PATH" -ItemType Directory -Force
    }

    if (-not (Test-Path "$env:HOME\.ssh\authorized_keys" -PathType Leaf)) {
        New-Item -Path "$env:HOME\.ssh\authorized_keys" -ItemType File -Force
        attrib "$env:HOME\.ssh\authorized_keys" +h
    }
}

function Parse-Env {
    $script:VERSION = if ([string]::IsNullOrEmpty($VERSION)) { "latest" } else { Norm-Version $VERSION }
    $script:SSHNP_URL = "https://api.github.com/repos/atsign-foundation/noports/releases/$VERSION"
    $script:WINSW_URL = "https://api.github.com/repos/winsw/winsw/releases/$VERSION"
    $script:ARCHIVE_PATH =  "$env:LOCALAPPDATA\atsign\$VERSION"
    $script:homepath = if (-not [string]::IsNullOrEmpty($env:HOME)) { $env:HOME } else { $env:USERPROFILE }
    $script:INSTALL_PATH =  "$homepath\.local\bin"
    $script:INSTALL_TYPE = Norm-InstallType "$script:INSTALL_TYPE"
}
function Cleanup {
    if (Test-Path "$ARCHIVE_PATH") {
        Remove-Item -Path "$ARCHIVE_PATH" -Recurse -Force
    }
}
function Unpack-Archive {
    if (-not (Test-Path "$ARCHIVE_PATH\sshnp.zip")) {
        Write-Host "Failed to download sshnp"
        Exit 1
    }
    if (Test-Path "$script:INSTALL_PATH\sshnp"){
        Remove-Item -Path "$script:INSTALL_PATH\sshnp" -Recurse -Force
    }


    Expand-Archive -Path "$ARCHIVE_PATH\sshnp.zip" -DestinationPath $INSTALL_PATH -Force
    if (-not (Test-Path "$INSTALL_PATH/sshnp/sshnp.exe")) {
        Write-Host "Failed to unpack sshnp"
        Cleanup
        Exit 1
    }
}

function Download-Sshnp {
    Write-Host "Downloading sshnp from $SSHNP_URL"
    $DOWNLOAD_BODY = $(Invoke-WebRequest -Uri $SSHNP_URL).ToString() -split "," | Select-String "browser_download_url" | Select-String "sshnp-windows" | Select-Object -Index 0
    $DOWNLOAD_URL = $DOWNLOAD_BODY.ToString() -split '"' | Select-Object -Index 3
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile "$ARCHIVE_PATH\sshnp.zip"
    if (-not (Test-Path "$ARCHIVE_PATH\sshnp.zip")) {
        Write-Host "Failed to download sshnp"
        Cleanup
        Exit 1
    }
    Unpack-Archive
}

function Download-Winsw {
    $DOWNLOAD_BODY = $(Invoke-WebRequest -Uri $script:WINSW_URL).ToString() -split "," | Select-String "browser_download_url" | Select-String "WinSW-x64" 
    $DOWNLOAD_URL = $DOWNLOAD_BODY.ToString() -split '"' | Select-Object -Index 3
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile "$script:INSTALL_PATH\sshnp\sshnpd_service.exe"
    if (-not (Test-Path "$script:INSTALL_PATH\sshnp\sshnpd_service.exe")) {
        Write-Host "Failed to download winsw"
        Cleanup
        Exit 1
    }
}

function Add-ToPath {
    $pathToAdd = "$script:INSTALL_PATH\sshnp"
    if (Test-Path $script:INSTALL_PATH){
        if ($env:Path -notlike "*$pathToAdd*") {
            $newPath = ($env:Path + ";" + $pathToAdd)
            [Environment]::SetEnvironmentVariable("PATH", $newPath, [EnvironmentVariableTarget]::User)
        } else {
            Write-Host "Path already exists in the environment variable PATH."
        }
    } else {
        Throw "'$pathToAdd' is not a valid path."
    }
}

function Get-InstallType {
    if ([string]::IsNullOrEmpty($script:INSTALL_TYPE)) {
        while ([string]::IsNullOrEmpty($script:INSTALL_TYPE)) {
            $install_type_input = Read-Host "Install type (device, client, both)"
            $script:INSTALL_TYPE = Norm-InstallType $install_type_input
        }
    }
}

function Get-Atsigns {
    $directory = "$homepath\.atsign\keys"
    $prefixes = @()

    if (Test-Path $directory -PathType Container) {
        $files = Get-ChildItem -Path $directory -Filter "*.atKeys" -File

        foreach ($file in $files) {
            $prefix = $file.BaseName -replace '_key$'
            $prefixes += $prefix
        }
    }
    $i = 1
    Write-Host "Found some atsigns, please select one"
    Write-Host "0) None"
    foreach($prefix in $prefixes){
        Write-Host "$i) $prefix"
        $i = $i + 1
    }
    $i = Read-Host "Choose an atsign"
    return $prefixes[$i-1]
}

function Write-Metadata {
    param(
        [string]$file,
        [string]$variable,
        [string]$value
    )
    $start_line = "# SCRIPT METADATA"
    $end_line = "# END METADATA"
    $content = Get-Content -Path $file
    $start_index = $content.IndexOf($start_line)
    $end_index = $content.IndexOf($end_line)
    if ([string]::IsNullOrEmpty($content)) {
        Write-Host "Error: $file is empty"
        return
    }

    if ($start_index -ne -1 -and $end_index -ne -1) {
        for ($i = $start_index; $i -le $end_index; $i++) {
            if ($content[$i] -match "$variable=`".*`"") {
                $content[$i] = $content[$i] -replace "$variable=`".*`"", "$variable=`"$value`""

            }
        }
        $content | Set-Content -Path $file
    } else {
        Write-Host "Error: Metadata block not found in $file"
    }
}

function Install-Client {
    if (-not $HOST_ATSIGN) {
        Write-Host "Pick your default region:"
        Write-Host "  am   : Americas"
        Write-Host "  ap   : Asia Pacific"
        Write-Host "  eu   : Europe"
        Write-Host "  @___ : Specify a custom region atSign"
        while (-not ($host_atsign -match "@.*")) {
            switch -regex ($host_atsign.ToLower()) {
                "^(am).*" {
                    $host_atsign = "@rv_am"
                    break
                }
                "^(eu).*" {
                    $host_atsign = "@rv_eu"
                    break
                }
                "^(ap).*" {
                    $host_atsign = "@rv_ap"
                    break
                }
                "^@" {
                    # Do nothing for custom region
                    break
                }
                default {
                    $host_atsign = Read-Host "Region"
                }
            }
        }
        $script:HOST_ATSIGN = $host_atsign
    }
    $clientPath = "$script:INSTALL_PATH\sshnp\$script:DEVICE_NAME$script:DEVICE_ATSIGN.ps1"
    "sshnp.exe -f '$script:CLIENT_ATSIGN' -t '$script:DEVICE_ATSIGN' -d '$script:DEVICE_NAME' -r '$script:HOST_ATSIGN' -s -u '$Env:UserName'"  | Out-File -FilePath  $clientPath
    if (-not (Test-Path $clientPath -PathType Leaf)) {
        Write-Host "Failed to create client script'. Please check your permissions and try again."
        Cleanup
        Exit 1
    } 
    Write-Host "Created client script for $script:DEVICE_NAME$script:DEVICE_ATSIGN"
    if (-not ($script:INSTALL_TYPE -eq "both")){
        Remove-Item "$script:INSTALL_PATH/sshnp/srv.exe" -Force
        Remove-Item "$script:INSTALL_PATH/sshnp/sshnpd.exe" -Force
    }
}

function Install-Device {
    Write-Host "Installed at_activate and sshnpd binaries to $script:INSTALL_PATH"
    if (-not ($script:INSTALL_TYPE -eq "both")){
        Remove-Item "$script:INSTALL_PATH/sshnp/sshnp.exe" -Force
        Remove-Item "$script:INSTALL_PATH/sshnp/srv.exe" -Force
        Remove-Item "$script:INSTALL_PATH/sshnp/npt.exe" -Force
    }
    Download-Winsw
    $servicePath = "$script:INSTALL_PATH\sshnp\sshnpd_service.exe"
    [xml]$xmlContent = Get-Content "$script:INSTALL_PATH\sshnp\sshnpd_service.xml"
    $xmlContent.service.arguments = "-a $script:DEVICE_ATSIGN -m $script:CLIENT_ATSIGN -d $script:DEVICE_NAME -k $script:homepath/.atsign/keys/$script:DEVICE_ATSIGN"+ "_key.atKeys -s"
    $xmlContent.Save("$script:INSTALL_PATH\sshnp\sshnpd_service.xml")
    if (-not (Test-Path $servicePath -PathType Leaf)) {
        Write-Host "Failed to create service script'. Please check your permissions and try again."
        Cleanup
        Exit 1
    } 
    if (Get-Service sshnpd){
        sshnpd_service.exe uninstall -ErrorAction SilentlyContinue
    }
    sshnpd_service.exe install 
    sshnpd_service.exe start
}

# Main function
function Main {
    Check-BasicRequirements
    Parse-Env
    if ([string]::IsNullOrEmpty($script:INSTALL_TYPE)){
        Get-InstallType
    }
    Make-Dirs
    Download-Sshnp
    Add-ToPath
    while ([string]::IsNullOrEmpty($script:DEVICE_ATSIGN)){
        Write-Host "Selecting a Device atsign.."
        $atsign = Get-Atsigns
        $script:DEVICE_ATSIGN =  Norm-Atsign $atsign
    }
    while([string]::IsNullOrEmpty($script:CLIENT_ATSIGN)){
        Write-Host "Selecting a Client atsign.."
        $atsign = Get-Atsigns
        $script:CLIENT_ATSIGN =  Norm-Atsign $atsign
    }
    $script:DEVICE_NAME = Read-Host "Device Name? "
    switch -regex ($INSTALL_TYPE){
        "client" {
            Install-Client
        }
        "device" {
            Install-Device
        }
        "both" {
            Install-Client
            Install-Device
        }
    }
    Cleanup
    Write-Host "Successfully installed $script:INSTALL_TYPE at $script:INSTALL_PATH, script ending..."
    Start-Sleep -Seconds 10
}

# Execute the main function
Main
