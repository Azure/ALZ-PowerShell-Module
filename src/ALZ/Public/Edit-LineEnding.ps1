enum LineEndingTypes {
    Darwin
    Unix
    Win
}

function Edit-LineEnding {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([String[]])]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [String[]]$InputText,
        [Parameter()][LineEndingTypes]$LineEnding = "Unix"
    )

    Begin {

        Switch ("$LineEnding".ToLower()) {
            "darwin" { $eol = "`r" }
            "unix" { $eol = "`n" }
            "win" { $eol = "`r`n" }
        }

    }

    Process {

        [String[]]$outputText += $InputText |
            ForEach-Object { $_ -replace "`r`n", "`n" } |
            ForEach-Object { $_ -replace "`r", "`n" } |
            ForEach-Object { $_ -replace "`n", "$eol" }

    }

    End {

        return $outputText

    }

}

New-Alias -Name "Edit-LineEndings" -Value "Edit-LineEnding"