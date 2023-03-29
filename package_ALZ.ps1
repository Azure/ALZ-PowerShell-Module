param(
    [string]$version,
    [string]$prerelease = ""
)

New-Item "ALZ" -ItemType Directory -Force
Copy-Item -Path "./src/Artifacts/*" -Destination "./ALZ" -Recurse -Exclude "ccReport", "testOutput"  -Force

Update-ModuleManifest -Path "./ALZ/ALZ.psd1" -ModuleVersion $version -Prerelease $prerelease

