# specify the minimum required major PowerShell version that the build script should validate
[version]$script:requiredPSVersion = '5.1.0'

# specify the supported versions of ALZ-Bicep
$script:ALZBicepSupportedReleases = @('v0.14.0', 'v0.15.0', 'v0.16.0', 'v0.16.1')