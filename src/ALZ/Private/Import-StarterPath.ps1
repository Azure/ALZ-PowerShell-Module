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

    $bootstrapStarterPathObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Name -eq "module_folder_path" }
    if($null -ne $bootstrapStarterPathObject) {
        $bootstrapStarterPathObject.Value.Value = $starterPath
    }

    $bootstrapPipelinePathObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Name -eq "pipeline_folder_path" }
    if($null -ne $bootstrapPipelinePathObject) {
        $bootstrapPipelinePathObject.Value.Value = $starterPipelinePath
    }

    $bootstrapStarterPathRelativeObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Name -eq "module_folder_path_relative" }
    if($null -ne $bootstrapStarterPathRelativeObject) {
        $bootstrapStarterPathRelativeObject.Value.Value = "false"
    }

    $bootstrapPipelinePathRelativeObject = $bootstrapConfiguration.PsObject.Properties | Where-Object { $_.Name -eq "pipeline_folder_path_relative" }
    if($null -ne $bootstrapPipelinePathRelativeObject) {
        $bootstrapPipelinePathRelativeObject.Value.Value = "false"
    }
}
