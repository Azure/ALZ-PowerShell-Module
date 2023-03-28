param(
    [string]$version,
    [string]$prerelease
)

New-Item "ALZ" -ItemType Directory -Force
Copy-Item -Path "./src/Artifacts/Assets" -Destination "./ALZ/" -Recurse -Force
Copy-Item -Path "./src/Artifacts/Private" -Destination "./ALZ/" -Recurse -Force
Copy-Item -Path "./src/Artifacts/Public" -Destination "./ALZ/" -Recurse -Force
Copy-Item -Path "./src/Artifacts/ALZ.psd1" -Destination "./ALZ/" -Force
Copy-Item -Path "./src/Artifacts/ALZ.psm1" -Destination "./ALZ/" -Force

Update-ModuleManifest -Path "./ALZ/ALZ.psd1" -ModuleVersion $version -Prerelease $prerelease
