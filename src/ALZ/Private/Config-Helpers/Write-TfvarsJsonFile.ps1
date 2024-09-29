function Write-TfvarsJsonFile {
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

        $jsonObject = [ordered]@{}

        foreach($configurationProperty in $configuration.PSObject.Properties | Sort-Object Name) {
            $configurationValue = $configurationProperty.Value.Value

            if($configurationValue -eq "sourced-from-env") {
                continue
            }

            if($configurationProperty.Value.Validator -eq "configuration_file_path") {
                $configurationValue = [System.IO.Path]::GetFileName($configurationValue)
            }

            $jsonObject["$($configurationProperty.Name)"] = $configurationValue
        }

        $jsonString = ConvertTo-Json $jsonObject -Depth 100
        $jsonString | Out-File $tfvarsFilePath
    }
}