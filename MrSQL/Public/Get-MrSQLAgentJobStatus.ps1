#Requires -Version 3.0
function Get-MrSqlAgentJobStatus {

<#
.SYNOPSIS
    Retrieves the status of one or more SQL Agent Jobs from the specified target instance of SQL Server.
 
.DESCRIPTION
    Get-MrSqlAgentJobStatus is a PowerShell function that is designed to retrieve the status of one or more SQL
    Server Agent jobs from the specified target instance of SQL Server without requiring the SQL Server PowerShell
    module or snap-in to be installed.
 
.PARAMETER ServerInstance
    The name of an instance of SQL Server where the SQL Agent is running. For default instances, only
    specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
 
.PARAMETER Name
    Specifies the name of one or more Job objects that this cmdlet gets. The names may or may not be
    case-sensitive, depending on the collation of the SQL Server where the SQL Agent is running.

.PARAMETER Credential
    SQL Authentication userid and password in the form of a credential object.
 
.EXAMPLE
     Get-MrSqlAgentJobStatus -ServerInstance SQLServer01 -Name syspolicy_purge_history, test

.EXAMPLE
     Get-MrSqlAgentJobStatus -ServerInstance SQLServer01 -Name syspolicy_purge_history -Credential (Get-Credential)

.EXAMPLE
     'syspolicy_purge_history', 'test' | Get-MrSqlAgentJobStatus -ServerInstance SQLServer01

.INPUTS
    String
 
.OUTPUTS
    PSCustomObject
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory,
                   ValueFromPipeLine)]
        [string[]]$Name,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
    
        $Params = @{
            ServerInstance = $ServerInstance
            Database = 'msdb'
        }

        if ($PSBoundParameters.Credential) {
            $Params.Credential = $Credential
        }

    }

    PROCESS {
        foreach ($n in $Name) {
        
            $Params.Query = "EXEC dbo.sp_help_job @JOB_NAME = '$n', @job_aspect= 'JOB'"
            $Results = Invoke-MrSqlDataReader @Params |
                       Select-Object -Property originating_server, name, last_run_outcome, current_execution_status

            [pscustomobject]@{
                ComputerName = $Results.originating_server
                Name = $Results.name
                Outcome = switch ($Results.current_execution_status) {
                              1 {'Executing';break}
                              2 {'Waiting for thread';break}
                              3 {'Between retries';break}
                              4 {'Idle';break}
                              5 {'Suspended';break}
                              7 {'Performing completion actions';break}        
                              default {'An unknown error has occurred'}
                          }
                Status = switch ($Results.last_run_outcome) {
                             0 {'Failed';break}
                             1 {'Succeeded';break}
                             3 {'Canceled';break}
                             5 {'Unknown';break}     
                             default {'An unknown error has occurred'}
                         }
            }
        
        }

    }

}