#Requires -Version 3.0
function Test-MrSqlDbBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [Alias('physical_device_name')]
        [string[]]$BackupFilePath,

        [ValidateNotNullOrEmpty()]
        [int]$FileNumber = 1,

        [switch]$Detailed
    )

    PROCESS {
        foreach ($BackupFile in $BackupFilePath) {
            try {
                $FileList = Get-MrSqlDbRestoreFileList -ServerInstance $ServerInstance -BackupFilePath $BackupFile -ErrorAction Stop
            }
            catch {
                Write-Warning -Message 'An unexpected error has occurred'
                Continue
            }

            $BackupInfo = (Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "
            RESTORE VERIFYONLY FROM DISK = '$BackupFile' WITH FILE = $FileNumber" -Verbose | Out-Null) 2>&1 4>&1
        
            if ($BackupInfo -like '*The backup set on file ? is valid*') {
                $Valid = $true
            }
            else {
                $Valid = $false
            }

            if ($PSBoundParameters.Detailed) {
                [pscustomobject]@{
                    DatabaseName = ($FileList | Where-Object Type -eq Data).LogicalName
                    BackupFile = $BackupFile -replace '^.*\\'
                    ValidBackup = $Valid
                }
            }
            else {
                Write-Output $Valid
            }
            
        }

    }

}