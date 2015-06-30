function Import-MrSqlModule {

<#
.SYNOPSIS
    Imports the SQL Server PowerShell module or snapin.
 
.DESCRIPTION
    Import-MrSQLModule is a PowerShell function that imports the SQLPS PowerShell
    module (SQL Server 2012 and higher) or adds the SQL PowerShell snapin (SQL
    Server 2008 & 2008R2).
 
.EXAMPLE
     Import-MrSqlModule
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param ()

    if (-not(Get-Module -Name SQLPS) -and (-not(Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -ErrorAction SilentlyContinue))) {
    Write-Verbose -Message 'SQLPS PowerShell module or snapin not currently loaded'

        if (Get-Module -Name SQLPS -ListAvailable) {
        Write-Verbose -Message 'SQLPS PowerShell module found'

            Push-Location
            Write-Verbose -Message "Storing the current location: '$((Get-Location).Path)'"

            if ((Get-ExecutionPolicy) -ne 'Restricted') {
                Import-Module -Name SQLPS -DisableNameChecking -Verbose:$false
                Write-Verbose -Message 'SQLPS PowerShell module successfully imported'
            }
            else{
                Write-Warning -Message 'The SQLPS PowerShell module cannot be loaded with an execution policy of restricted'
            }
            
            Pop-Location
            Write-Verbose -Message "Changing current location to previously stored location: '$((Get-Location).Path)'"
        }
        elseif (Get-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100 -Registered -ErrorAction SilentlyContinue) {
        Write-Verbose -Message 'SQL PowerShell snapin found'

            Add-PSSnapin -Name SqlServerCmdletSnapin100, SqlServerProviderSnapin100
            Write-Verbose -Message 'SQL PowerShell snapin successfully added'

            [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null
            Write-Verbose -Message 'SQL Server Management Objects .NET assembly successfully loaded'
        }
        else {
            Write-Warning -Message 'SQLPS PowerShell module or snapin not found'
        }
    }
    else {
        Write-Verbose -Message 'SQL PowerShell module or snapin already loaded'
    }

}

function Invoke-MrSqlDataReader {

<#
.SYNOPSIS
    Runs a Select statement query against a SQL Server database.
 
.DESCRIPTION
    Invoke-MrSqlDataReader is a PowerShell function that is designed to query
    a SQL Server database using a Select statement without the need for the SQL
    PowerShell module or snap-in being installed.
 
.PARAMETER ServerInstance
    The name of an instance of the SQL Server database engine. For default instances,
    only specify the computer name: "MyComputer". For named instances, use the format
    "ComputerName\InstanceName".
 
.PARAMETER Database
    The name of the database to query on the specified SQL Server instance.
 
.PARAMETER Query
    Specifies one or more Transact-SQL queries to be run.

.PARAMETER Credential
    SQL Authentication userid and password in the form of a credential object. Warning:
    when using SQL Server authentication, the password is transmitted across the network
    in clear text.    
 
.EXAMPLE
     Invoke-MrSqlDataReader -ServerInstance Server01 -Database Master -Query '
     select name, database_id, compatibility_level, recovery_model_desc from sys.databases'

.EXAMPLE
     Invoke-MrSqlDataReader -ServerInstance Server01\NamedInstance -Database Master -Query '
     select name, database_id, compatibility_level, recovery_model_desc from sys.databases' -Credential (Get-Credential)
 
.INPUTS
    String
 
.OUTPUTS
    DataRow
 
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
        [string]$Database,
        
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [string[]]$Query,
        
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )
    
    BEGIN {    
        if (-not($PSBoundParameters.Credential)) {
            $connectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=True;"
        }
        else {
            $connectionString = "Server=$ServerInstance;Database=$Database;uid=$($Credential.UserName -replace '^.*\\|@.*$'); pwd=$(($Credential.GetNetworkCredential()).Password);Integrated Security=False;"
        }

        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $connection.Open()
        $command = $connection.CreateCommand()
    }

    PROCESS {
        foreach ($Q in $Query) {
            $command.CommandText = $Q
            try {
                $result = $command.ExecuteReader()
            }
            catch [System.Management.Automation.MethodInvocationException] {
                Write-Warning -Message "An error has occured. Error Details: $_.Exception.Message"
                break
            }
            catch {
                Write-Warning -Message "An error has occured. Error Details: $_.Exception.Message"
                continue
            }

            if ($result) {
                $dataTable = New-Object -TypeName System.Data.DataTable
                $dataTable.Load($result)
                $dataTable
            }
        }
    }

    END {
        $connection.Close()
    }

}