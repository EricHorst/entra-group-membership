<#
.SYNOPSIS
    Recursively gets all effective users from nested Azure AD/Entra groups.

.DESCRIPTION
    This script uses Microsoft Graph PowerShell cmdlets to recursively traverse nested group memberships
    and return all effective users. It handles circular references and provides detailed logging.

.PARAMETER GroupId
    The Object ID of the Azure AD group to analyze.

.PARAMETER GroupDisplayName
    The display name of the Azure AD group to analyze. If both GroupId and GroupDisplayName are provided, GroupId takes precedence.

.PARAMETER MaxDepth
    Maximum recursion depth to prevent infinite loops. Default is 10.

.PARAMETER IncludeGroupInfo
    Include additional group information in the output.

.PARAMETER ExportToCsv
    Export results to a CSV file.

.PARAMETER CsvPath
    Path for the CSV export. If not specified, uses current directory with timestamp.

.EXAMPLE
    .\Get-NestedGroupMembers.ps1 -GroupId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\Get-NestedGroupMembers.ps1 -GroupDisplayName "All Company Users" -IncludeGroupInfo -ExportToCsv

.NOTES
    Requires Microsoft.Graph PowerShell module and appropriate permissions:
    - Group.Read.All or Group.ReadWrite.All
    - User.Read.All

    Author: GitHub Copilot
    Version: 1.0
#>

[CmdletBinding(DefaultParameterSetName = 'ById')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
    [string]$GroupId,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
    [string]$GroupDisplayName,

    [Parameter(Mandatory = $false)]
    [int]$MaxDepth = 10,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeGroupInfo,

    [Parameter(Mandatory = $false)]
    [switch]$ExportToCsv,

    [Parameter(Mandatory = $false)]
    [string]$CsvPath
)

# Import Microsoft Graph module if not already loaded
if (-not (Get-Module -Name Microsoft.Graph.Groups -ListAvailable)) {
    Write-Error "Microsoft.Graph.Groups module is not installed. Please install it using: Install-Module Microsoft.Graph"
    exit 1
}

if (-not (Get-Module -Name Microsoft.Graph.Users -ListAvailable)) {
    Write-Error "Microsoft.Graph.Users module is not installed. Please install it using: Install-Module Microsoft.Graph"
    exit 1
}

Import-Module Microsoft.Graph.Groups -Force
Import-Module Microsoft.Graph.Users -Force

# Global variables to track processed groups and users
$script:ProcessedGroups = @{}
$script:AllUsers = @{}
$script:CurrentDepth = 0

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $indentation = "  " * $script:CurrentDepth
    Write-Host "[$timestamp] [$Level] $indentation$Message"
}

function Get-GroupByDisplayName {
    param([string]$DisplayName)

    try {
        Write-Log "Searching for group with display name: $DisplayName"
        $groups = Get-MgGroup -Filter "displayName eq '$DisplayName'" -Property Id, DisplayName

        if ($groups.Count -eq 0) {
            throw "Group with display name '$DisplayName' not found"
        }
        elseif ($groups.Count -gt 1) {
            Write-Warning "Multiple groups found with display name '$DisplayName'. Using the first one."
        }

        return $groups[0]
    }
    catch {
        Write-Error "Error finding group '$DisplayName': $($_.Exception.Message)"
        throw
    }
}

function Get-NestedGroupMembersRecursive {
    param(
        [string]$GroupId,
        [int]$CurrentDepth = 0
    )

    # Check depth limit
    if ($CurrentDepth -ge $MaxDepth) {
        Write-Log "Maximum depth ($MaxDepth) reached for group $GroupId" "WARNING"
        return
    }

    # Check if we've already processed this group (circular reference protection)
    if ($script:ProcessedGroups.ContainsKey($GroupId)) {
        Write-Log "Group $GroupId already processed (circular reference detected)" "WARNING"
        return
    }

    $script:CurrentDepth = $CurrentDepth

    try {
        # Mark this group as being processed
        $script:ProcessedGroups[$GroupId] = $true

        # Get group information
        $group = Get-MgGroup -GroupId $GroupId -Property Id, DisplayName, Description
        Write-Log "Processing group: $($group.DisplayName) ($GroupId)"

        # Get direct members of the group
        $members = Get-MgGroupMember -GroupId $GroupId -All

        Write-Log "Found $($members.Count) direct members in group $($group.DisplayName)"

        foreach ($member in $members) {
            switch ($member.AdditionalProperties.'@odata.type') {
                '#microsoft.graph.user' {
                    # It's a user - get detailed user information
                    try {
                        $user = Get-MgUser -UserId $member.Id -Property Id, DisplayName, UserPrincipalName, Mail, JobTitle, Department, CompanyName, AccountEnabled

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
                                Depth = $CurrentDepth
                            }

                            $script:AllUsers[$user.Id] = $userInfo
                            Write-Log "Added user: $($user.DisplayName) ($($user.UserPrincipalName))"
                        }
                        else {
                            Write-Log "User $($user.DisplayName) already found through another group path"
                        }
                    }
                    catch {
                        Write-Log "Error getting user details for $($member.Id): $($_.Exception.Message)" "ERROR"
                    }
                }

                '#microsoft.graph.group' {
                    # It's a nested group - recurse into it
                    Write-Log "Found nested group: $($member.Id)"
                    Get-NestedGroupMembersRecursive -GroupId $member.Id -CurrentDepth ($CurrentDepth + 1)
                }

                default {
                    Write-Log "Skipping member of type: $($member.AdditionalProperties.'@odata.type')" "WARNING"
                }
            }
        }
    }
    catch {
        Write-Log "Error processing group $GroupId : $($_.Exception.Message)" "ERROR"
    }
}

function Export-Results {
    param([array]$Users, [string]$Path)

    if (-not $Path) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $Path = "EntraGroupMembers-$timestamp.csv"
    }

    try {
        $Users | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        Write-Log "Results exported to: $Path"
    }
    catch {
        Write-Error "Error exporting to CSV: $($_.Exception.Message)"
    }
}

# Main execution
try {
    # Check if connected to Microsoft Graph
    try {
        $context = Get-MgContext
        if (-not $context) {
            Write-Host "Not connected to Microsoft Graph. Please connect using Connect-MgGraph."
            Write-Host "Example: Connect-MgGraph -Scopes 'Group.Read.All','User.Read.All'"
            exit 1
        }
        Write-Log "Connected to Microsoft Graph as: $($context.Account)"
    }
    catch {
        Write-Host "Please connect to Microsoft Graph first using Connect-MgGraph."
        Write-Host "Example: Connect-MgGraph -Scopes 'Group.Read.All','User.Read.All'"
        exit 1
    }

    # Resolve group ID if display name was provided
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $targetGroup = Get-GroupByDisplayName -DisplayName $GroupDisplayName
        $GroupId = $targetGroup.Id
        Write-Log "Resolved group '$GroupDisplayName' to ID: $GroupId"
    }

    Write-Log "Starting recursive group member enumeration for group: $GroupId"
    Write-Log "Maximum recursion depth: $MaxDepth"

    # Start the recursive enumeration
    Get-NestedGroupMembersRecursive -GroupId $GroupId -CurrentDepth 0

    # Prepare results
    $allUsersArray = $script:AllUsers.Values | Sort-Object DisplayName

    Write-Log "==============================================="
    Write-Log "SUMMARY"
    Write-Log "==============================================="
    Write-Log "Total unique users found: $($allUsersArray.Count)"
    Write-Log "Total groups processed: $($script:ProcessedGroups.Count)"

    if ($IncludeGroupInfo) {
        Write-Log "Groups processed:"
        foreach ($processedGroupId in $script:ProcessedGroups.Keys) {
            try {
                $groupInfo = Get-MgGroup -GroupId $processedGroupId -Property DisplayName
                Write-Log "  - $($groupInfo.DisplayName) ($processedGroupId)"
            }
            catch {
                Write-Log "  - $processedGroupId (unable to get display name)"
            }
        }
    }

    # Display results
    Write-Host "`nEffective Users:" -ForegroundColor Green
    $allUsersArray | Format-Table -Property DisplayName, UserPrincipalName, Department, JobTitle, AccountEnabled -AutoSize

    # Export to CSV if requested
    if ($ExportToCsv) {
        Export-Results -Users $allUsersArray -Path $CsvPath
    }

    # Return the users for further processing if needed
    return $allUsersArray
}
catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
