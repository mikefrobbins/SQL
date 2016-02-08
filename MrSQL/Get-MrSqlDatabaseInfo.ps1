function Get-MrSqlDatabaseInfo {

<#
.SYNOPSIS
    Returns database information for a Microsoft SQL Server database. 

.DESCRIPTION
    Get-MrSqlDatabaseInfo is a function that returns the database information
    for one or more Microsoft SQL Server databases.

.PARAMETER ComputerName
    The computer that is running Microsoft SQL Server that you're targeting to
    query database information on.

.PARAMETER InstanceName
    The instance name of SQL Server to return database informmation for.
    The default is the default SQL Server instance.
 
.PARAMETER DatabaseName
    The database(s) to return informmation for. The default is all databases.

.EXAMPLE
    Get-MrSqlDatabaseInfo -ComputerName sql01
 
.EXAMPLE
     Get-MrSqlDatabaseInfo -ComputerName sql01 -DatabaseName master, msdb, model

.EXAMPLE
     Get-MrSqlDatabaseInfo -ComputerName sql01 -InstanceName MrSQL -DatabaseName master,
     msdb, model
 
.EXAMPLE
    'master', 'msdb', 'model' | Get-MrSqlDatabaseInfo -ComputerName sql01
 
.INPUTS
    String
 
.OUTPUTS
    MrSQL.DatabaseInfo
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

                        foreach ($database in $databases) {

                            Write-Verbose -Message "Attemtping to retrieve file group information for database: $database"
                            foreach ($filegroup in $database.filegroups) {
                                
                                Write-Verbose -Message "Retrieving information for filegroup: $filegroup."

                                foreach ($file in $filegroup.files) {
                            
                                    Write-Verbose -Message "Retrieving information for file: $file."

                                    $CustomObject = [PSCustomObject]@{
                                        ComputerName = $SQL.Information.ComputerNamePhysicalNetBIOS
                                        InstanceName = $Instance
                                        DatabaseName = $database.Name
                                        FileGroup = $filegroup
                                        Name = $file.Name
                                        FileName = $file.FileName
                                        DefaultPath = $(if (($file.filename -replace '[^\\]+$') -eq ($SQL.DefaultFile)){'True'} else{'False'})
                                        PrimaryFile = $file.IsPrimaryFile
                                        'Size(MB)' = '{0:N2}' -f ($file.Size / 1KB)
                                        'FreeSpace(MB)' = '{0:N2}' -f ($file.AvailableSpace / 1KB)
                                        MaxSize = $file.MaxSize
                                        "Growth($($file.GrowthType))" = $file.Growth
                                        'VolumeFreeSpace(GB)' = '{0:N2}' -f ($file.VolumeFreeSpace / 1MB)
                                        NumberOfDiskReads = $file.NumberOfDiskReads
                                        'ReadFromDisk(MB)' = '{0:N2}' -f ($file.BytesReadFromDisk / 1MB)
                                        NumberOfDiskWrites = $file.NumberOfDiskWrites
                                        'WrittenToDisk(MB)' = '{0:N2}' -f ($file.BytesWrittenToDisk / 1MB)
                                        ID = $file.ID                    
                                        Offline = $file.IsOffline                    
                                        ReadOnly = $file.IsReadOnly
                                        ReadOnlyMedia = $file.IsReadOnlyMedia
                                        Sparse = $file.IsSparse
                                        DesignMode = $file.IsDesignMode
                                        Parent = $file.Parent                    
                                        State = $file.State
                                        UsedSpace = $file.UsedSpace
                                        UserData = $file.UserData                    
                                    }

                                    $CustomObject.PSTypeNames.Insert(0,’MrSQL.DatabaseInfo’)
                                    Write-Output $CustomObject

                                }
                            }
                        }
                    }
                }
            }
        }
    }
}