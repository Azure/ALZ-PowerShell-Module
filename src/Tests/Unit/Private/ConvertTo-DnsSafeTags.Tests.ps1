Describe "ConvertTo-DnsSafeTags" {
    BeforeAll {
        # Directly source the function file
        . "$PSScriptRoot/../../../ALZ/Private/Config-Helpers/ConvertTo-DnsSafeTags.ps1"
    }

    Context "When converting hashtable tags" {
        It "Should remove spaces from tag keys" {
            $tags = @{
                "Business Application" = "ALZ"
                "Owner" = "Platform"
            }
            
            $result = ConvertTo-DnsSafeTags -tags $tags
            
            $result.Keys | Should -Contain "BusinessApplication"
            $result.Keys | Should -Contain "Owner"
            $result.Keys | Should -Not -Contain "Business Application"
            $result["BusinessApplication"] | Should -Be "ALZ"
            $result["Owner"] | Should -Be "Platform"
        }

        It "Should remove parentheses from tag keys" {
            $tags = @{
                "Business Unit (Primary)" = "IT"
                "Cost Center (Backup)" = "12345"
            }
            
            $result = ConvertTo-DnsSafeTags -tags $tags
            
            $result.Keys | Should -Contain "BusinessUnitPrimary"
            $result.Keys | Should -Contain "CostCenterBackup"
            $result["BusinessUnitPrimary"] | Should -Be "IT"
            $result["CostCenterBackup"] | Should -Be "12345"
        }

        It "Should prefix tag keys that start with a number" {
            $tags = @{
                "1stTag" = "value1"
                "2ndTag" = "value2"
            }
            
            $result = ConvertTo-DnsSafeTags -tags $tags
            
            $result.Keys | Should -Contain "_1stTag"
            $result.Keys | Should -Contain "_2ndTag"
            $result["_1stTag"] | Should -Be "value1"
            $result["_2ndTag"] | Should -Be "value2"
        }

        It "Should handle tags with multiple spaces and special characters" {
            $tags = @{
                "Business  Application  (Main)" = "ALZ"
                "  Owner  " = "Platform"
            }
            
            $result = ConvertTo-DnsSafeTags -tags $tags
            
            $result.Keys | Should -Contain "BusinessApplicationMain"
            $result.Keys | Should -Contain "Owner"
            $result["BusinessApplicationMain"] | Should -Be "ALZ"
            $result["Owner"] | Should -Be "Platform"
        }

        It "Should return null for null input" {
            $result = ConvertTo-DnsSafeTags -tags $null
            $result | Should -Be $null
        }

        It "Should handle empty hashtable" {
            $tags = @{}
            $result = ConvertTo-DnsSafeTags -tags $tags
            $result.Count | Should -Be 0
        }
    }

    Context "When converting PSCustomObject tags" {
        It "Should remove spaces from tag keys in PSCustomObject" {
            $tags = [PSCustomObject]@{
                "Business Application" = "ALZ"
                "Owner" = "Platform"
            }
            
            $result = ConvertTo-DnsSafeTags -tags $tags
            
            $result.Keys | Should -Contain "BusinessApplication"
            $result.Keys | Should -Contain "Owner"
            $result["BusinessApplication"] | Should -Be "ALZ"
            $result["Owner"] | Should -Be "Platform"
        }

        It "Should handle PSCustomObject with special characters" {
            $tags = [PSCustomObject]@{
                "Business Unit (Test)" = "IT"
                "1stTag" = "value"
            }
            
            $result = ConvertTo-DnsSafeTags -tags $tags
            
            $result.Keys | Should -Contain "BusinessUnitTest"
            $result.Keys | Should -Contain "_1stTag"
            $result["BusinessUnitTest"] | Should -Be "IT"
            $result["_1stTag"] | Should -Be "value"
        }
    }

    Context "When handling edge cases" {
        It "Should skip tags that result in empty keys" {
            $tags = @{
                "   " = "value"
                "Owner" = "Platform"
            }
            
            # Should issue a warning but not fail
            $result = ConvertTo-DnsSafeTags -tags $tags -WarningAction SilentlyContinue
            
            $result.Keys | Should -Contain "Owner"
            $result.Keys | Should -Not -Contain "   "
            $result.Keys | Should -Not -Contain ""
            $result.Count | Should -Be 1
        }

        It "Should handle tags with only spaces and parentheses" {
            $tags = @{
                "( )" = "value"
                "Owner" = "Platform"
            }
            
            $result = ConvertTo-DnsSafeTags -tags $tags -WarningAction SilentlyContinue
            
            $result.Keys | Should -Contain "Owner"
            $result.Count | Should -Be 1
        }
    }
}
