function Import-MrSqlModule {

<#
.SYNOPSIS
    Imports the SQL Server PowerShell module or snapin.
 
.DESCRIPTION
    Import-MrSqlModule is a PowerShell function that imports the SQLPS PowerShell
    module (SQL Server 2012 and higher) or adds the SQL PowerShell snapin (SQL
    Server 2008 & 2008R2).
 
.EXAMPLE
     Import-MrSqlModule
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param ()

    if (-not(Get-Module -Name SQLPS) -and (-not(Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -ErrorAction SilentlyContinue))) {
    Write-Verbose -Message 'SQLPS PowerShell module or snapin not currently loaded'

        if (Get-Module -Name SQLPS -ListAvailable) {
        Write-Verbose -Message 'SQLPS PowerShell module found'

            Push-Location
            Write-Verbose -Message "Storing the current location: '$((Get-Location).Path)'"

            if ((Get-ExecutionPolicy) -ne 'Restricted') {
                Import-Module -Name SQLPS -DisableNameChecking -Verbose:$false
                Write-Verbose -Message 'SQLPS PowerShell module successfully imported'
            }
            else{
                Write-Warning -Message 'The SQLPS PowerShell module cannot be loaded with an execution policy of restricted'
            }
            
            Pop-Location
            Write-Verbose -Message "Changing current location to previously stored location: '$((Get-Location).Path)'"
        }
        elseif (Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -Registered -ErrorAction SilentlyContinue) {
        Write-Verbose -Message 'SQL PowerShell snapin found'

            Add-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100
            Write-Verbose -Message 'SQL PowerShell snapin successfully added'

            [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
            Write-Verbose -Message 'SQL Server Management Objects .NET assembly successfully loaded'
        }
        else {
            Write-Warning -Message 'SQLPS PowerShell module or snapin not found'
        }
    }
    else {
        Write-Verbose -Message 'SQL PowerShell module or snapin already loaded'
    }

}