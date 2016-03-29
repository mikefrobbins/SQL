function Restore-MrSqlDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [string]$Database,

        [string]$DatabasePath,

        [Parameter(ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [Alias('physical_device_name')]
        [string[]]$BackupFilePath        
    )

    PROCESS {
        $FileList = Get-MrSqlDbRestoreFileList -ServerInstance $ServerInstance -BackupFilePath $BackupFilePath[0]
        
        if (-not($PSBoundParameters.DatabasePath)) {
            $DatabasePath = Split-Path -Parent ($FileList | Where-Object type -eq data | Select-Object -ExpandProperty PhysicalName)
        }

        foreach ($file in $BackupFilePath) {
            Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -QueryTimeout 3600 –Query "
            RESTORE DATABASE $Database
            FROM  DISK = N'$file'
            WITH  FILE = 1,
             MOVE N'$($FileList | Where-Object Type -eq data | Select-Object -ExpandProperty LogicalName)' TO N'$(Join-Path -Path $DatabasePath -ChildPath "$Database.mdf")',
             MOVE N'$($FileList | Where-Object Type -eq log | Select-Object -ExpandProperty LogicalName)' TO N'$(Join-Path -Path $DatabasePath -ChildPath "$($Database)_log.ldf")',
             NORECOVERY, REPLACE
            GO"
        }
    }

    END {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -QueryTimeout 600 –Query "
        RESTORE DATABASE $Database
        WITH RECOVERY
        GO"
    }

}