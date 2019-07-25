function Invoke-MrSqlDataReader {

<#
.SYNOPSIS
    Runs a select statement query against a SQL Server database.
 
.DESCRIPTION
    Invoke-MrSqlDataReader is a PowerShell function that is designed to query
    a SQL Server database using a select statement without the need for the SQL
    PowerShell module or snap-in being installed.
 
.PARAMETER ServerInstance
    The name of an instance of the SQL Server database engine. For default instances,
    only specify the server name: 'ServerName'. For named instances, use the format
    'ServerName\InstanceName'.
 
.PARAMETER Database
    The name of the database to query on the specified SQL Server instance.
 
.PARAMETER Query
    Specifies one Transact-SQL select statement query to be run.

.PARAMETER Credential
    SQL Authentication userid and password in the form of a credential object.
 
.EXAMPLE
     Invoke-MrSqlDataReader -ServerInstance Server01 -Database Master -Query '
     select name, database_id, compatibility_level, recovery_model_desc from sys.databases'

.EXAMPLE
     'select name, database_id, compatibility_level, recovery_model_desc from sys.databases' |
     Invoke-MrSqlDataReader -ServerInstance Server01 -Database Master

.EXAMPLE
     'select name, database_id, compatibility_level, recovery_model_desc from sys.databases' |
     Invoke-MrSqlDataReader -ServerInstance Server01 -Database Master -Credential (Get-Credential)
 
.INPUTS
    String
 
.OUTPUTS
    DataRow
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (        
        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [string]$Database,
        
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [string]$Query,
        
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    
    BEGIN {
        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection

        if (-not($PSBoundParameters.Credential)) {
            $connectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=True;"
        }
        else {
            $connectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=False;"
            $userid= $Credential.UserName -replace '^.*\\|@.*$'
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
        $command.CommandText = $Query
        $ErrorActionPreference = 'Stop'

        try {
            $result = $command.ExecuteReader()
        }
        catch {
            Write-Error -Message "An error has occured. Error Details: $($_.Exception.Message)"
        }

        $ErrorActionPreference = 'Continue'

        if ($result) {
            $dataTable = New-Object -TypeName System.Data.DataTable
            $dataTable.Load($result)
            $dataTable
        }
    }

    END {
        $connection.Close()
    }

}