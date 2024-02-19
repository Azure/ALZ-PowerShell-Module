function Import-StarterPath {
    <#

    #>
    param(
        [Parameter(Mandatory = $false)]
        [string] $starterPath,
        [Parameter(Mandatory = $false)]
        [string] $starterPipelinePath,
        [Parameter(Mandatory = $false)]
        [PSCustomObject] $bootstrapConfiguration
    )

    $bootstrapStarterPathObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Value.Name -eq "module_folder_path" }
    $bootstrapStarterPathObject.Value.Value = $starterPath

    $bootstrapPipelinePathObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Value.Name -eq "pipeline_folder_path" }
    $bootstrapPipelinePathObject.Value.Value = $starterPipelinePath


    $bootstrapStarterPathRelativeObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Value.Name -eq "module_folder_path_relative" }
    $bootstrapStarterPathRelativeObject.Value.Value = "false"

    $bootstrapPipelinePathRelativeObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Value.Name -eq "pipeline_folder_path_relative" }
    $bootstrapPipelinePathRelativeObject.Value.Value = "false"
}
