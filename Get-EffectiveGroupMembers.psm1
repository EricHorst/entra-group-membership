<#
.SYNOPSIS
    Simple recursive function to get effective users from nested groups using Microsoft Graph.

.DESCRIPTION
    This is a focused implementation of the recursive logic using Get-MgGroupMemberAsGroup
    and Get-MgGroupMemberAsUser to traverse nested group memberships.

.NOTES
    This is a simplified version focusing on the core recursive logic.
    For a full-featured script, use Get-NestedGroupMembers.ps1
#>

# Global hashtable to track processed groups and prevent infinite loops
$ProcessedGroups = @{}
$AllUsers = @{}

function Get-EffectiveGroupMembers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId,

        [Parameter(Mandatory = $false)]
        [int]$MaxDepth = 10,

        [Parameter(Mandatory = $false)]
        [int]$CurrentDepth = 0
    )

    # Prevent infinite recursion
    if ($CurrentDepth -ge $MaxDepth) {
        Write-Warning "Maximum depth reached for group $GroupId"
        return
    }

    # Prevent circular references
    if ($ProcessedGroups.ContainsKey($GroupId)) {
        Write-Verbose "Group $GroupId already processed, skipping to prevent circular reference"
        return
    }

    # Mark this group as processed
    $ProcessedGroups[$GroupId] = $true

    try {
        Write-Verbose "Processing group: $GroupId (Depth: $CurrentDepth)"

        # Get all users that are direct members of this group
        $userMembers = Get-MgGroupMemberAsUser -GroupId $GroupId -All
        foreach ($user in $userMembers) {
            if (-not $AllUsers.ContainsKey($user.Id)) {
                $AllUsers[$user.Id] = $user
                Write-Verbose "Found user: $($user.DisplayName) ($($user.UserPrincipalName))"
            }
        }

        # Get all groups that are direct members of this group
        $groupMembers = Get-MgGroupMemberAsGroup -GroupId $GroupId -All
        foreach ($group in $groupMembers) {
            Write-Verbose "Found nested group: $($group.DisplayName) ($($group.Id))"
            # Recursively process the nested group
            Get-EffectiveGroupMembers -GroupId $group.Id -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
        }
    }
    catch {
        Write-Error "Error processing group $GroupId : $($_.Exception.Message)"
    }
}

# Example usage:
<#
# Connect to Microsoft Graph first
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"

# Clear the global variables if running multiple times
$ProcessedGroups.Clear()
$AllUsers.Clear()

# Get effective members of a group
Get-EffectiveGroupMembers -GroupId "your-group-id-here"

# Display results
Write-Host "Total effective users: $($AllUsers.Count)"
$AllUsers.Values | Select-Object DisplayName, UserPrincipalName, Mail | Sort-Object DisplayName
#>

# Export the function
Export-ModuleMember -Function Get-EffectiveGroupMembers
