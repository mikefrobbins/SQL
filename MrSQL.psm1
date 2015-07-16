function Import-MrSqlModule {

<#
.SYNOPSIS
    Imports the SQL Server PowerShell module or snapin.
 
.DESCRIPTION
    Import-MrSQLModule is a PowerShell function that imports the SQLPS PowerShell
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

function Find-MrSqlDatabaseChange {

<#
.SYNOPSIS
    Queries the active transaction log and transaction log backup file(s) for
    insert, update, or delete operations on the specified database.
 
.DESCRIPTION
    Find-MrSqlDatabaseChange is a PowerShell function that is designed to query
    the active transaction log and transaction log backups for either insert,
    update, or delete operations that occurred on the specified database within
    the specified datetime range. The Invoke-MrSqlDataReader function which is
    also part of the MrSQL script module is required.
 
.PARAMETER ServerInstance
    The name of an instance of the SQL Server database engine. For default
    instances, only specify the server name: 'ServerName'. For named instances,
    use the format 'ServerName\InstanceName'.

.PARAMETER TransactionName
    The type of transaction to search for. Valid values are insert, update, or
    delete. The default value is 'Delete'.
 
.PARAMETER Database
    The name of the database to query the transaction log for.

.PARAMETER StartTime
    The beginning datetime to start searching from. The default is at the
    beginning of the current day.

.PARAMETER EndTime
    The ending datetime to stop searching at. The default is at the current
    datetime (now).

.PARAMETER Credential
    SQL Authentication userid and password in the form of a credential object.
 
.EXAMPLE
     Find-MrSqlDatabaseChange -ServerInstance sql04 -Database pubs

.EXAMPLE
     Find-MrSqlDatabaseChange -ServerInstance sql04 -TransactionName Update `
     -Database Northwind -StartTime (Get-Date).AddDays(-14) `
     -EndTime (Get-Date).AddDays(-7) -Credential (Get-Credential)

.EXAMPLE
     'AdventureWorks2012' | Find-MrSqlDatabaseChange -ServerInstance sql02\qa
 
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
        
        [ValidateSet('Insert', 'Update', 'Delete')]
        [string]$TransactionName = 'Delete',

        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [string]$Database,

        [ValidateNotNullOrEmpty()]
        [datetime]$StartTime = (Get-Date).Date,

        [ValidateNotNullOrEmpty()]
        [datetime]$EndTime = (Get-Date),

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $Params = @{
            ServerInstance = $ServerInstance
        }
        
        if($PSBoundParameters.Credential) {
            $Params.Credential = $Credential
        }
    }

    PROCESS {
        Write-Verbose -Message "Obtaining a list of transaction log backup files for the $Database database"

        $TransactionLogBackupHistory = Invoke-MrSqlDataReader @Params -Database msdb -Query "
        SELECT backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
        backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
        FROM backupset
        INNER JOIN backupmediafamily
        ON backupset.media_set_id = backupmediafamily.media_set_id
        WHERE database_name = '$Database'
        AND type = 'L'
        AND backup_start_date >= '$StartTime'"

        $TransactionLogBackups = $TransactionLogBackupHistory | Where-Object backup_finish_date -le $EndTime
        $Params.Database = $Database
        
        if (($TransactionLogBackups.count) -ne (($TransactionLogBackups | Select-Object -ExpandProperty backup_set_id -Unique).count)) {
            Write-Verbose -Message 'Transaction log backups were found that are striped accross multiple backup files'

            $UniqueBackupSetId = $TransactionLogBackups | Select-Object -ExpandProperty backup_set_id -Unique
            
            $BackupInfo = foreach ($SetId in $UniqueBackupSetId) {
                Write-Verbose -Message "Creating an updated list of transaction log backup files for backup set $($SetId)"

                $BackupSet = $TransactionLogBackups | Where-Object backup_set_id -in $SetId
                [pscustomobject]@{            
                    backup_set_id = $BackupSet | Select-Object -First 1 -ExpandProperty backup_set_id
                    last_family_number = $BackupSet | Select-Object -First 1 -ExpandProperty last_family_number
                    database_name = $BackupSet | Select-Object -First 1 -ExpandProperty database_name
                    recovery_model = $BackupSet | Select-Object -First 1 -ExpandProperty recovery_model
                    type = $BackupSet | Select-Object -First 1 -ExpandProperty type
                    position = $BackupSet | Select-Object -First 1 -ExpandProperty position
                    physical_device_name = $BackupSet.physical_device_name
                    backup_start_date = $BackupSet | Select-Object -First 1 -ExpandProperty backup_start_date
                    backup_finish_date = $BackupSet | Select-Object -First 1 -ExpandProperty backup_finish_date
                }
            }
        }
        else {
            Write-Verbose -Message 'No transaction log backup sets were found that are striped accross multiple files'
            $BackupInfo = $TransactionLogBackups
        }

        foreach ($Backup in $BackupInfo) {
            Write-Verbose -Message "Building a query to locate the $TransactionName operations in transaction log backup set $($Backup.backup_set_id)"
                            
            $Query = "SELECT [Current LSN], Operation, Context, [Transaction ID], [Transaction Name],
                      Description, [Begin Time], SUser_SName ([Transaction SID]) AS [User]
                      FROM fn_dump_dblog (NULL,NULL,N'DISK',$($Backup.Position),
                      $("N$(($Backup.physical_device_name) | ForEach-Object {"'$_'"})" -replace "' '","', N'"),
                      $((1..(64 - $Backup.last_family_number)) | ForEach-Object {'DEFAULT,'}))
                      WHERE [Transaction Name] = N'$TransactionName'
                      AND [Begin Time] >= '$(($StartTime).ToString('yyyy/MM/dd HH:mm:ss'))'
                      AND ([End Time] <= '$(($EndTime).ToString('yyyy/MM/dd HH:mm:ss'))'
                      OR [End Time] is null)" -replace ',\)',')'

            $Params.Query = $Query

            Write-Verbose -Message "Executing the query for transaction log backup set $($Backup.backup_set_id)"
            Invoke-MrSqlDataReader @Params
        }

        if ($EndTime -gt ($TransactionLogBackupHistory | Select-Object -Last 1 -ExpandProperty backup_finish_date)) {
            Write-Verbose -Message "Building a query to locate the $TransactionName operations in the active transaction log for the $Database database"

            $Query = "SELECT [Current LSN], Operation, Context, [Transaction ID], [Transaction Name],
                      Description, [Begin Time], SUser_SName ([Transaction SID]) AS [User]
                      FROM fn_dblog (NULL, NULL)
                      WHERE [Transaction Name] = N'$TransactionName'
                      AND [Begin Time] >= '$(($StartTime).ToString('yyyy/MM/dd HH:mm:ss'))'                      
                      AND ([End Time] <= '$(($EndTime).ToString('yyyy/MM/dd HH:mm:ss'))'
                      OR [End Time] is null)"
            
            $Params.Query = $Query

            Write-Verbose -Message "Executing the query for the active transaction log for the $Database database"
            Invoke-MrSqlDataReader @Params
        }
    }   
}