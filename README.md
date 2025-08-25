# Recursive Entra Group Member Scripts

This repository contains PowerShell scripts for recursively getting all effective users from nested Azure AD/Entra groups using Microsoft Graph PowerShell cmdlets.

## Files

- **`Get-NestedGroupMembers.ps1`** - Full-featured script with comprehensive logging, error handling, and export capabilities
- **`Get-EffectiveGroupMembers.psm1`** - Simple PowerShell module containing the core recursive function
- **`Example-Usage.ps1`** - Example script showing how to use the functions
- **`README.md`** - This documentation file

## Prerequisites

1. **Microsoft Graph PowerShell Module**
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```

2. **Required Permissions**
   - `Group.Read.All` or `Group.ReadWrite.All`
   - `User.Read.All`

3. **Authentication**
   ```powershell
   Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"
   ```

## Key Features

- **Recursive traversal** of nested group memberships
- **Circular reference protection** to prevent infinite loops
- **Depth limiting** to control recursion depth
- **Deduplication** of users found through multiple paths
- **Comprehensive logging** and error handling
- **CSV export** capabilities
- **Flexible input** - works with Group ID or Display Name

## Quick Start

### Method 1: Using the Full Script

```powershell
# By Group ID
.\Get-NestedGroupMembers.ps1 -GroupId "12345678-1234-1234-1234-123456789012"

# By Group Display Name
.\Get-NestedGroupMembers.ps1 -GroupDisplayName "All Company Users" -ExportToCsv

# With additional options
.\Get-NestedGroupMembers.ps1 -GroupId "12345678-1234-1234-1234-123456789012" -MaxDepth 15 -IncludeGroupInfo -ExportToCsv -CsvPath "C:\Reports\GroupMembers.csv"
```

### Method 2: Using the Module Function

```powershell
# Import the module
Import-Module .\Get-EffectiveGroupMembers.psm1

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"

# Clear variables (if running multiple times)
$ProcessedGroups.Clear()
$AllUsers.Clear()

# Get effective members
Get-EffectiveGroupMembers -GroupId "your-group-id-here"

# View results
Write-Host "Total effective users: $($AllUsers.Count)"
$AllUsers.Values | Select-Object DisplayName, UserPrincipalName, Mail | Sort-Object DisplayName
```

### Method 3: Using the Example Script

```powershell
# Run the example
.\Example-Usage.ps1

# Follow the prompts or directly call:
Invoke-GroupMemberExample -GroupId "your-group-id-here"
```

## Core Function Explanation

The main recursive function works by:

1. **Checking for circular references** - Prevents infinite loops by tracking processed groups
2. **Getting direct user members** - Uses `Get-MgGroupMemberAsUser` to get users
3. **Getting direct group members** - Uses `Get-MgGroupMemberAsGroup` to get nested groups
4. **Recursively processing nested groups** - Calls itself for each nested group found
5. **Deduplicating users** - Ensures each user is only counted once

```powershell
function Get-EffectiveGroupMembers {
    param(
        [string]$GroupId,
        [int]$MaxDepth = 10,
        [int]$CurrentDepth = 0
    )

    # Prevent infinite recursion and circular references
    if ($CurrentDepth -ge $MaxDepth -or $ProcessedGroups.ContainsKey($GroupId)) {
        return
    }

    $ProcessedGroups[$GroupId] = $true

    # Get direct user members
    $userMembers = Get-MgGroupMemberAsUser -GroupId $GroupId -All
    foreach ($user in $userMembers) {
        if (-not $AllUsers.ContainsKey($user.Id)) {
            $AllUsers[$user.Id] = $user
        }
    }

    # Get direct group members and recurse
    $groupMembers = Get-MgGroupMemberAsGroup -GroupId $GroupId -All
    foreach ($group in $groupMembers) {
        Get-EffectiveGroupMembers -GroupId $group.Id -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
    }
}
```

## Parameters

### Get-NestedGroupMembers.ps1 Parameters

- **`-GroupId`** - Azure AD Group Object ID
- **`-GroupDisplayName`** - Azure AD Group Display Name (alternative to GroupId)
- **`-MaxDepth`** - Maximum recursion depth (default: 10)
- **`-IncludeGroupInfo`** - Include additional group information in output
- **`-ExportToCsv`** - Export results to CSV file
- **`-CsvPath`** - Custom path for CSV export

### Get-EffectiveGroupMembers Function Parameters

- **`-GroupId`** - Azure AD Group Object ID (required)
- **`-MaxDepth`** - Maximum recursion depth (default: 10)
- **`-CurrentDepth`** - Current recursion depth (used internally)

## Output

The scripts return user objects with the following properties:

- `UserId` - Azure AD User Object ID
- `DisplayName` - User's display name
- `UserPrincipalName` - User's UPN (email)
- `Mail` - User's email address
- `JobTitle` - User's job title
- `Department` - User's department
- `CompanyName` - User's company
- `AccountEnabled` - Whether the account is enabled
- `SourceGroupId` - The group where this user was found (full script only)
- `SourceGroupName` - The group name where this user was found (full script only)
- `Depth` - The recursion depth where this user was found (full script only)

## Error Handling

The scripts include comprehensive error handling for:

- **Authentication issues** - Checks for Microsoft Graph connection
- **Permission errors** - Provides clear error messages for insufficient permissions
- **Group not found** - Handles cases where groups don't exist
- **API rate limiting** - Graceful handling of Graph API limits
- **Circular references** - Prevention and detection of infinite loops

## Performance Considerations

- **Large groups** may take significant time to process
- **API rate limiting** may slow down processing for very large nested structures
- **Memory usage** increases with the number of unique users found
- Consider using **`-MaxDepth`** parameter to limit recursion for very deep nesting

## Troubleshooting

### Common Issues

1. **"Not connected to Microsoft Graph"**
   ```powershell
   Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"
   ```

2. **"Insufficient privileges"**
   - Ensure you have the required permissions
   - Contact your Azure AD administrator

3. **"Group not found"**
   - Verify the Group ID or Display Name
   - Ensure you have permission to read the group

4. **Slow performance**
   - Reduce `MaxDepth` parameter
   - Consider processing smaller groups first

### Debugging

Enable verbose output for detailed logging:

```powershell
$VerbosePreference = "Continue"
Get-EffectiveGroupMembers -GroupId "your-group-id" -Verbose
```

## License

This code is provided as-is for educational and practical use. Feel free to modify and adapt for your specific needs.
