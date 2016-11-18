#Requires -Version 3.0
function Start-MrSqlAgentJob {

<#
.SYNOPSIS
    Starts the specified SQL Agent Job on the specified target instance of SQL Server.
 
.DESCRIPTION
    Start-MrSqlAgentJob is a PowerShell function that is designed to start the specified SQL Server
    Agent job on the specified target instance of SQL Server without requiring the SQL Server PowerShell
    module or snap-in to be installed.
 
.PARAMETER ServerInstance
    The name of an instance of SQL Server where the SQL Agent is running. For default instances, only
    specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
 
.PARAMETER Name
    Specifies the name of the Job object that this cmdlet gets. The name may or may not be
    case-sensitive, depending on the collation of the SQL Server where the SQL Agent is running.

.PARAMETER Credential
    SQL Authentication userid and password in the form of a credential object.
 
.EXAMPLE
     Start-MrSqlAgentJob -ServerInstance SQLServer01 -Name syspolicy_purge_history

.EXAMPLE
     Start-MrSqlAgentJob -ServerInstance SQLServer01 -Name syspolicy_purge_history -Credential (Get-Credential)

.EXAMPLE
     'syspolicy_purge_history' | Start-MrSqlAgentJob -ServerInstance SQLServer01
 
.INPUTS
    String
 
.OUTPUTS
    Boolean
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (        
        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory,
                   ValueFromPipeLine)]
        [string]$Name,
        
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    
    BEGIN {

        [string]$Database = 'msdb'

        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection

        if (-not($PSBoundParameters.Credential)) {
            $connectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=True;"
        }
        else {
            $connectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=False;"
            $userid = $Credential.UserName -replace '^.*\\|@.*$'
            ($password = $credential.Password).MakeReadOnly()
            $sqlCred = New-Object -TypeName System.Data.SqlClient.SqlCredential($userid, $password)
            $connection.Credential = $sqlCred
        }

        $connection.ConnectionString = $connectionString
        $ErrorActionPreference = 'Stop'
        
        try {
            $connection.Open()
            Write-Verbose -Message "Connection to the $($connection.Database) database on $($connection.DataSource) has been successfully opened."
        }
        catch {
            Write-Error -Message "An error has occurred. Error details: $($_.Exception.Message)"
        }

        $ErrorActionPreference = 'Continue'
        $command = $connection.CreateCommand()

    }

    PROCESS {

        [string]$Query = "EXEC dbo.sp_start_job N'$Name'"        
        $command.CommandText = $Query
        $ErrorActionPreference = 'Stop'

        try {
            $result = $command.ExecuteNonQuery()
        }
        catch {
            Write-Error -Message "An error has occured. Error Details: $($_.Exception.Message)"
        }

        $ErrorActionPreference = 'Continue'

        if ($result -eq -1) {
            Write-Output $true
        }
        else {
            Write-Output $false
        }

    }

    END {

        $connection.Close()
        $connection.Dispose()

    }

}