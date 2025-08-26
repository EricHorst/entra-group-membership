<#
.SYNOPSIS
    Enterprise-grade PowerShell module for recursively enumerating Entra (Azure AD) group memberships.

.DESCRIPTION
    This module provides robust, scalable functions to recursively traverse nested group memberships
    and return all effective users. It combines the best practices from multiple implementations
    with enhanced error handling, retry logic, and proper variable scoping.

.NOTES
    Author: Consolidated from multiple implementations
    Version: 2.0
    Requires: Microsoft.Graph.Groups, Microsoft.Graph.Users

    Required Permissions:
    - Group.Read.All or Group.ReadWrite.All
    - User.Read.All
#>

using namespace System.Collections.Generic

# Module-scoped variables for tracking state
$script:ProcessedGroups = [Dictionary[string, bool]]::new()
$script:AllUsers = [Dictionary[string, PSCustomObject]]::new()
$script:OperationStats = @{
    TotalApiCalls = 0
    GroupsProcessed = 0
    UsersFound = 0
    StartTime = $null
    Errors = [List[string]]::new()
}

#region Helper Functions

function Write-ModuleLog {
    <#
    .SYNOPSIS
        Centralized logging function for the module.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$Level = 'Info',

        [Parameter(Mandatory = $false)]
        [int]$Depth = 0
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $indentation = "  " * $Depth
    $prefix = "[$timestamp] [$Level]"

    switch ($Level) {
        'Debug' {
            Write-Debug "$prefix $indentation$Message"
        }
        'Info' {
            Write-Verbose "$prefix $indentation$Message"
        }
        'Warning' {
            Write-Warning "$prefix $indentation$Message"
        }
        'Error' {
            Write-Error "$prefix $indentation$Message"
            $script:OperationStats.Errors.Add("$prefix $Message")
        }
    }
}

function Test-GraphConnection {
    <#
    .SYNOPSIS
        Validates Microsoft Graph connection and required permissions.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $context = Get-MgContext -ErrorAction Stop
        if (-not $context) {
            Write-ModuleLog -Message "Not connected to Microsoft Graph. Please connect using Connect-MgGraph." -Level 'Error'
            Write-Host "Example: Connect-MgGraph -Scopes 'Group.Read.All','User.Read.All'" -ForegroundColor Yellow
            return $false
        }

        # Check required scopes
        $requiredScopes = @('Group.Read.All', 'User.Read.All')
        $currentScopes = $context.Scopes

        foreach ($scope in $requiredScopes) {
            if ($scope -notin $currentScopes -and 'Group.ReadWrite.All' -notin $currentScopes) {
                Write-ModuleLog -Message "Missing required scope: $scope" -Level 'Warning'
            }
        }

        Write-ModuleLog -Message "Connected to Microsoft Graph as: $($context.Account)" -Level 'Info'
        return $true
    }
    catch {
        Write-ModuleLog -Message "Failed to verify Graph connection: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

function Invoke-GraphCallWithRetry {
    <#
    .SYNOPSIS
        Executes Microsoft Graph calls with retry logic for resilience.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [int]$BaseDelay = 1,

        [Parameter(Mandatory = $false)]
        [string]$OperationName = "Graph API Call"
    )

    $attempt = 0
    $lastException = $null

    while ($attempt -le $MaxRetries) {
        try {
            $script:OperationStats.TotalApiCalls++
            $result = & $ScriptBlock

            if ($attempt -gt 0) {
                Write-ModuleLog -Message "$OperationName succeeded on attempt $($attempt + 1)" -Level 'Info'
            }

            return $result
        }
        catch {
            $lastException = $_
            $attempt++

            # Check if it's a retryable error
            $isRetryable = $false
            if ($_.Exception.Message -match "429|5\d\d") {
                $isRetryable = $true
            }

            if ($attempt -le $MaxRetries -and $isRetryable) {
                # Calculate delay with exponential backoff and jitter
                $delay = $BaseDelay * [Math]::Pow(2, $attempt - 1)
                $jitter = Get-Random -Minimum 0 -Maximum 1000
                $totalDelay = $delay + ($jitter / 1000)

                Write-ModuleLog -Message "$OperationName failed on attempt $attempt. Retrying in $totalDelay seconds..." -Level 'Warning'
                Start-Sleep -Seconds $totalDelay
            }
            else {
                break
            }
        }
    }

    # If we get here, all retries failed
    Write-ModuleLog -Message "$OperationName failed after $($attempt) attempts: $($lastException.Exception.Message)" -Level 'Error'
    throw $lastException
}

function Find-GroupByDisplayName {
    <#
    .SYNOPSIS
        Finds an Entra group by display name with error handling.
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Graph.PowerShell.Models.MicrosoftGraphGroup])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    try {
        Write-ModuleLog -Message "Searching for group with display name: $DisplayName" -Level 'Info'

        $groups = Invoke-GraphCallWithRetry -ScriptBlock {
            Get-MgGroup -Filter "displayName eq '$DisplayName'" -Property Id, DisplayName -All
        } -OperationName "Search group by name"

        if ($groups.Count -eq 0) {
            throw "Group with display name '$DisplayName' not found"
        }
        elseif ($groups.Count -gt 1) {
            Write-ModuleLog -Message "Multiple groups found with display name '$DisplayName'. Using the first one." -Level 'Warning'
        }

        Write-ModuleLog -Message "Found group: $($groups[0].DisplayName) (ID: $($groups[0].Id))" -Level 'Info'
        return $groups[0]
    }
    catch {
        Write-ModuleLog -Message "Error finding group '$DisplayName': $($_.Exception.Message)" -Level 'Error'
        throw
    }
}

function Initialize-ModuleState {
    <#
    .SYNOPSIS
        Initializes or resets the module's internal state.
    #>
    [CmdletBinding()]
    param()

    $script:ProcessedGroups.Clear()
    $script:AllUsers.Clear()
    $script:OperationStats.TotalApiCalls = 0
    $script:OperationStats.GroupsProcessed = 0
    $script:OperationStats.UsersFound = 0
    $script:OperationStats.StartTime = Get-Date
    $script:OperationStats.Errors.Clear()

    Write-ModuleLog -Message "Module state initialized" -Level 'Debug'
}

#endregion

#region Core Functions

function Get-EntraGroupMembersRecursive {
    <#
    .SYNOPSIS
        Recursively gets all effective users from nested Entra (Azure AD) groups.

    .DESCRIPTION
        This function uses Microsoft Graph PowerShell cmdlets to recursively traverse nested group memberships
        and return all effective users. It includes comprehensive error handling, circular reference protection,
        and retry logic for enterprise environments.

    .PARAMETER GroupId
        The Object ID of the Entra group to analyze.

    .PARAMETER MaxDepth
        Maximum recursion depth to prevent infinite loops. Default is 10.

    .PARAMETER CurrentDepth
        Current recursion depth (used internally for tracking).

    .PARAMETER IncludeDisabledUsers
        Include disabled user accounts in the results. Default is false.

    .PARAMETER ShowProgress
        Display progress information during processing. Default is true.

    .EXAMPLE
        Get-EntraGroupMembersRecursive -GroupId "12345678-1234-1234-1234-123456789012"

        Gets all effective users from the specified group and its nested groups.

    .EXAMPLE
        Get-EntraGroupMembersRecursive -GroupId "12345678-1234-1234-1234-123456789012" -MaxDepth 5 -IncludeDisabledUsers

        Gets all users (including disabled) with a maximum recursion depth of 5 levels.

    .OUTPUTS
        Returns a collection of user objects with detailed properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$GroupId,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$MaxDepth = 10,

        [Parameter(Mandatory = $false)]
        [int]$CurrentDepth = 0,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDisabledUsers,

        [Parameter(Mandatory = $false)]
        [bool]$ShowProgress = $true
    )

    # Depth limit check
    if ($CurrentDepth -ge $MaxDepth) {
        Write-ModuleLog -Message "Maximum depth ($MaxDepth) reached for group $GroupId" -Level 'Warning' -Depth $CurrentDepth
        return
    }

    # Circular reference protection
    if ($script:ProcessedGroups.ContainsKey($GroupId)) {
        Write-ModuleLog -Message "Group $GroupId already processed (circular reference detected)" -Level 'Warning' -Depth $CurrentDepth
        return
    }

    try {
        # Mark group as being processed
        $script:ProcessedGroups[$GroupId] = $true
        $script:OperationStats.GroupsProcessed++

        # Get group information
        $group = Invoke-GraphCallWithRetry -ScriptBlock {
            Get-MgGroup -GroupId $GroupId -Property Id, DisplayName, Description, Mail
        } -OperationName "Get group details"

        Write-ModuleLog -Message "Processing group: $($group.DisplayName) ($GroupId)" -Level 'Info' -Depth $CurrentDepth

        # Update progress if enabled
        if ($ShowProgress -and $CurrentDepth -eq 0) {
            Write-Progress -Activity "Processing Entra Groups" -Status "Processing: $($group.DisplayName)" -PercentComplete 0
        }

        # Get direct user members using type-specific cmdlet
        $userMembers = Invoke-GraphCallWithRetry -ScriptBlock {
            Get-MgGroupMemberAsUser -GroupId $GroupId -All -Property Id, DisplayName, UserPrincipalName, Mail, JobTitle, Department, CompanyName, AccountEnabled
        } -OperationName "Get user members"

        Write-ModuleLog -Message "Found $($userMembers.Count) direct user members" -Level 'Info' -Depth $CurrentDepth

        # Process user members
        foreach ($user in $userMembers) {
            # Skip disabled users if not requested
            if (-not $IncludeDisabledUsers -and -not $user.AccountEnabled) {
                Write-ModuleLog -Message "Skipping disabled user: $($user.DisplayName)" -Level 'Debug' -Depth $CurrentDepth
                continue
            }

            if (-not $script:AllUsers.ContainsKey($user.Id)) {
                $userInfo = [PSCustomObject]@{
                    UserId = $user.Id
                    DisplayName = $user.DisplayName
                    UserPrincipalName = $user.UserPrincipalName
                    Mail = $user.Mail
                    JobTitle = $user.JobTitle
                    Department = $user.Department
                    CompanyName = $user.CompanyName
                    AccountEnabled = $user.AccountEnabled
                    SourceGroupId = $GroupId
                    SourceGroupName = $group.DisplayName
                    DiscoveryDepth = $CurrentDepth
                    ProcessedAt = Get-Date
                }

                $script:AllUsers[$user.Id] = $userInfo
                $script:OperationStats.UsersFound++

                Write-ModuleLog -Message "Added user: $($user.DisplayName) ($($user.UserPrincipalName))" -Level 'Debug' -Depth $CurrentDepth
            }
            else {
                Write-ModuleLog -Message "User $($user.DisplayName) already found through another group path" -Level 'Debug' -Depth $CurrentDepth
            }
        }

        # Get direct group members using type-specific cmdlet
        $groupMembers = Invoke-GraphCallWithRetry -ScriptBlock {
            Get-MgGroupMemberAsGroup -GroupId $GroupId -All -Property Id, DisplayName, Description, Mail
        } -OperationName "Get group members"

        Write-ModuleLog -Message "Found $($groupMembers.Count) nested groups" -Level 'Info' -Depth $CurrentDepth

        # Process nested groups recursively
        foreach ($nestedGroup in $groupMembers) {
            Write-ModuleLog -Message "Found nested group: $($nestedGroup.DisplayName) ($($nestedGroup.Id))" -Level 'Info' -Depth $CurrentDepth

            # Recursive call with increased depth
            Get-EntraGroupMembersRecursive -GroupId $nestedGroup.Id -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1) -IncludeDisabledUsers:$IncludeDisabledUsers -ShowProgress $ShowProgress
        }

    }
    catch {
        Write-ModuleLog -Message "Error processing group $GroupId : $($_.Exception.Message)" -Level 'Error' -Depth $CurrentDepth
        # Don't re-throw to allow processing of other groups to continue
    }
    finally {
        if ($ShowProgress -and $CurrentDepth -eq 0) {
            Write-Progress -Activity "Processing Entra Groups" -Completed
        }
    }
}

function Get-EntraGroupMembers {
    <#
    .SYNOPSIS
        Main function to get all effective users from nested Entra (Azure AD) groups.

    .DESCRIPTION
        This is the primary entry point for getting effective group membership. It handles initialization,
        validation, and provides comprehensive output including statistics and error reporting.

    .PARAMETER GroupId
        The Object ID of the Entra group to analyze.

    .PARAMETER GroupDisplayName
        The display name of the Entra group to analyze. Alternative to GroupId.

    .PARAMETER MaxDepth
        Maximum recursion depth to prevent infinite loops. Default is 10.

    .PARAMETER IncludeDisabledUsers
        Include disabled user accounts in the results. Default is false.

    .PARAMETER IncludeGroupInfo
        Include additional group information in the output summary.

    .PARAMETER ShowProgress
        Display progress information during processing. Default is true.

    .EXAMPLE
        Get-EntraGroupMembers -GroupId "12345678-1234-1234-1234-123456789012"

        Gets all effective users from the specified group.

    .EXAMPLE
        Get-EntraGroupMembers -GroupDisplayName "All Company Users" -IncludeDisabledUsers -IncludeGroupInfo

        Gets all users including disabled accounts, with additional group information.

    .OUTPUTS
        Returns a PSCustomObject containing:
        - Users: Array of user objects
        - Statistics: Processing statistics
        - ProcessedGroups: List of groups that were processed
        - Errors: Any errors that occurred during processing
    #>
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$GroupId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$GroupDisplayName,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$MaxDepth = 10,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeDisabledUsers,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeGroupInfo,

        [Parameter(Mandatory = $false)]
        [bool]$ShowProgress = $true
    )

    begin {
        # Validate Graph connection
        if (-not (Test-GraphConnection)) {
            throw "Microsoft Graph connection validation failed. Please connect using Connect-MgGraph."
        }

        # Initialize module state
        Initialize-ModuleState

        Write-ModuleLog -Message "Starting Entra group membership enumeration" -Level 'Info'
    }

    process {
        try {
            # Resolve group ID if display name was provided
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                $targetGroup = Find-GroupByDisplayName -DisplayName $GroupDisplayName
                $GroupId = $targetGroup.Id
                Write-ModuleLog -Message "Resolved group '$GroupDisplayName' to ID: $GroupId" -Level 'Info'
            }

            Write-ModuleLog -Message "Target Group ID: $GroupId" -Level 'Info'
            Write-ModuleLog -Message "Maximum recursion depth: $MaxDepth" -Level 'Info'
            Write-ModuleLog -Message "Include disabled users: $IncludeDisabledUsers" -Level 'Info'

            # Start recursive enumeration
            Get-EntraGroupMembersRecursive -GroupId $GroupId -MaxDepth $MaxDepth -IncludeDisabledUsers:$IncludeDisabledUsers -ShowProgress $ShowProgress

            # Calculate processing time
            $processingTime = (Get-Date) - $script:OperationStats.StartTime

            # Prepare results
            $allUsersArray = $script:AllUsers.Values | Sort-Object DisplayName

            # Build comprehensive result object
            $result = [PSCustomObject]@{
                Users = $allUsersArray
                Statistics = [PSCustomObject]@{
                    TotalUsers = $allUsersArray.Count
                    TotalGroups = $script:OperationStats.GroupsProcessed
                    TotalApiCalls = $script:OperationStats.TotalApiCalls
                    ProcessingTimeSeconds = [Math]::Round($processingTime.TotalSeconds, 2)
                    ErrorCount = $script:OperationStats.Errors.Count
                    StartTime = $script:OperationStats.StartTime
                    EndTime = Get-Date
                }
                ProcessedGroups = @()
                Errors = $script:OperationStats.Errors.ToArray()
            }

            # Add processed group information if requested
            if ($IncludeGroupInfo) {
                $groupInfo = @()
                foreach ($processedGroupId in $script:ProcessedGroups.Keys) {
                    try {
                        $groupDetails = Invoke-GraphCallWithRetry -ScriptBlock {
                            Get-MgGroup -GroupId $processedGroupId -Property Id, DisplayName, Description, Mail
                        } -OperationName "Get processed group details"

                        $groupInfo += [PSCustomObject]@{
                            Id = $groupDetails.Id
                            DisplayName = $groupDetails.DisplayName
                            Description = $groupDetails.Description
                            Mail = $groupDetails.Mail
                        }
                    }
                    catch {
                        Write-ModuleLog -Message "Could not retrieve details for processed group $processedGroupId" -Level 'Warning'
                        $groupInfo += [PSCustomObject]@{
                            Id = $processedGroupId
                            DisplayName = "Unable to retrieve"
                            Description = $null
                            Mail = $null
                        }
                    }
                }
                $result.ProcessedGroups = $groupInfo
            }

            # Display summary
            Write-Host "`n===============================================" -ForegroundColor Cyan
            Write-Host "ENTRA GROUP MEMBERSHIP ANALYSIS COMPLETE" -ForegroundColor Cyan
            Write-Host "===============================================" -ForegroundColor Cyan
            Write-Host "Total unique users found: $($result.Statistics.TotalUsers)" -ForegroundColor Green
            Write-Host "Total groups processed: $($result.Statistics.TotalGroups)" -ForegroundColor Green
            Write-Host "Total API calls made: $($result.Statistics.TotalApiCalls)" -ForegroundColor Yellow
            Write-Host "Processing time: $($result.Statistics.ProcessingTimeSeconds) seconds" -ForegroundColor Yellow

            if ($result.Statistics.ErrorCount -gt 0) {
                Write-Host "Errors encountered: $($result.Statistics.ErrorCount)" -ForegroundColor Red
                Write-Host "Use the .Errors property for details" -ForegroundColor Red
            }

            return $result
        }
        catch {
            Write-ModuleLog -Message "Fatal error during group membership enumeration: $($_.Exception.Message)" -Level 'Error'
            throw
        }
    }
}

#endregion

#region Export Functions

function Export-EntraGroupMembers {
    <#
    .SYNOPSIS
        Exports Entra group membership results to various formats.

    .DESCRIPTION
        Exports the results from Get-EntraGroupMembers to CSV, JSON, or other formats
        with customizable options for different reporting needs.

    .PARAMETER InputObject
        The result object from Get-EntraGroupMembers.

    .PARAMETER OutputPath
        The output file path. Extension determines format (.csv, .json, .html).

    .PARAMETER Format
        Output format: CSV, JSON, HTML. If not specified, inferred from OutputPath extension.

    .PARAMETER IncludeStatistics
        Include processing statistics in the export.

    .EXAMPLE
        $result = Get-EntraGroupMembers -GroupId "12345678-1234-1234-1234-123456789012"
        Export-EntraGroupMembers -InputObject $result -OutputPath "C:\Reports\GroupMembers.csv"

        Exports the results to a CSV file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('CSV', 'JSON', 'HTML')]
        [string]$Format,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeStatistics
    )

    # Determine format from file extension if not specified
    if (-not $Format) {
        $extension = [System.IO.Path]::GetExtension($OutputPath).ToLower()
        switch ($extension) {
            '.csv' { $Format = 'CSV' }
            '.json' { $Format = 'JSON' }
            '.html' { $Format = 'HTML' }
            default { $Format = 'CSV' }
        }
    }

    try {
        switch ($Format) {
            'CSV' {
                $InputObject.Users | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                if ($IncludeStatistics) {
                    $statsPath = $OutputPath -replace '\.csv$', '_Statistics.csv'
                    $InputObject.Statistics | Export-Csv -Path $statsPath -NoTypeInformation -Encoding UTF8
                }
            }
            'JSON' {
                $exportData = if ($IncludeStatistics) { $InputObject } else { @{ Users = $InputObject.Users } }
                $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
            }
            'HTML' {
                # Create basic HTML report
                $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Entra Group Membership Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .stats { background-color: #e7f3ff; padding: 10px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <h1>Entra Group Membership Report</h1>
"@
                if ($IncludeStatistics) {
                    $html += @"
    <div class="stats">
        <h2>Processing Statistics</h2>
        <p>Total Users: $($InputObject.Statistics.TotalUsers)</p>
        <p>Total Groups: $($InputObject.Statistics.TotalGroups)</p>
        <p>Processing Time: $($InputObject.Statistics.ProcessingTimeSeconds) seconds</p>
        <p>Generated: $(Get-Date)</p>
    </div>
"@
                }

                $html += @"
    <h2>Users</h2>
    <table>
        <tr>
            <th>Display Name</th>
            <th>User Principal Name</th>
            <th>Department</th>
            <th>Job Title</th>
            <th>Account Enabled</th>
            <th>Source Group</th>
        </tr>
"@

                foreach ($user in $InputObject.Users) {
                    $html += @"
        <tr>
            <td>$($user.DisplayName)</td>
            <td>$($user.UserPrincipalName)</td>
            <td>$($user.Department)</td>
            <td>$($user.JobTitle)</td>
            <td>$($user.AccountEnabled)</td>
            <td>$($user.SourceGroupName)</td>
        </tr>
"@
                }

                $html += @"
    </table>
</body>
</html>
"@
                $html | Out-File -FilePath $OutputPath -Encoding UTF8
            }
        }

        Write-ModuleLog -Message "Results exported to: $OutputPath" -Level 'Info'
    }
    catch {
        Write-ModuleLog -Message "Error exporting results: $($_.Exception.Message)" -Level 'Error'
        throw
    }
}

#endregion

# Export module members
Export-ModuleMember -Function Get-EntraGroupMembers, Export-EntraGroupMembers
