function Get-MrSqlDatabaseBackupInfo {

<#
.SYNOPSIS
    Returns database backup information for a Microsoft SQL Server database. 

.DESCRIPTION
    Get-MrSqlDatabaseBackupInfo is a function that returns database backup information for
    one or more Microsoft SQL Server databases.

.PARAMETER ComputerName
    The computer that is running Microsoft SQL Server that your targeting to
    query database file information on.

.PARAMETER InstanceName
    The instance name of SQL Server to return database file informmation for.
    The default is the default SQL Server instance.
 
.PARAMETER DatabaseName
    The database(s) to return backup informmation for. The default is all databases.

.EXAMPLE
    Get-MrSqlDatabaseBackupInfo -ComputerName sql01
 
.EXAMPLE
     Get-MrSqlDatabaseBackupInfo -ComputerName sql01 -DatabaseName master, msdb, model

.EXAMPLE
     Get-MrSqlDatabaseBackupInfo -ComputerName sql01 -InstanceName MrSQL -DatabaseName master,
     msdb, model
 
.EXAMPLE
    'master', 'msdb', 'model' | Get-MrSqlDatabaseBackupInfo -ComputerName sql01
 
.INPUTS
    String
 
.OUTPUTS
    MrSQL.DbBackupInfo
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipelineByPropertyName)]
        [Alias('ServerName',
               'PSComputerName')]
        [string[]]$ComputerName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$InstanceName = 'Default',
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$DatabaseName = '*'
    )

    BEGIN {
        $problem = $false

        Write-Verbose -Message "Attempting to load SQL Module if it's not already loaded"
        if (-not (Get-Module -Name SQLPS)) {          
            try {
                Import-Module -Name SQLPS -DisableNameChecking -ErrorAction Stop
            }
            catch {
                $problem = $true
                Write-Warning -Message "An error has occured.  Error details: $_.Exception.Message"
            }
        }                
    }

    PROCESS {

        foreach ($Computer in $ComputerName) {

            foreach ($Instance in $InstanceName) {

                Write-Verbose -Message 'Checking for default or named SQL instance'
                If (-not ($problem)) {
                    If (($Instance -eq 'Default') -or ($Instance -eq 'MSSQLSERVER')) {
                        $SQLInstance = $Computer
                    }
                    else {
                        $SQLInstance = "$Computer\$Instance"
                    }

                    $SQL = New-Object('Microsoft.SqlServer.Management.Smo.Server') -ArgumentList $SQLInstance
                }

                if (-not $problem) {
                    foreach ($db in $DatabaseName) {
                    
                        Write-Verbose -Message "Verifying a database named: $db exists on SQL Instance $SQLInstance."                        
                        try {
                            if ($db -match '\*') {
                                $databases = $SQL.Databases | Where-Object Name -like "$db"
                            }
                            else {
                                $databases = $SQL.Databases | Where-Object Name -eq "$db"                              
                            }
                        }
                        catch {
                            $problem = $true
                            Write-Warning -Message "An error has occured.  Error details: $_.Exception.Message"
                        }

                        if (-not $problem) {
                            foreach ($database in $databases) {

                                Write-Verbose -Message "Retrieving information for database: $database."

                                $CustomObject = [PSCustomObject]@{
                                    ComputerName = $SQL.Information.ComputerNamePhysicalNetBIOS
                                    InstanceName = $Instance
                                    DefaultBackupDirectory = $SQL.BackupDirectory
                                    BackupDevices = $SQL.BackupDevices                    
                                    DatabaseName = $database.Name
                                    LastBackupDate = $database.LastBackupDate
                                    LastDifferentialBackupDate = $database.LastDifferentialBackupDate
                                    LastLogBackupDate = $database.LastLogBackupDate
                                    RecoveryModel = $database.RecoveryModel
                                }

                                $CustomObject.PSTypeNames.Insert(0,’MrSQL.DatabaseBackupInfo’)
                                Write-Output $CustomObject
                            }
                        }
                    }
                }
            }
        }
    }
}