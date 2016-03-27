function Get-MrSqlDbRestoreFileList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(ValueFromPipeline)]
        [string]$BackupFilePath
    )

    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -QueryTimeout 120 –Query "
    RESTORE FILELISTONLY
    FROM DISK = '$BackupFilePath' WITH FILE = 1
    GO" |
    Select-Object -Property LogicalName, PhysicalName, @{label='Type';expression={
        switch ($_.Type) {
            'L' {'Log'}
            'D' {'Data'}
            'F' {'FullTextCatalog'}
            'S' {'Other'}
        }
    }}

}