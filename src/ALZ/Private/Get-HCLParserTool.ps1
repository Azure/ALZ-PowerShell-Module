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
            $architecture = $($env:PROCESSOR_ARCHITECTURE).ToLower()
        }
        if($IsLinux) {
            $os = "linux"
        }
        if($IsMacOS) {
            $os = "darwin"
        }

        $architecture = ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture).ToString().ToLower()

        if($architecture -eq "x64") {
            $architecture = "amd64"
        }
        if($architecture -eq "x86") {
            $architecture = "386"
        }

        $osAndArchitecture = "$($os)_$($architecture)"

        $supportedOsAndArchitectures = @(
            "darwin_amd64",
            "darwin_arm64",
            "linux_386",
            "linux_amd64",
            "linux_arm64",
            "windows_386",
            "windows_amd64"
        )

        if($supportedOsAndArchitectures -notcontains $osAndArchitecture) {
            Write-Error "Unsupported OS and architecture combination: $osAndArchitecture"
            exit 1
        }

        $toolFileName = "hcl2json_$osAndArchitecture"

        if($os -eq "windows") {
            $toolFileName = "$($toolFileName).exe"
        }

        $toolFilePath = Join-Path -Path $alzEnvironmentDestination -ChildPath $toolFileName

        if(!(Test-Path $toolFilePath)) {
            Invoke-WebRequest -Uri "https://github.com/tmccombs/hcl2json/releases/download/$($toolVersion)/$($toolFileName)" -OutFile "$toolFilePath" | Out-String | Write-Verbose
        }

        if($os -ne "windows") {
            $isExecutable = $(test -x $toolFilePath; 0 -eq $LASTEXITCODE)
            if(!($isExecutable)) {
                chmod +x $toolFilePath
            }
        }
    }

    return $toolFilePath
}