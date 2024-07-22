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

        $jsonObject = @{}

        foreach($configurationProperty in $configuration.PSObject.Properties) {
            $configurationValue = $configurationProperty.Value.Value

            if($configurationProperty.Value.Validator -eq "configuration_file_path") {
                $configurationValue = [System.IO.Path]::GetFileName($configurationValue)
            }

            if($configurationProperty.Value.DataType -eq "list(string)" -and !($configurationValue -is [array])) {
                $configurationValue = $configurationValue -split ","
            }

            if($configurationProperty.Value.DataType -eq "number") {
                $configurationValue = [int]($configurationValue)
            }

            if($configurationProperty.Value.DataType -eq "bool") {
                $configurationValue = [bool]($configurationValue)
            }

            $jsonObject["$($configurationProperty.Name)"] = $configurationValue
        }

        $jsonString = ConvertTo-Json $jsonObject

        $jsonString | Out-File $tfvarsFilePath
    }
}