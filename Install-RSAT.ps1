<#     
	.NOTES
    ===========================================================================
	            Created on:    02/12/2019
                Modified on:   02/14/2019
	            Created by:    Taylor Triggs
                Notes:         Run as Administrator and requires internet access
	            Dependencies:  PowerShell 5.0
    ===========================================================================

    .SYNOPSIS 
            Script installs the Remote Server Administration Tools on Windows 10 build 1809+
            Requires active internet connection to install
            Temporarily changes the registry to not use WSUS

    .DESCRIPTION
            Useful DISM commands
            DISM.exe /Online /Get-Capabilities
            DISM.exe /Online /Add-Capability /CapabilityName:Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0
            DISM.exe /Online /Remove-Capability /CapabilityName:Rsat.VolumeActivation.Tools~~~~0.0.1.0

    .EXAMPLE
            . \Install-RSAT.ps1

    .LINK
            https://www.microsoft.com/en-us/download/details.aspx?id=45520
#>

$features = @(
    "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0",
    "Rsat.CertificateServices.Tools~~~~0.0.1.0",
    "Rsat.DHCP.Tools~~~~0.0.1.0", "Rsat.Dns.Tools~~~~0.0.1.0", 
    "Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0",
    "Rsat.FileServices.Tools~~~~0.0.1.0", 
    "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0", 
    "Rsat.IPAM.Client.Tools~~~~0.0.1.0", 
    "Rsat.LLDP.Tools~~~~0.0.1.0", 
    "Rsat.NetworkController.Tools~~~~0.0.1.0", 
    "Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0", 
    "Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0", 
    "Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0", 
    "Rsat.ServerManager.Tools~~~~0.0.1.0", 
    "Rsat.Shielded.VM.Tools~~~~0.0.1.0", 
    "Rsat.StorageReplica.Tools~~~~0.0.1.0", 
    "Rsat.VolumeActivation.Tools~~~~0.0.1.0", "Rsat.WSUS.Tools~~~~0.0.1.0", 
    "Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0",
    "Rsat.SystemInsights.Management.Tools~~~~0.0.1.0"
)

$featuresCount = $features.Count

# Returns bool for registry existence
function Test-RegistryValue
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Path,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Name
    )
        
    try
    {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Name -ErrorAction Stop | Out-Null
        return $true
    }
        
    catch
    {
        return $false
    }  
}

# Corrects registry values if they are incorrect
function Fix-RegistryValue
{
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Path,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Name,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $RegChangeValue
    )

    $regValue = Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Name

    if ($regValue -ne $RegChangeValue)
    {
        try 
        { 
            Set-ItemProperty -Path $Path -Name $Name -Value $RegChangeValue -Type DWORD -ErrorAction Stop
        }

        catch 
        {
            Write-Host -ForegroundColor Red "Reg was not able to be corrected, please look at" $Path
        }
    }

    else 
    {
        Write-Output "Reg value was not changed"
    }
}

# Checks for Internet access by looking up your public ip
Function Get-ExternalIP
{
    try
    {
        Invoke-RestMethod http://ipinfo.io/json | Select-Object -ExpandProperty ip
        return $true
    }

    catch
    {
        return $false
    }
}

$getOS = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
$getBuild = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name CurrentBuild).CurrentBuild + '.' + ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name UBR).UBR)

$ErrorActionPreference = 'Stop' #'SilentlyContinue'

if ( ($getOS -like "Windows 10*") -and ($getBuild -ige 17763.0) )
{   
    $checkInternet = Get-ExternalIP

    if ($checkInternet -eq $false)
    {
        Write-Host -ForegroundColor Red "You need an active internet connection to run this installer"
    }

    else
    {
        # 1 - Temporarily change registry keys to allow online Microsoft Updates after capturing the previous values
        $regPath1 = "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        $regItem1 = "DoNotConnectToWindowsUpdateInternetLocations"
        $regItemPropValue1 = Get-ItemPropertyValue -Path $regPath1 -Name $regItem1

        $regPath2 = "Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        $regItem2 = "UseWUServer"
        $regItemPropValue2 = Get-ItemPropertyValue -Path $regPath2 -Name $regItem2

        $registryTest1 = Test-RegistryValue -Path $regPath1 -Name $regItem1
        $registryTest2 = Test-RegistryValue -Path $regPath2 -Name $regItem2
    
        if ($registryTest1) 
        {
            Fix-RegistryValue -Path $regPath1 -Name $regItem1 -RegChangeValue 0
        }

        else 
        {
            Write-Output "Registry items are missing, exiting script"
            Exit
        }

        if ($registryTest2) 
        {
            Fix-RegistryValue -Path $regPath2 -Name $regItem2 -RegChangeValue 0
        }

        else 
        {
            Write-Output "Registry items are missing, exiting script"
            Exit
        }

        # 2 - Restart Windows Update service
        try
        {
            Restart-Service -Name wuauserv -Force
        }

        catch
        {
            Write-Host -ForegroundColor Red "Failed to restart Windows Update service"
            Exit
        }

        # 3 - Install RSAT using DISM command
        try
        {            
            foreach ($feature in $features)
            {
                $currentIndex = $features.IndexOf($feature) + 1
                $shortName = $feature.Split(".")[1]
            
                Write-Host -ForegroundColor Green -NoNewline "`nInstalling $currentIndex of $featuresCount - $shortName "

                . DISM.exe /Online /Add-Capability /CapabilityName:$feature
            }
        }

        catch
        {
            Write-Host -ForegroundColor Red "Failed to install RSAT with DISM command"
        }

        # 4 - Change registry values back to the original values we captured earlier

        Fix-RegistryValue -Path $regPath1 -Name $regItem1 -RegChangeValue $regItemPropValue1      
        Fix-RegistryValue -Path $regPath2 -Name $regItem2 -RegChangeValue $regItemPropValue2  
        
        # 5 - Restart Windows Update service
        try
        {
            Restart-Service -Name wuauserv -Force
        }

        catch
        {
            Write-Host -ForegroundColor Red "Failed to restart Windows Update service"
            Exit
        } 
        
        # 6 - Run GPUpdate to set any WSUS settings back
        . gpupdate /force           
    }
}

else 
{
    Write-Host -ForegroundColor Red "You must have Windows 10 version 1809 or greater to run this installer"
}