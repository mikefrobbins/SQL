function Get-MrSqlInstance {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [Alias('ServerName',
               'PSComputerName')]
        [string[]]$ComputerName,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty

    )
    
    BEGIN {
        $Opt = New-CimSessionOption -Protocol Dcom
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {

            Write-Verbose "Attempting to Query $Computer"
            $Params = @{
                ComputerName  = $Computer
                ErrorAction = 'Stop'
            }
 
            if ($PSBoundParameters['Credential']) {
               $Params.credential = $Credential
            }

            try {
                
                Write-Verbose -Message "Attempting to retrieve the SQL Instances via PowerShell Remoting & the registry."          
                $SQLInstances = Invoke-Command @Params {
                    Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server'
                }

                foreach ($SQLInstance in $SQLInstances) {

                    foreach ($s in $SQLInstance.InstalledInstances) {
                        if ($s -eq 'MSSQLServer') {
                            $s = 'Default'
                        }

                        [PSCustomObject]@{
                            InstanceName = $s
                            ServerName = $SQLInstance.PSComputerName
                        }
                    }
                }

            }
            catch {
                
                try {                
                    
                    if ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).ProductVersion -match 'Stack: 3\.0') {                    
                        Write-Verbose -Message "Attempting to retrieve the SQL Instances for $Computer via CimInstance."
                        $CimSession = New-CimSession @Params
                    }
                    else {
                        $Params.SessionOption = $Opt
                        $CimSession = New-CimSession @Params
                    }

                    foreach ($i in 10..12) {
                        Get-CimInstance -CimSession $CimSession -Namespace "root\Microsoft\SqlServer/ComputerManagement$i" -ClassName ServerSettings -ErrorAction SilentlyContinue
                    }

                }
                catch {
                    Write-Warning -Message "Unable to connect to $Computer using PowerShell Remoting or a CIMSession. Verify $Computer is online and try again."
                }
            }
        }
    }
}