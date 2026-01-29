function Invoke-PromptForConfirmation {
    <#
    .SYNOPSIS
        Prompts the user for a two-stage confirmation before destructive operations.

    .DESCRIPTION
        This function implements a two-stage confirmation process for destructive operations.
        First, it generates a random 6-character string that the user must type to confirm.
        Then, it requires the user to type a final confirmation text (default: "CONFIRM").
        This helps prevent accidental execution of dangerous operations.

    .PARAMETER Message
        The warning message to display explaining what will happen.

    .PARAMETER FinalConfirmationText
        The text the user must type for final confirmation. Defaults to "CONFIRM".

    .OUTPUTS
        [bool] Returns $true if both confirmations pass, $false otherwise.

    .EXAMPLE
        $continue = Invoke-PromptForConfirmation -Message "ALL DATA WILL BE DELETED"
        if (-not $continue) { return }

    .EXAMPLE
        $continue = Invoke-PromptForConfirmation -Message "RESOURCES WILL BE DESTROYED" -FinalConfirmationText "DELETE"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$FinalConfirmationText = "CONFIRM"
    )

    Write-ToConsoleLog "$Message" -IsWarning
    $randomString = (Get-RandomString -Length 6).ToUpper()
    Write-ToConsoleLog "If you wish to proceed, type '$randomString' to confirm." -IsPrompt
    $confirmation = Read-Host "Enter the confirmation text"
    $confirmation = $confirmation.ToUpper().Replace("'","").Replace([System.Environment]::NewLine, "").Trim()
    if ($confirmation -ne $randomString.ToUpper()) {
        Write-ToConsoleLog "Confirmation text did not match the required input. Exiting without making any changes." -IsError
        return $false
    }
    Write-ToConsoleLog "Initial confirmation received." -IsSuccess
    Write-ToConsoleLog "This operation is permanent and cannot be reversed!" -IsWarning
    Write-ToConsoleLog "Are you sure you want to proceed? Type '$FinalConfirmationText' to perform the highly destructive operation..." -IsPrompt
    $confirmation = Read-Host "Enter the final confirmation text"
    $confirmation = $confirmation.ToUpper().Replace("'","").Replace([System.Environment]::NewLine, "").Trim()
    if ($confirmation -ne $FinalConfirmationText.ToUpper()) {
        Write-ToConsoleLog "Final confirmation did not match the required input. Exiting without making any changes." -IsError
        return $false
    }
    Write-ToConsoleLog "Final confirmation received. Proceeding with destructive operation..." -IsSuccess
    return $true
}
