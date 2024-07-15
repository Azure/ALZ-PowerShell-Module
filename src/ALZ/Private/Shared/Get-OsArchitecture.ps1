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
        exit 1
    }

    return @{
        os                = $os
        architecture      = $architecture
        osAndArchitecture = $osAndArchitecture
    }
}
