# Used to allow mocking of the $PSVersionTable variable
function Get-PSVersion { $PSVersionTable }

#Unable to mock $PSScriptRoot variable
function Get-ScriptRoot { $PSScriptRoot }