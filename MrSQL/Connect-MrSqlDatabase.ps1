function Connect-MrSqlDatabase {

    [CmdletBinding()]
    param (

        [Parameter(Mandatory)]
        [string]$ComputerName,
        
        [Parameter(Mandatory)]
        [string]$DatabaseName,

        [Parameter(Mandatory)]
        [string]$DataFilePath,

        [Parameter(Mandatory)]
        [string]$LogFilePath

    )

    $SQL = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $ComputerName
    $Files = New-Object System.Collections.Specialized.StringCollection
    $Files.add($DatabaseName)
    $Files.add($LogFilePath)    
    $SQL.AttachDatabase($DatabaseName, $Files)

}