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
        [string[]]$BackupFilePath,
        
        [string]$StopAtLSN       
    )

    PROCESS {

        foreach ($file in $BackupFilePath) {
            [array]$Files += $file
        }

    }

    END {
    
        $FileList = Get-MrSqlDbRestoreFileList -ServerInstance $ServerInstance -BackupFilePath $BackupFilePath[0]
        
        if (-not($PSBoundParameters.DatabasePath)) {
            $DatabasePath = Split-Path -Parent ($FileList | Where-Object type -eq data | Select-Object -ExpandProperty PhysicalName)
        }
        
        foreach ($file in $Files) {

            if (-not($PSBoundParameters.StopAtLSN) -or $file -ne $Files[-1]) {
                Write-Verbose -Message '***Restore Database***'

                Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -QueryTimeout 3600 –Query "
                RESTORE DATABASE $Database
                FROM  DISK = N'$file'
                WITH  FILE = 1,
                 MOVE N'$($FileList | Where-Object Type -eq data | Select-Object -ExpandProperty LogicalName)' TO N'$(Join-Path -Path $DatabasePath -ChildPath "$Database.mdf")',
                 MOVE N'$($FileList | Where-Object Type -eq log | Select-Object -ExpandProperty LogicalName)' TO N'$(Join-Path -Path $DatabasePath -ChildPath "$($Database)_log.ldf")',
                 NORECOVERY, REPLACE
                GO"

            }
            else {
                Write-Verbose -Message '***Restore Transaction Log***'

                Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -QueryTimeout 3600 –Query "
                RESTORE LOG $Database
                FROM  DISK = N'$file'
                WITH STOPBEFOREMARK = 'lsn:$StopAtLSN',                 
                 NORECOVERY
                GO"
                
            }

        }

        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -QueryTimeout 600 –Query "
        RESTORE DATABASE $Database
        WITH RECOVERY
        GO"
    }

}