function Get-HCLParserTool {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $false)]
        [string] $toolVersion
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {
        $osArchitecture = Get-OSArchitecture

        $toolFileName = "hcl2json_$($osArchitecture.osAndArchitecture)"

        if($osArchitecture.os -eq "windows") {
            $toolFileName = "$($toolFileName).exe"
        }

        $toolFilePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $toolFileName

        if(!(Test-Path $toolFilePath)) {
            Invoke-WebRequest -Uri "https://github.com/tmccombs/hcl2json/releases/download/$($toolVersion)/$($toolFileName)" -OutFile "$toolFilePath" | Out-String | Write-Verbose
        }

        if($osArchitecture.os -ne "windows") {
            $isExecutable = $(test -x $toolFilePath; 0 -eq $LASTEXITCODE)
            if(!($isExecutable)) {
                chmod +x $toolFilePath
            }
        }
    }

    return $toolFilePath
}
