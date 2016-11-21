#Requires -Version 3.0 -Modules MrSQL
function Get-MrSQLAgentJobStatus {

<#
.SYNOPSIS
    Retrieves the status of the specified SQL Agent Job from the specified target instance of SQL Server.
 
.DESCRIPTION
    Get-MrSQLAgentJobStatus is a PowerShell function that is designed to retrieve the status of the specified SQL
    Server Agent job from the specified target instance of SQL Server without requiring the SQL Server PowerShell
    module or snap-in to be installed.
 
.PARAMETER ServerInstance
    The name of an instance of SQL Server where the SQL Agent is running. For default instances, only
    specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
 
.PARAMETER Name
    Specifies the name of the Job object that this cmdlet gets. The name may or may not be
    case-sensitive, depending on the collation of the SQL Server where the SQL Agent is running.

.PARAMETER Credential
    SQL Authentication userid and password in the form of a credential object.
 
.EXAMPLE
     Get-MrSQLAgentJobStatus -ServerInstance SQLServer01 -Name syspolicy_purge_history

.EXAMPLE
     Get-MrSQLAgentJobStatus -ServerInstance SQLServer01 -Name syspolicy_purge_history -Credential (Get-Credential)

.INPUTS
    None
 
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

        [Parameter(Mandatory)]
        [string]$Name,

        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    $Params = @{
        ServerInstance = $ServerInstance
        Database = 'msdb'
        Query = "EXEC dbo.sp_help_job @JOB_NAME = '$Name', @job_aspect= 'JOB'"
    }

    if ($PSBoundParameters.Credential) {
        $Params.Credential = $Credential
    }

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
