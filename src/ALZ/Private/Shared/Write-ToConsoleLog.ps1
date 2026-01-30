function Write-ToConsoleLog {
    <#
    .SYNOPSIS
        Writes formatted log messages to the console with timestamps and log levels.

    .DESCRIPTION
        This function provides consistent console logging with timestamps, log levels, and color coding.
        It supports error, warning, success, and plan modes with appropriate coloring.
        Can also write to a file when in plan mode.

    .PARAMETER Messages
        One or more messages to write to the console.

    .PARAMETER Level
        The log level (INFO, ERROR, WARNING, SUCCESS, PLAN). Defaults to INFO.

    .PARAMETER Color
        The console color to use. Defaults to Blue for INFO, or determined by Level.

    .PARAMETER NewLine
        Adds the newline prefix before the message.

    .PARAMETER Overwrite
        Uses carriage return to overwrite the current line (for progress indicators).

    .PARAMETER IsError
        Sets the level to ERROR and uses red coloring.

    .PARAMETER IsWarning
        Sets the level to WARNING and uses yellow coloring.

    .PARAMETER IsSuccess
        Sets the level to SUCCESS and uses green coloring.

    .PARAMETER IsPlan
        Sets the level to PLAN and uses gray coloring. Also enables file writing.

    .PARAMETER WriteToFile
        Enables writing the message to a log file.

    .PARAMETER LogFilePath
        The path to the log file when WriteToFile is enabled.

    .EXAMPLE
        Write-ToConsoleLog "Starting process..."

    .EXAMPLE
        Write-ToConsoleLog "Operation completed successfully" -IsSuccess

    .EXAMPLE
        Write-ToConsoleLog "Something went wrong" -IsError
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$Messages,

        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$Color = [System.ConsoleColor]::White,

        [Parameter(Mandatory = $false)]
        [switch]$NewLine,

        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,

        [Parameter(Mandatory = $false)]
        [switch]$IsError,

        [Parameter(Mandatory = $false)]
        [switch]$IsWarning,

        [Parameter(Mandatory = $false)]
        [switch]$IsSuccess,

        [Parameter(Mandatory = $false)]
        [switch]$IsPlan,

        [Parameter(Mandatory = $false)]
        [switch]$IsPrompt,

        [Parameter(Mandatory = $false)]
        [switch]$IsSelection,

        [Parameter(Mandatory = $false)]
        [switch]$WriteToFile,

        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = $null,

        [Parameter(Mandatory = $false)]
        [switch]$ShowDateTime,

        [Parameter(Mandatory = $false)]
        [switch]$ShowType,

        [Parameter(Mandatory = $false)]
        [string]$IndentTemplate = "  ",

        [Parameter(Mandatory = $false)]
        [int]$IndentLevel = 0,

        [Parameter(Mandatory = $false)]
        [array]$Defaults = @(
            @{
                Level        = "INFO"
                Color        = [System.ConsoleColor]::Blue
                NewLine      = $false
                ShowDateTime = $true
                ShowType     = $true
                WriteToFile  = $false
            },
            @{
                Level        = "ERROR"
                Color        = [System.ConsoleColor]::Red
                NewLine      = $true
                ShowDateTime = $true
                ShowType     = $true
                WriteToFile  = $false
            },
            @{
                Level        = "WARNING"
                Color        = [System.ConsoleColor]::Yellow
                NewLine      = $true
                ShowDateTime = $true
                ShowType     = $true
                WriteToFile  = $false
            },
            @{
                Level        = "SUCCESS"
                Color        = [System.ConsoleColor]::Green
                NewLine      = $true
                ShowDateTime = $true
                ShowType     = $true
                WriteToFile  = $false
            },
            @{
                Level        = "PLAN"
                Color        = [System.ConsoleColor]::Gray
                NewLine      = $false
                ShowDateTime = $true
                ShowType     = $true
                WriteToFile  = $true
            },
            @{
                Level        = "INPUT REQUIRED"
                Color        = [System.ConsoleColor]::Magenta
                NewLine      = $true
                ShowDateTime = $true
                ShowType     = $true
                WriteToFile  = $false
            },
            @{
                Level        = "SELECTION"
                Color        = [System.ConsoleColor]::White
                NewLine      = $false
                ShowDateTime = $false
                ShowType     = $false
                WriteToFile  = $false
            }
        )
    )

    if ($IsError) {
        $Level = "ERROR"
    } elseif ($IsWarning) {
        $Level = "WARNING"
    } elseif ($IsSuccess) {
        $Level = "SUCCESS"
    } elseif ($IsPlan) {
        $Level = "PLAN"
    } elseif ($IsPrompt) {
        $Level = "INPUT REQUIRED"
    } elseif ($IsSelection) {
        $Level = "SELECTION"
    }

    $defaultSettings = $Defaults | Where-Object { $_.Level -eq $Level } | Select-Object -First 1

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"

    if ($Color -eq [System.ConsoleColor]::White) {
        if ($defaultSettings) {
            $Color = $defaultSettings.Color
        }
    }

    $prefix = ""

    if ($Overwrite) {
        $prefix = "`r"
    } else {
        if ($AddNewLine -or ($defaultSettings -and $defaultSettings.NewLine)) {
            $prefix = [System.Environment]::NewLine
        }
    }

    if ($ShowDateTime -or ($defaultSettings -and $defaultSettings.ShowDateTime)) {
        $prefix += "[$timestamp] "
    }

    if ($ShowType -or ($defaultSettings -and $defaultSettings.ShowType)) {
        $prefix += "[$Level] "
    }

    if ($IndentLevel -gt 0) {
        $indentString = $IndentTemplate * $IndentLevel
        $prefix = $indentString + $prefix
    }

    $finalMessages = @()
    foreach ($Message in $Messages) {
        $finalMessages += "$prefix$Message"
    }

    if ($finalMessages.Count -gt 1) {
        $finalMessages = $finalMessages -join "`n"
    }

    Write-Host $finalMessages -ForegroundColor $Color -NoNewline:$Overwrite.IsPresent
    if (($WriteToFile -or ($defaultSettings -and $defaultSettings.WriteToFile)) -and $LogFilePath) {
        Add-Content -Path $LogFilePath -Value $finalMessages
    }
}
