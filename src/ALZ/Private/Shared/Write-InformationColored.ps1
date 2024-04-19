function Write-InformationColored {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Object]$MessageData,
        [ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor,
        [ConsoleColor]$BackgroundColor = $Host.UI.RawUI.BackgroundColor,
        [Switch]$NoNewline,
        [Switch]$NewLineBefore
    )

    if($NewLineBefore) {
        $MessageData = "$([Environment]::NewLine)$MessageData"
    }

    $msg = [System.Management.Automation.HostInformationMessage]@{
        Message         = $MessageData
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        NoNewline       = $NoNewline.IsPresent
    }

    Write-Information $msg
}
