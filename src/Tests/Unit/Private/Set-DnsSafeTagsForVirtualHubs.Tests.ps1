Describe "Set-DnsSafeTagsForVirtualHubs" {
    BeforeAll {
        # Directly source the function files
        . "$PSScriptRoot/../../../ALZ/Private/Config-Helpers/ConvertTo-DnsSafeTags.ps1"
        . "$PSScriptRoot/../../../ALZ/Private/Config-Helpers/Set-DnsSafeTagsForVirtualHubs.ps1"
    }

    Context "When processing virtual_hubs with DNS zone tags" {
        It "Should sanitize existing DNS zone tags" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        tags = @{
                            "Business Application" = "ALZ"
                            "Owner" = "Platform"
                        }
                    }
                }
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs
            
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "BusinessApplication"
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "Owner"
            $result.primary.private_dns_zones.tags.Keys | Should -Not -Contain "Business Application"
        }

        It "Should apply connectivity tags as fallback when DNS zone has no tags" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        resource_group_name = "dns-rg"
                    }
                }
            }
            
            $connectivityTags = @{
                "Business Application" = "ALZ"
                "Business Unit" = "IT"
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs -connectivityTags $connectivityTags
            
            $result.primary.private_dns_zones.tags | Should -Not -BeNullOrEmpty
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "BusinessApplication"
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "BusinessUnit"
            $result.primary.private_dns_zones.tags["BusinessApplication"] | Should -Be "ALZ"
            $result.primary.private_dns_zones.tags["BusinessUnit"] | Should -Be "IT"
        }

        It "Should apply overall tags as fallback when no DNS or connectivity tags exist" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        resource_group_name = "dns-rg"
                    }
                }
            }
            
            $overallTags = @{
                "Deployment Type" = "Terraform"
                "Environment" = "Production"
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs -overallTags $overallTags
            
            $result.primary.private_dns_zones.tags | Should -Not -BeNullOrEmpty
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "DeploymentType"
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "Environment"
            $result.primary.private_dns_zones.tags["DeploymentType"] | Should -Be "Terraform"
        }

        It "Should prefer DNS zone tags over connectivity tags" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        tags = @{
                            "Owner" = "DNS Team"
                        }
                    }
                }
            }
            
            $connectivityTags = @{
                "Owner" = "Connectivity Team"
                "Business Unit" = "IT"
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs -connectivityTags $connectivityTags
            
            $result.primary.private_dns_zones.tags["Owner"] | Should -Be "DNS Team"
            $result.primary.private_dns_zones.tags.Keys | Should -Not -Contain "BusinessUnit"
        }

        It "Should prefer connectivity tags over overall tags" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        resource_group_name = "dns-rg"
                    }
                }
            }
            
            $connectivityTags = @{
                "Business Unit" = "Connectivity"
            }
            
            $overallTags = @{
                "Business Unit" = "Overall"
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs -connectivityTags $connectivityTags -overallTags $overallTags
            
            $result.primary.private_dns_zones.tags["BusinessUnit"] | Should -Be "Connectivity"
        }

        It "Should handle multiple virtual hubs" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        tags = @{
                            "Environment" = "Primary"
                        }
                    }
                }
                secondary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        tags = @{
                            "Environment" = "Secondary"
                        }
                    }
                }
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs
            
            $result.primary.private_dns_zones.tags["Environment"] | Should -Be "Primary"
            $result.secondary.private_dns_zones.tags["Environment"] | Should -Be "Secondary"
        }

        It "Should handle virtual hubs without private_dns_zones" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    location = "eastus"
                }
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs
            
            $result.primary.location | Should -Be "eastus"
            $result.primary.PSObject.Properties.Name | Should -Not -Contain "private_dns_zones"
        }

        It "Should return null for null input" {
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $null
            $result | Should -Be $null
        }

        It "Should not apply fallback tags if no fallback tags are provided" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        resource_group_name = "dns-rg"
                    }
                }
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs
            
            $result.primary.private_dns_zones.PSObject.Properties.Name | Should -Not -Contain "tags"
        }
    }

    Context "When handling complex tag sanitization scenarios" {
        It "Should sanitize connectivity fallback tags with spaces and parentheses" {
            $virtualHubs = [PSCustomObject]@{
                primary = [PSCustomObject]@{
                    private_dns_zones = [PSCustomObject]@{
                        resource_group_name = "dns-rg"
                    }
                }
            }
            
            $connectivityTags = @{
                "Business Application (Main)" = "ALZ"
                "Business  Criticality" = "High"
                "1stPriority" = "DNS"
            }
            
            $result = Set-DnsSafeTagsForVirtualHubs -virtualHubs $virtualHubs -connectivityTags $connectivityTags
            
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "BusinessApplicationMain"
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "BusinessCriticality"
            $result.primary.private_dns_zones.tags.Keys | Should -Contain "_1stPriority"
            $result.primary.private_dns_zones.tags["BusinessApplicationMain"] | Should -Be "ALZ"
            $result.primary.private_dns_zones.tags["BusinessCriticality"] | Should -Be "High"
            $result.primary.private_dns_zones.tags["_1stPriority"] | Should -Be "DNS"
        }
    }
}
