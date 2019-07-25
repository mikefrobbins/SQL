function Get-MrSqlDbRestoreInfo {

<#
.SYNOPSIS
    Retrieves a list of the database backups and transaction logs backup files
    that would need to be stored to recover a database to a specific point in time.
 
.DESCRIPTION
    Get-MrSqlDbRestoreInfo is a PowerShell function that is designed to query the
    MSDB database on the specified SQL Server instance for database and transaction
    log backup information for the files that are necessary for point in time recovery
    of the specified database. 
 
.PARAMETER ServerInstance
    The name of an instance of the SQL Server database engine. For default instances,
    only specify the server name: 'ServerName'. For named instances, use the format
    'ServerName\InstanceName'.
 
.PARAMETER Database
    The name of the database to query on the specified SQL Server instance.

.PARAMETER RestoreTime
    The point in time to restore the specified database to.

.PARAMETER Credential
    SQL Authentication userid and password in the form of a credential object.
 
.EXAMPLE
     Get-MrSqlDbRestoreInfo -ServerInstance SQL04 -Database pubs -RestoreTime (
     Get-Date).AddHours(-1)

.EXAMPLE
     'pubs' | Get-MrSqlDbRestoreInfo -ServerInstance SQL04 -Credential (Get-Credential) -RestoreTime (
     Get-Date).AddHours(-1)
 
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

        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [string]$Database,

        [ValidateScript({
            If ($_ -le (Get-Date)) {
                $True
            }
            else {
                Throw "$_ is a future date and restoring a database to a future point in time is not supported."
            }
        })]
        [datetime]$RestoreTime = (Get-Date),

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $Params = @{
            ServerInstance = $ServerInstance
        }
        
        if($PSBoundParameters.Credential) {
            Write-Verbose -Message 'Credential parameter specified'
            $Params.Credential = $Credential
        }
    }

    PROCESS {
        Write-Verbose -Message "Verifying the $database database is not set to the Simple recovery model"
        if ((Invoke-MrSqlDataReader @Params -Database master -Query "
                SELECT recovery_model_desc
                FROM sys.databases
                WHERE name = '$Database'").recovery_model_desc -eq 'Simple') {
            Throw "Database: '$Database' on ServerInstance: '$ServerInstance' is set to the Simple recovery model so point in time recovery is not possible."
        }

        Write-Verbose -Message "Verifying a transaction log backup for the $Database database exists that is later than the requested recovery time."
        $LastTLBackup = Invoke-MrSqlDataReader @Params -Database msdb -Query "
                        SELECT top 1 backup_start_date
                        FROM backupset
                        WHERE database_name = '$Database'
                        AND type = 'L'
                        AND backup_start_date >= '$RestoreTime'
                        ORDER BY backup_start_date" |
                        Select-Object -ExpandProperty backup_start_date

        if (-not($LastTLBackup)) {
            Throw "No Transaction Log backups exist that are greater than or equal to $RestoreTime. Take a transaction log backup and try again."
        }
        
        Invoke-MrSqlDataReader @Params -Database msdb -Query "
            SELECT top 1 backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
            backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
            FROM backupset
            INNER JOIN backupmediafamily
            ON backupset.media_set_id = backupmediafamily.media_set_id
            WHERE database_name = '$Database'
            AND type = 'D'
            AND backup_start_date <= '$RestoreTime'
            ORDER BY backup_start_date DESC" -OutVariable FullBackup

        if (-not($FullBackup)) {
            Throw "No Full database backups exist that are greater than or equal to $RestoreTime. Unable to recover the database based on this info."
        }

        Invoke-MrSqlDataReader @Params -Database msdb -Query "
            SELECT top 1 backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
            backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
            FROM backupset
            INNER JOIN backupmediafamily
            ON backupset.media_set_id = backupmediafamily.media_set_id
            WHERE database_name = '$Database'
            AND type = 'I'
            AND backup_start_date > '$($FullBackup.backup_start_date)'
            AND backup_start_date <= '$RestoreTime'
            ORDER BY backup_start_date DESC" -OutVariable DiffBackup

        if ($DiffBackup) {
            $TLDate = $DiffBackup.backup_start_date
        }
        elseif ($FullBackup) {
            $TLDate = $FullBackup.backup_start_date
        }
        else {
            Throw "No full database backups exist for the '$Database' database."
        }
                
        Invoke-MrSqlDataReader @Params -Database msdb -Query "
            SELECT backupset.backup_set_id, backupset.last_family_number, backupset.database_name, backupset.recovery_model, backupset.type,
            backupset.position, backupmediafamily.physical_device_name, backupset.backup_start_date, backupset.backup_finish_date
            FROM backupset
            INNER JOIN backupmediafamily
            ON backupset.media_set_id = backupmediafamily.media_set_id
            WHERE database_name = '$Database'
            AND type = 'L'
            AND backup_start_date > '$TLDate'
            AND backup_start_date <= '$LastTLBackup'
            ORDER BY backup_start_date" -OutVariable $TLBackups

    }

}