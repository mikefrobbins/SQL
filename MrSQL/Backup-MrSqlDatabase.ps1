#Requires -Version 3.0
function Backup-MrSqlDatabase {

<#
.SYNOPSIS
    Performs a full database backup on one of more SQL Server databases.
 
.DESCRIPTION
    Backup-MrSqlDatabase is an advanced function that performs a full database backup of
    one or more specified databases.
 
.PARAMETER ComputerName
    Computer name of the SQL Server to perform the backups on.
 
 .PARAMETER InstanceName
    Instance name of the SQL Server to perform the database backups on.

.PARAMETER DatabaseName
    One or more database names to backup.

.EXAMPLE
     Backup-MrSqlDatabase -ComputerName SQL01 -InstanceName Prod -DatabaseName Master

.INPUTS
    String
 
.OUTPUTS
    None
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
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

        $Date = (Get-Date).ToString('MM-dd-yyyy')

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

                foreach ($db in $DatabaseName) {
                    
                    Write-Verbose -Message "Verifying a database named: $db exists on SQL Instance $SQLInstance."                        
                    try {
                        if ($db -match '\*') {
                            $databases = $SQL.Databases | Where-Object {$_.Name -like "$db" -and $_.Name -ne 'tempdb'}
                        }
                        else {
                            $databases = $SQL.Databases | Where-Object {$_.Name -eq "$db" -and $_.Name -ne 'tempdb'}
                        }
                    }
                    catch {
                        $problem = $true
                        Write-Warning -Message "An error has occured.  Error details: $_.Exception.Message"
                    }

                    foreach ($database in $databases.name) {
                        
                        $backupdir = Invoke-Command -ComputerName $Computer {
                            $Instance = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances -eq $Using:Instance
                            $InstancePath = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$Instance
                            $a = $((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstancePath\MSSQLServer").BackupDirectory)
                            
                            if (-not(Test-Path $a\$Using:database -PathType Container)) {
                                New-Item -Path $a\$Using:database -ItemType Container
                            }
                        }
                        
                        Backup-SqlDatabase -ServerInstance $SQLInstance -Database $database -BackupFile "$($backupdir)\$($database)_$($Date).bak"

                    }
                }
            }
        }
    }
}