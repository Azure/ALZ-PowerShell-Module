# Used to allow mocking of the $PSVersionTable variable
function Get-PSVersion { $PSVersionTable }

#Unable to mock $PSScriptRoot variable
function Get-ScriptRoot { $PSScriptRoot }

# Used to allow mocking of the Get-Module AZ
function Get-AZVersion { Get-Module -Name Az -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1 }
