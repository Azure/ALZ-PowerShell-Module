function Get-HCLParserTool {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $alzEnvironmentDestination,

        [Parameter(Mandatory = $false)]
        [string] $toolVersion
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {
        $os = ""
        if ($IsWindows) {
            $os = "windows"
        }
        if($IsLinux) {
            $os = "linux"
        }
        if($IsMacOS) {
            $os = "darwin"
        }

        $architecture = $($env:PROCESSOR_ARCHITECTURE).ToLower()
        $toolFileName = "hcl2json_$($os)_$($architecture)"

        if($os -eq "windows") {
            $toolFileName = "$($toolFileName).exe"
        }

        $toolFilePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $toolFileName

        if(!(Test-Path $toolFilePath)) {
            Invoke-WebRequest -Uri "https://github.com/tmccombs/hcl2json/releases/download/$($toolVersion)/$($toolFileName)" -OutFile "$toolFilePath" | Out-String | Write-Verbose
        }
    }

    return $toolFilePath
}