# Enterprise Entra Group Membership Module

A unified, enterprise-grade PowerShell module for recursively analyzing Entra (Azure AD) group memberships with enhanced reliability, performance, and reporting capabilities.

## 🚀 Key Features

- **✅ Unified Architecture** - Single, robust module with consistent API usage
- **✅ Enterprise-Grade Retry Logic** - Automatic handling of transient Graph API failures with exponential backoff
- **✅ Enhanced Error Handling** - Comprehensive error tracking and reporting
- **✅ Progress Reporting** - Real-time progress updates for long-running operations
- **✅ Multiple Export Formats** - CSV, JSON, and HTML report generation
- **✅ Detailed Statistics** - Processing metrics, timing, and API usage tracking
- **✅ Proper Variable Scoping** - Clean module design with no global variable pollution

## Files

- **`EntraGroupMembership.psm1`** - Main enterprise-grade module ⭐
- **`EntraGroupMembership.psd1`** - Module manifest with metadata
- **`Examples.ps1`** - Comprehensive usage examples and interactive demo

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
   ```powershell
   Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"
   ```

## Core Capabilities

- **Recursive traversal** of nested group memberships
- **Circular reference protection** to prevent infinite loops
- **Depth limiting** to control recursion depth
- **Deduplication** of users found through multiple paths

## Key Features

- **Recursive traversal** of nested group memberships
- **Circular reference protection** to prevent infinite loops
- **Depth limiting** to control recursion depth
- **Deduplication** of users found through multiple paths
- **Comprehensive logging** and error handling
- **CSV export** capabilities
- **Flexible input** - works with Group ID or Display Name

## Quick Start (v2.0)

### Import the Module
```powershell
# Import the unified module
Import-Module .\EntraGroupMembership.psm1

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"
```

### Basic Usage
```powershell
# Get group members by ID
$result = Get-EntraGroupMembers -GroupId "12345678-1234-1234-1234-123456789012"

# View results
Write-Host "Found $($result.Statistics.TotalUsers) users in $($result.Statistics.TotalGroups) groups"
$result.Users | Select-Object DisplayName, UserPrincipalName, Department | Format-Table

# Export to CSV
Export-EntraGroupMembers -InputObject $result -OutputPath "GroupMembers.csv" -IncludeStatistics
```

### Advanced Usage
```powershell
# Get group members by name with comprehensive options
$result = Get-EntraGroupMembers -GroupDisplayName "All Company Users" `
                                -MaxDepth 15 `
                                -IncludeDisabledUsers `
                                -IncludeGroupInfo

# Export to multiple formats
Export-EntraGroupMembers -InputObject $result -OutputPath "report.csv" -IncludeStatistics
Export-EntraGroupMembers -InputObject $result -OutputPath "report.json" -IncludeStatistics
Export-EntraGroupMembers -InputObject $result -OutputPath "report.html" -IncludeStatistics
```

### Interactive Demo
```powershell
# Run the interactive demonstration
.\Examples.ps1
# Then call: Start-InteractiveDemo
```

## Core Function Explanation

The unified module works by:

1. **Validating Graph Connection** - Ensures proper authentication and permissions
2. **Initializing Module State** - Sets up internal tracking with proper scoping
3. **Retry Logic Implementation** - Handles transient API failures automatically
4. **Type-Specific API Calls** - Uses `Get-MgGroupMemberAsUser` and `Get-MgGroupMemberAsGroup` consistently
5. **Circular Reference Protection** - Prevents infinite loops with robust tracking
6. **Progress Reporting** - Provides real-time updates for long operations
7. **Comprehensive Result Object** - Returns structured data with statistics and metadata

```powershell
function Get-EntraGroupMembers {
    param(
        [string]$GroupId,
        [string]$GroupDisplayName,
        [int]$MaxDepth = 10,
        [switch]$IncludeDisabledUsers,
        [switch]$IncludeGroupInfo
    )

    # Returns structured object:
    # - Users: Array of user objects with detailed properties
    # - Statistics: Processing metrics (timing, API calls, etc.)
    # - ProcessedGroups: Group hierarchy information
    # - Errors: Any errors encountered during processing
}
```

## Parameters### Get-EntraGroupMembers Parameters

- **`-GroupId`** - Azure AD Group Object ID (GUID format, validated)
- **`-GroupDisplayName`** - Azure AD Group Display Name (alternative to GroupId)
- **`-MaxDepth`** - Maximum recursion depth (default: 10, range: 1-50)
- **`-IncludeDisabledUsers`** - Include disabled user accounts in results
- **`-IncludeGroupInfo`** - Include detailed group information in output
- **`-ShowProgress`** - Display progress during processing (default: true)

### Export-EntraGroupMembers Parameters

- **`-InputObject`** - Result object from Get-EntraGroupMembers
- **`-OutputPath`** - Output file path (extension determines format)
- **`-Format`** - Output format: CSV, JSON, HTML (auto-detected from path)
- **`-IncludeStatistics`** - Include processing statistics in export

## Output

The module returns a comprehensive result object with:

### User Objects
Each user contains:
- `UserId` - Azure AD User Object ID
- `DisplayName` - User's display name
- `UserPrincipalName` - User's UPN (email)
- `Mail` - User's email address
- `JobTitle` - User's job title
- `Department` - User's department
- `CompanyName` - User's company
- `AccountEnabled` - Whether the account is enabled
- `SourceGroupId` - The group where this user was found
- `SourceGroupName` - The group name where this user was found
- `DiscoveryDepth` - The recursion depth where this user was found
- `ProcessedAt` - Timestamp when user was processed

### Statistics Object
- `TotalUsers` - Total unique users found
- `TotalGroups` - Total groups processed
- `TotalApiCalls` - Number of Graph API calls made
- `ProcessingTimeSeconds` - Total processing time
- `ErrorCount` - Number of errors encountered
- `StartTime` - Processing start timestamp
- `EndTime` - Processing end timestamp

### Additional Data
- `ProcessedGroups` - Array of group details (if IncludeGroupInfo enabled)
- `Errors` - Array of error messages encountered during processing

## Error Handling

The unified module includes enterprise-grade error handling:

### Automatic Retry Logic
- **Transient Failures** - Automatic retry with exponential backoff for Graph API errors (429, 5xx)
- **Configurable Retries** - Default 3 attempts with intelligent delay calculation
- **Jitter Implementation** - Prevents thundering herd problems in distributed scenarios

### Comprehensive Error Tracking
- **Individual Group Failures** - Processing continues even if individual groups fail
- **Detailed Error Messages** - Specific error information with context
- **Error Collection** - All errors collected in result object for review
- **Graceful Degradation** - Partial results returned even with some failures

### Validation and Safety
- **Connection Validation** - Verifies Graph connection and permissions before processing
- **Parameter Validation** - Input validation with clear error messages
- **Circular Reference Detection** - Prevents infinite loops with robust tracking
- **Memory Management** - Proper cleanup of internal state

### Common Error Scenarios Handled
- **Authentication issues** - Clear guidance for Graph connection
- **Permission errors** - Specific permission requirements and suggestions
- **Group not found** - Graceful handling with detailed error messages
- **API rate limiting** - Automatic retry with appropriate delays
- **Network timeouts** - Retry logic with exponential backoff
- **Partial failures** - Continue processing other groups when individual groups fail

## Performance Considerations

### Optimizations
- **Type-Specific API Calls** - More efficient than generic member queries
- **Retry Logic** - Reduces manual intervention for transient failures
- **Progress Reporting** - Visibility into long-running operations
- **Memory Management** - Proper cleanup and scoped variables

### Scalability Features
- **Configurable Depth Limits** - Prevent runaway processing
- **API Call Tracking** - Monitor Graph API usage
- **Processing Statistics** - Performance metrics for optimization
- **Batch-Ready Design** - Architecture supports future batching enhancements

### Large Environment Considerations
- **Memory Usage** - Scales with unique user count
- **Processing Time** - Depends on group structure depth and breadth
- **API Limits** - Retry logic handles rate limiting automatically
- **Progress Visibility** - Real-time updates for long operations

## Troubleshooting

### Common Issues

1. **"Not connected to Microsoft Graph"**
   ```powershell
   Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"
   ```

2. **"Module not found"**
   ```powershell
   # Ensure you're in the correct directory
   Import-Module .\EntraGroupMembership.psm1 -Force
   ```

3. **"Insufficient privileges"**
   - Ensure you have the required permissions: `Group.Read.All`, `User.Read.All`
   - Contact your Azure AD administrator for permission assignment

4. **"Group not found"**
   - Verify the Group ID (must be valid GUID format)
   - Ensure you have permission to read the group
   - Check group display name spelling

5. **Slow performance or timeouts**
   - Reduce `MaxDepth` parameter for very deep hierarchies
   - Use `ShowProgress $false` for automated scripts
   - Check `$result.Statistics.TotalApiCalls` to monitor API usage

### Debugging and Monitoring

**Enable Verbose Logging:**
```powershell
$VerbosePreference = "Continue"
$result = Get-EntraGroupMembers -GroupId "your-group-id" -Verbose
```

**Check Processing Statistics:**
```powershell
$result = Get-EntraGroupMembers -GroupId "your-group-id"
$result.Statistics | Format-List
```

**Review Errors:**
```powershell
if ($result.Statistics.ErrorCount -gt 0) {
    $result.Errors | ForEach-Object { Write-Warning $_ }
}
```

**Performance Analysis:**
```powershell
Write-Host "API Efficiency: $([Math]::Round($result.Statistics.TotalUsers / $result.Statistics.TotalApiCalls, 2)) users per API call"
Write-Host "Processing Rate: $([Math]::Round($result.Statistics.TotalGroups / $result.Statistics.ProcessingTimeSeconds, 2)) groups per second"
```

### Getting Additional Help

```powershell
# Detailed help for main function
Get-Help Get-EntraGroupMembers -Full

# Detailed help for export function
Get-Help Export-EntraGroupMembers -Full

# Run interactive examples
.\Examples.ps1
Start-InteractiveDemo
```

## License

This code is provided as-is for educational and practical use. Feel free to modify and adapt for your specific needs.

## Contributing

When contributing to this project:
1. Focus on the unified module (`EntraGroupMembership.psm1`)
2. Follow PowerShell best practices
3. Include comprehensive error handling
4. Add appropriate parameter validation
5. Update documentation and examples

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Run the interactive examples in `Examples.ps1`
3. Use `Get-Help` commands for detailed parameter information
