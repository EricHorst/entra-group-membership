<#
.SYNOPSIS
    Example usage of the EntraGroupMembership module.

.DESCRIPTION
    This script demonstrates how to use the EntraGroupMembership module
    to recursively get all users from nested Entra (Azure AD) groups with enhanced
    features and enterprise-grade reliability.

.NOTES
    Comprehensive examples demonstrating the module's capabilities and features.
#>

# Import the unified module
Import-Module .\EntraGroupMembership.psm1 -Force

function Show-ModuleCapabilities {
    <#
    .SYNOPSIS
        Demonstrates the capabilities of the new EntraGroupMembership module.
    #>

    Write-Host @"
========================================================
EntraGroupMembership Module - Usage Examples
========================================================

This module provides enterprise-grade functionality for analyzing
Entra (Azure AD) group memberships with the following features:

✅ Unified architecture with consistent API usage
✅ Enterprise-grade retry logic for Graph API calls
✅ Comprehensive error handling and logging
✅ Progress reporting for long-running operations
✅ Multiple export formats (CSV, JSON, HTML)
✅ Detailed processing statistics
✅ Proper variable scoping and state management
✅ Enhanced validation and parameter sets

"@ -ForegroundColor Green
}

function Invoke-BasicExample {
    <#
    .SYNOPSIS
        Basic example of getting group members by Group ID.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    Write-Host "`n=== BASIC EXAMPLE: Get Group Members by ID ===" -ForegroundColor Cyan

    try {
        # Get group members with default settings
        $result = Get-EntraGroupMembers -GroupId $GroupId

        # Display summary
        Write-Host "`nResults Summary:" -ForegroundColor Green
        Write-Host "- Total Users: $($result.Statistics.TotalUsers)"
        Write-Host "- Total Groups Processed: $($result.Statistics.TotalGroups)"
        Write-Host "- Processing Time: $($result.Statistics.ProcessingTimeSeconds) seconds"
        Write-Host "- API Calls Made: $($result.Statistics.TotalApiCalls)"

        if ($result.Users.Count -gt 0) {
            Write-Host "`nFirst 5 Users:" -ForegroundColor Yellow
            $result.Users | Select-Object -First 5 | Format-Table DisplayName, UserPrincipalName, Department, AccountEnabled -AutoSize
        }

        return $result
    }
    catch {
        Write-Error "Basic example failed: $($_.Exception.Message)"
    }
}

function Invoke-AdvancedExample {
    <#
    .SYNOPSIS
        Advanced example with comprehensive options and export.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupDisplayName
    )

    Write-Host "`n=== ADVANCED EXAMPLE: Full Feature Demonstration ===" -ForegroundColor Cyan

    try {
        # Get group members with all advanced options
        $result = Get-EntraGroupMembers -GroupDisplayName $GroupDisplayName -MaxDepth 15 -IncludeDisabledUsers -IncludeGroupInfo -ShowProgress $true

        # Display comprehensive results
        Write-Host "`nComprehensive Results:" -ForegroundColor Green
        Write-Host "- Total Users (including disabled): $($result.Statistics.TotalUsers)"
        Write-Host "- Active Users: $(($result.Users | Where-Object AccountEnabled -eq $true).Count)"
        Write-Host "- Disabled Users: $(($result.Users | Where-Object AccountEnabled -eq $false).Count)"
        Write-Host "- Total Groups Processed: $($result.Statistics.TotalGroups)"
        Write-Host "- Processing Time: $($result.Statistics.ProcessingTimeSeconds) seconds"
        Write-Host "- Errors Encountered: $($result.Statistics.ErrorCount)"

        # Show group hierarchy if available
        if ($result.ProcessedGroups.Count -gt 0) {
            Write-Host "`nProcessed Groups:" -ForegroundColor Yellow
            $result.ProcessedGroups | Format-Table DisplayName, Id -AutoSize
        }

        # Show user distribution by department
        $deptStats = $result.Users | Group-Object Department | Sort-Object Count -Descending
        if ($deptStats.Count -gt 0) {
            Write-Host "`nUser Distribution by Department:" -ForegroundColor Yellow
            $deptStats | Select-Object Name, Count | Format-Table -AutoSize
        }

        # Export to multiple formats
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $basePath = "EntraGroupAnalysis-$timestamp"

        Write-Host "`nExporting results..." -ForegroundColor Green
        Export-EntraGroupMembers -InputObject $result -OutputPath "$basePath.csv" -IncludeStatistics
        Export-EntraGroupMembers -InputObject $result -OutputPath "$basePath.json" -IncludeStatistics
        Export-EntraGroupMembers -InputObject $result -OutputPath "$basePath.html" -IncludeStatistics

        Write-Host "Exported to:" -ForegroundColor Green
        Write-Host "- CSV: $basePath.csv"
        Write-Host "- JSON: $basePath.json"
        Write-Host "- HTML: $basePath.html"

        return $result
    }
    catch {
        Write-Error "Advanced example failed: $($_.Exception.Message)"
    }
}

function Invoke-ErrorHandlingExample {
    <#
    .SYNOPSIS
        Demonstrates error handling and retry capabilities.
    #>

    Write-Host "`n=== ERROR HANDLING EXAMPLE ===" -ForegroundColor Cyan

    # Example with invalid group ID to show error handling
    try {
        Write-Host "Testing with invalid Group ID to demonstrate error handling..." -ForegroundColor Yellow
        $result = Get-EntraGroupMembers -GroupId "00000000-0000-0000-0000-000000000000"
    }
    catch {
        Write-Host "✅ Error handling working correctly:" -ForegroundColor Green
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    }

    # Example with invalid group name
    try {
        Write-Host "`nTesting with non-existent group name..." -ForegroundColor Yellow
        $result = Get-EntraGroupMembers -GroupDisplayName "NonExistentGroupName12345"
    }
    catch {
        Write-Host "✅ Error handling working correctly:" -ForegroundColor Green
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-PerformanceExample {
    <#
    .SYNOPSIS
        Demonstrates performance monitoring and optimization features.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupId
    )

    Write-Host "`n=== PERFORMANCE EXAMPLE ===" -ForegroundColor Cyan

    try {
        # Test with different depth limits to show performance impact
        Write-Host "Testing performance with different depth limits..." -ForegroundColor Yellow

        $depths = @(3, 5, 10)
        foreach ($depth in $depths) {
            Write-Host "`nTesting with MaxDepth = $depth" -ForegroundColor Green
            $result = Get-EntraGroupMembers -GroupId $GroupId -MaxDepth $depth -ShowProgress $false

            Write-Host "Results for depth $depth"
            Write-Host "- Users: $($result.Statistics.TotalUsers)"
            Write-Host "- Groups: $($result.Statistics.TotalGroups)"
            Write-Host "- API Calls: $($result.Statistics.TotalApiCalls)"
            Write-Host "- Time: $($result.Statistics.ProcessingTimeSeconds)s"

            if ($result.Statistics.ErrorCount -gt 0) {
                Write-Host "- Errors: $($result.Statistics.ErrorCount)" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Error "Performance example failed: $($_.Exception.Message)"
    }
}

function Start-InteractiveDemo {
    <#
    .SYNOPSIS
        Interactive demonstration of the module capabilities.
    #>

    Show-ModuleCapabilities

    # Check Graph connection
    Write-Host "Checking Microsoft Graph connection..." -ForegroundColor Yellow
    try {
        $context = Get-MgContext
        if (-not $context) {
            Write-Host "❌ Not connected to Microsoft Graph" -ForegroundColor Red
            Write-Host "Please connect using: Connect-MgGraph -Scopes 'Group.Read.All','User.Read.All'" -ForegroundColor Yellow
            return
        }
        Write-Host "✅ Connected as: $($context.Account)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Graph connection check failed" -ForegroundColor Red
        Write-Host "Please install and connect to Microsoft Graph PowerShell" -ForegroundColor Yellow
        return
    }

    do {
        Write-Host @"

========================================================
Choose an example to run:
========================================================
1. Basic Example (by Group ID)
2. Advanced Example (by Group Name with all features)
3. Error Handling Demonstration
4. Performance Testing
5. Exit

"@ -ForegroundColor White

        $choice = Read-Host "Enter your choice (1-5)"

        switch ($choice) {
            '1' {
                $groupId = Read-Host "Enter Group ID (GUID format)"
                if ($groupId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    Invoke-BasicExample -GroupId $groupId
                } else {
                    Write-Host "Invalid Group ID format" -ForegroundColor Red
                }
            }
            '2' {
                $groupName = Read-Host "Enter Group Display Name"
                if ($groupName) {
                    Invoke-AdvancedExample -GroupDisplayName $groupName
                } else {
                    Write-Host "Group name cannot be empty" -ForegroundColor Red
                }
            }
            '3' {
                Invoke-ErrorHandlingExample
            }
            '4' {
                $groupId = Read-Host "Enter Group ID for performance testing (GUID format)"
                if ($groupId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                    Invoke-PerformanceExample -GroupId $groupId
                } else {
                    Write-Host "Invalid Group ID format" -ForegroundColor Red
                }
            }
            '5' {
                Write-Host "Goodbye!" -ForegroundColor Green
                break
            }
            default {
                Write-Host "Invalid choice. Please enter 1-5." -ForegroundColor Red
            }
        }

        if ($choice -ne '5') {
            Read-Host "`nPress Enter to continue"
        }
    } while ($choice -ne '5')
}

# Quick usage examples (uncomment to run directly)

# Example 1: Basic usage with Group ID
# $result = Get-EntraGroupMembers -GroupId "12345678-1234-1234-1234-123456789012"

# Example 2: Advanced usage with Group Name
# $result = Get-EntraGroupMembers -GroupDisplayName "All Company Users" -IncludeDisabledUsers -IncludeGroupInfo

# Example 3: Export results
# $result | Export-EntraGroupMembers -OutputPath "GroupMembers.csv" -IncludeStatistics

# Start interactive demo
Write-Host @"
========================================================
EntraGroupMembership Module - Ready to Use!
========================================================

Quick Commands:
• Start-InteractiveDemo  - Interactive demonstration
• Get-Help Get-EntraGroupMembers -Full  - Detailed help
• Get-Help Export-EntraGroupMembers -Full  - Export help

Example Usage:
• Get-EntraGroupMembers -GroupId "your-group-id"
• Get-EntraGroupMembers -GroupDisplayName "Group Name" -IncludeGroupInfo

"@ -ForegroundColor Cyan
