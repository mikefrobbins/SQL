#Requires -Version 3.0
function Get-MrSqlVersion {
    
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(ValueFromPipeline)] 
        [string]$ServerInstance =$env:COMPUTERNAME 
    ) 
    
    BEGIN {
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
    }

    PROCESS{
        foreach ($Instance in $ServerInstance) {
            $Server = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.Server' -ArgumentList $ServerInstance

            try {
                $VersionName = switch ($Server.VersionString.SubString(0,4)) {
                        '13.0' {'SQL Server 2016'; break}  
                        '12.0' {'SQL Server 2014'; break}  
                        '11.0' {'SQL Server 2012'; break}  
                        '10.5' {'SQL Server 2008 R2'; break}  
                        '10.0' {'SQL Server 2008'; break}
                        '9.00' {'SQL Server 2005'; break}
                        default {'unknown'}
                }
            }
            catch {
                Write-Warning -Message "Unable to connect to SQL Instance: $Instance"
                Continue
            }

            [pscustomobject]@{
                ComputerName = $Server.Name
                VersionName = $VersionName
                Version = $Server.VersionString
            }
        }
    }
}