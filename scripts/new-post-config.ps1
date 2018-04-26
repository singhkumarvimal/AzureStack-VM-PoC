Param (
    [Parameter(Mandatory=$true)]
    [string]
    $Username
    )

function DownloadWithRetry([string] $Uri, [string] $DownloadLocation, [int] $Retries = 5, [int]$RetryInterval = 10)
{
    while($true)
    {
        try
        {
            Start-BitsTransfer -Source $Uri -Destination $DownloadLocation -DisplayName $Uri
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Write-Host "Failed to download '$Uri': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Write-Host "Waiting $RetryInterval seconds before retrying. Retries left: $Retries"
                Clear-DnsClientCache
                Start-Sleep -Seconds $RetryInterval
 
            }
            else
            {
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}

$defaultLocalPath = "C:\AzureStackOnAzureVM"
New-Item -Path $defaultLocalPath -ItemType Directory -Force

DownloadWithRetry -Uri "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/development/config.ind" -DownloadLocation "$defaultLocalPath\config.ind"
$gitbranchconfig = Import-Csv -Path $defaultLocalPath\config.ind -Delimiter ","
$gitbranchcode = $gitbranchconfig.branch.Trim()
$gitbranch = "https://raw.githubusercontent.com/yagmurs/AzureStack-VM-PoC/$gitbranchcode"

DownloadWithRetry -Uri "$gitbranch/scripts/ASDKHelperModule.psm1" -DownloadLocation "$defaultLocalPath\ASDKHelperModule.psm1"

if (Test-Path "$defaultLocalPath\ASDKHelperModule.psm1")
{
    Import-Module "$defaultLocalPath\ASDKHelperModule.psm1"
}
else
{
    throw "required module $defaultLocalPath\ASDKHelperModule.psm1 not found"   
}

Set-ExecutionPolicy unrestricted -Force

#Disables Internet Explorer Enhanced Security Configuration
Disable-InternetExplorerESC

#Download Install-ASDK.ps1 (installer)
DownloadWithRetry -Uri "$gitbranch/scripts/Install-ASDK.ps1" -DownloadLocation "$defaultLocalPath\new-Install-ASDK.ps1"
#Invoke-WebRequest -Uri "$gitbranch/scripts/Install-ASDK.ps1" -OutFile "$defaultLocalPath\Install-ASDK.ps1"

#Download Azure Stack Development Kit Companion Service script
DownloadWithRetry -Uri "$gitbranch/scripts/ASDKCompanionService.ps1" -DownloadLocation "$defaultLocalPath\ASDKCompanionService.ps1"

#Download and extract Mobaxterm
DownloadWithRetry -Uri "https://aka.ms/mobaxtermLatest" -DownloadLocation "$defaultLocalPath\Mobaxterm.zip"
#Invoke-WebRequest -Uri "https://aka.ms/mobaxtermLatest" -OutFile "$defaultLocalPath\Mobaxterm.zip"
Expand-Archive -Path "$defaultLocalPath\Mobaxterm.zip" -DestinationPath "$defaultLocalPath\Mobaxterm"
Remove-Item -Path "$defaultLocalPath\Mobaxterm.zip" -Force

#Creating desktop shortcut for Install-ASDK.ps1
New-Item -ItemType SymbolicLink -Path ($env:ALLUSERSPROFILE + "\Desktop") -Name "Install-ASDK" -Value "$defaultLocalPath\new-Install-ASDK.ps1"

$size = Get-Volume -DriveLetter c | Get-PartitionSupportedSize
Resize-Partition -DriveLetter c -Size $size.sizemax

Rename-LocalUser -Name $username -NewName Administrator

Set-Location C:\CloudDeployment\Setup
.\BootstrapAzureStackDeployment.ps1

$baremetalFilePath = "C:\CloudDeployment\Roles\PhysicalMachines\Tests\BareMetal.Tests.ps1"
$baremetalFile = Get-Content -Path $baremetalFilePath
$baremetalFile = $baremetalFile.Replace('$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'')','$isVirtualizedDeployment = ($Parameters.OEMModel -eq ''Hyper-V'') -or $isOneNode') 
Set-Content -Value $baremetalFile -Path $baremetalFilePath -Force 

$HelpersFilePath = "C:\CloudDeployment\Common\Helpers.psm1" 
$HelpersFile = Get-Content -Path $HelpersFilePath
$HelpersFile = $HelpersFile.Replace('C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease','C:\tools\NuGet.exe install $NugetName -Source $NugetStorePath -OutputDirectory $DestinationPath -packagesavemode "nuspec" -Prerelease -ExcludeVersion') 
#Set-Content -Value $HelpersFile -Path $HelpersFilePath -Force