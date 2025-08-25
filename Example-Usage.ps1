<#
.SYNOPSIS
    Example usage of the recursive group member enumeration functions.

.DESCRIPTION
    This script demonstrates how to use the Get-EffectiveGroupMembers function
    to recursively get all users from nested Azure AD groups.
#>

# Import the module
Import-Module .\Get-EffectiveGroupMembers.psm1 -Force

# Function to demonstrate usage
function Invoke-GroupMemberExample {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    Write-Host "Starting recursive group member enumeration..." -ForegroundColor Green

    # Check if connected to Microsoft Graph
    try {
        $context = Get-MgContext
        if (-not $context) {
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
            Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All"
        }
    }
    catch {
        Write-Host "Please connect to Microsoft Graph:" -ForegroundColor Red
        Write-Host "Connect-MgGraph -Scopes 'Group.Read.All', 'User.Read.All'" -ForegroundColor Yellow
        return
    }

    # Clear global variables
    $ProcessedGroups.Clear()
    $AllUsers.Clear()

    # Start time
    $startTime = Get-Date

    # Get effective members
    Get-EffectiveGroupMembers -GroupId $GroupId -MaxDepth 10

    # End time
    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Display results
    Write-Host "`n===============================================" -ForegroundColor Cyan
    Write-Host "RESULTS SUMMARY" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Groups processed: $($ProcessedGroups.Count)" -ForegroundColor White
    Write-Host "Total effective users: $($AllUsers.Count)" -ForegroundColor White
    Write-Host "Processing time: $($duration.TotalSeconds) seconds" -ForegroundColor White

    if ($AllUsers.Count -gt 0) {
        Write-Host "`nEffective Users:" -ForegroundColor Green
        $AllUsers.Values |
            Select-Object DisplayName, UserPrincipalName, Mail, JobTitle, Department |
            Sort-Object DisplayName |
            Format-Table -AutoSize
    }

    # Option to export to CSV
    $export = Read-Host "`nExport results to CSV? (y/n)"
    if ($export -eq 'y' -or $export -eq 'Y') {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $csvPath = "EffectiveGroupMembers-$timestamp.csv"

        $AllUsers.Values |
            Select-Object DisplayName, UserPrincipalName, Mail, JobTitle, Department, Id |
            Export-Csv -Path $csvPath -NoTypeInformation

        Write-Host "Results exported to: $csvPath" -ForegroundColor Green
    }
}

# Example usage - uncomment and replace with your group ID
# Invoke-GroupMemberExample -GroupId "12345678-1234-1234-1234-123456789012"

Write-Host @"
To use this script:
1. Replace the group ID in the example below with your actual group ID
2. Run: Invoke-GroupMemberExample -GroupId "your-group-id-here"

Or to find a group by name first:
`$group = Get-MgGroup -Filter "displayName eq 'Your Group Name'"
Invoke-GroupMemberExample -GroupId `$group.Id
"@ -ForegroundColor Yellow
