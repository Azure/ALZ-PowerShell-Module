function Get-OSArchitecture {
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

    # Enum values can be seen here: https://learn.microsoft.com/en-us/dotnet/api/system.runtime.interopservices.architecture?view=net-7.0#fields
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
        "windows_amd64",
        "windows_arm64"
    )

    if($supportedOsAndArchitectures -notcontains $osAndArchitecture) {
        Write-Error "Unsupported OS and architecture combination: $osAndArchitecture"
        return
    }

    if($osAndArchitecture -eq "windows_arm64") {
        Write-InformationColored "Windows arm64 is not currently supported by Terraform, so we will pull the Windows amd64 verison instead and run in emulation mode: https://learn.microsoft.com/en-us/windows/arm/apps-on-arm-x86-emulation" -ForegroundColor Yellow -NewLineBefore -InformationAction Continue
        $architecture = "amd64"
        $osAndArchitecture = "windows_amd64"
    }

    return @{
        os                = $os
        architecture      = $architecture
        osAndArchitecture = $osAndArchitecture
    }
}
