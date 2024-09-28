function Get-HCLParserTool {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $false)]
        [string] $toolsPath,

        [Parameter(Mandatory = $false)]
        [string] $toolVersion
    )

    if ($PSCmdlet.ShouldProcess("Download Terraform Tools", "modify")) {
        $osArchitecture = Get-OSArchitecture

        $toolFolder = Join-Path -Path $toolsPath -ChildPath "hcl_parser_$($toolVersion)"

        if(!(Test-Path $toolFolder)) {
            New-Item -ItemType Directory -Path $toolFolder | Out-String | Write-Verbose
        }

        $toolFileName = "hcl2json_$($osArchitecture.osAndArchitecture)"

        if($osArchitecture.os -eq "windows") {
            $toolFileName = "$($toolFileName).exe"
        }

        $toolFilePath = Join-Path -Path $toolFolder -ChildPath $toolFileName

        if(!(Test-Path $toolFilePath)) {

            $uri = "https://github.com/tmccombs/hcl2json/releases/download/$($toolVersion)/$($toolFileName)"
            Write-Verbose "Downloading Terraform HCL parser Tool from $uri"
            Invoke-WebRequest -Uri $uri -OutFile "$toolFilePath" | Out-String | Write-Verbose
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
