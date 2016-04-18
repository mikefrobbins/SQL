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
                $BackupInfo = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "
                RESTORE VERIFYONLY FROM DISK = '$BackupFile' WITH FILE = $FileNumber" -Verbose -ErrorAction Stop 4>&1
            }
            catch [Microsoft.SqlServer.Management.PowerShell.SqlPowerShellSqlExecutionException] {
                Write-Warning -Message $_.Exception.Message
                Continue
            }
            catch {
                Write-Error -Message $_.Exception.Message
                Break
            }
        
            if ($BackupInfo -like '*The backup set on file ? is valid*') {
                $Valid = $true
            }
            else {
                $Valid = $false
            }

            if ($PSBoundParameters.Detailed) {
                $FileList = Get-MrSqlDbRestoreFileList -ServerInstance $ServerInstance -BackupFilePath $BackupFile

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