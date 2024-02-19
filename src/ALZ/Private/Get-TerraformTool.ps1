function Get-TerraformTool {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$version = "latest",
        [Parameter(Mandatory = $false)]
        [string]$toolsPath = ".\terraform"
    )

    if($version -eq "latest") {
        $versionResponse = Invoke-WebRequest -Uri "https://checkpoint-api.hashicorp.com/v1/check/terraform"
        if($versionResponse.StatusCode -ne "200") {
            throw "Unable to query Terraform version, please check your internet connection and try again..."
        }
        $version = ($versionResponse).Content | ConvertFrom-Json | Select-Object -ExpandProperty current_version
    }

    Write-InformationColored "Required version of Terraform is $version" -ForegroundColor Green -InformationAction Continue

    $commandDetails = Get-Command -Name terraform -ErrorAction SilentlyContinue
    if($commandDetails) {
        Write-InformationColored "Terraform already installed in $($commandDetails.Path), checking version" -ForegroundColor Green -InformationAction Continue
        $installedVersion = terraform version -json | ConvertFrom-Json
        Write-InformationColored "Installed version of Terraform: $($installedVersion.terraform_version) on $($installedVersion.platform)" -ForegroundColor Green -InformationAction Continue
        if($installedVersion.terraform_version -eq $version) {
            Write-InformationColored "Installed version of Terraform matches required version $version, skipping install" -ForegroundColor Green -InformationAction Continue
            return
        }
    }

    $unzipdir = Join-Path -Path $toolsPath -ChildPath "terraform_$version"
    if (Test-Path $unzipdir) {
        Write-InformationColored "Terraform $version already installed, adding to Path." -ForegroundColor Green -InformationAction Continue
        if($os -eq "windows") {
            $env:PATH = "$($unzipdir);$env:PATH"
        } else {
            $env:PATH = "$($unzipdir):$env:PATH"
        }
        return
    }

    $osArchitecture = Get-OSArchitecture

    $zipfilePath = "$unzipdir.zip"

    $url = "https://releases.hashicorp.com/terraform/$($version)/terraform_$($version)_$($osArchitecture.osAndArchitecture).zip"

    if(!(Test-Path $toolsPath)) {
        New-Item -ItemType Directory -Path $toolsPath| Out-String | Write-Verbose
    }

    Invoke-WebRequest -Uri $url -OutFile "$zipfilePath" | Out-String | Write-Verbose

    Expand-Archive -Path $zipfilePath -DestinationPath $unzipdir

    $toolFileName = "terraform"

    if($osArchitecture.os -eq "windows") {
        $toolFileName = "$($toolFileName).exe"
    }

    $toolFilePath = Join-Path -Path $unzipdir -ChildPath $toolFileName

    if($osArchitecture.os -ne "windows") {
        $isExecutable = $(test -x $toolFilePath; 0 -eq $LASTEXITCODE)
        if(!($isExecutable)) {
            chmod +x $toolFilePath
        }
    }

    if($osArchitecture.os -eq "windows") {
        $env:PATH = "$($unzipdir);$env:PATH"
    } else {
        $env:PATH = "$($unzipdir):$env:PATH"
    }

    Remove-Item $zipfilePath
    Write-InformationColored "Installed Terraform version $version" -ForegroundColor Green -InformationAction Continue
}
