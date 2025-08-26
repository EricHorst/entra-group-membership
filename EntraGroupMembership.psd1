@{
    # Module metadata
    RootModule = 'EntraGroupMembership.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author and company information
    Author = 'Consolidated Implementation'
    CompanyName = 'Enterprise Solutions'
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'Enterprise-grade PowerShell module for recursively enumerating Entra (Azure AD) group memberships with enhanced error handling, retry logic, and comprehensive reporting.'

    # Minimum PowerShell version
    PowerShellVersion = '5.1'

    # Required modules
    RequiredModules = @(
        @{
            ModuleName = 'Microsoft.Graph.Groups'
            ModuleVersion = '1.0.0'
        },
        @{
            ModuleName = 'Microsoft.Graph.Users'
            ModuleVersion = '1.0.0'
        },
        @{
            ModuleName = 'Microsoft.Graph.Authentication'
            ModuleVersion = '1.0.0'
        }
    )

    # Functions to export
    FunctionsToExport = @(
        'Get-EntraGroupMembers',
        'Export-EntraGroupMembers'
    )

    # Variables to export (none - using module-scoped variables)
    VariablesToExport = @()

    # Aliases to export
    AliasesToExport = @()

    # Cmdlets to export (none)
    CmdletsToExport = @()

    # Private data
    PrivateData = @{
        PSData = @{
            # Tags for PowerShell Gallery
            Tags = @(
                'Azure',
                'AzureAD',
                'Entra',
                'Groups',
                'Membership',
                'MicrosoftGraph',
                'Enterprise',
                'Security'
            )

            # License and project URLs
            LicenseUri = 'https://github.com/EricHorst/entra-group-membership/blob/main/LICENSE'
            ProjectUri = 'https://github.com/EricHorst/entra-group-membership'

            # Release notes
            ReleaseNotes = @'
Enterprise-grade PowerShell module for Entra (Azure AD) group membership analysis.

Key Features:
- Unified module architecture with consistent API usage
- Enterprise-grade retry logic for Graph API failures
- Enhanced error handling with comprehensive reporting
- Progress reporting for long-running operations
- Multiple export formats (CSV, JSON, HTML)
- Detailed processing statistics and metrics
- Proper variable scoping and state management
- Enhanced validation and parameter sets
- Comprehensive documentation and examples

Functions:
- Get-EntraGroupMembers: Main function for recursive group analysis
- Export-EntraGroupMembers: Export results in multiple formats

Requirements:
- Microsoft Graph PowerShell modules
- Appropriate Graph API permissions (Group.Read.All, User.Read.All)
'@
        }
    }

    # Help Info URI
    HelpInfoURI = 'https://github.com/EricHorst/entra-group-membership/blob/main/docs/'
}
