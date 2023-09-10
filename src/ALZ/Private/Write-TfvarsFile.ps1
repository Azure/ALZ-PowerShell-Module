function Write-TfvarsFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $tfvarsFilePath,

        [Parameter(Mandatory = $false)]
        [PSObject] $configuration
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {

        if(Test-Path $tfvarsFilePath) {
            Remove-Item -Path $tfvarsFilePath
        }

        foreach($configurationProperty in $configuration.PSObject.Properties) {
            Add-Content -Path $tfvarsFilePath -Value "$($configurationProperty.Name) = `"$($configurationProperty.Value.Value)`""
        }

        $tfvarsFolderPath = Split-Path -Path $tfvarsFilePath -Parent

        terraform -chdir="$tfvarsFolderPath" fmt | Out-String | Write-Verbose
    }
}