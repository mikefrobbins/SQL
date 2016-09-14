#Source: https://gallery.technet.microsoft.com/ScriptCenter/c193ed1a-9152-4bda-b5c0-acd044e68b2c/

try {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop}
catch {add-type -AssemblyName "Microsoft.SqlServer.ConnectionInfo"}

try {add-type -AssemblyName "Microsoft.SqlServer.Smo, Version=10.0.0.0, Culture=neutral, PublicKeyToken=89845dcd8080cc91" -EA Stop} 
catch {add-type -AssemblyName "Microsoft.SqlServer.Smo"} 

####################### 
function Get-SqlType 
{ 
    param([string]$TypeName) 
 
    switch ($TypeName)  
    { 
        'Boolean' {[Data.SqlDbType]::Bit} 
        'Byte[]' {[Data.SqlDbType]::VarBinary} 
        'Byte'  {[Data.SQLDbType]::VarBinary} 
        'Datetime'  {[Data.SQLDbType]::DateTime} 
        'Decimal' {[Data.SqlDbType]::Decimal} 
        'Double' {[Data.SqlDbType]::Float} 
        'Guid' {[Data.SqlDbType]::UniqueIdentifier} 
        'Int16'  {[Data.SQLDbType]::SmallInt} 
        'Int32'  {[Data.SQLDbType]::Int} 
        'Int64' {[Data.SqlDbType]::BigInt} 
        'UInt16'  {[Data.SQLDbType]::SmallInt} 
        'UInt32'  {[Data.SQLDbType]::Int} 
        'UInt64' {[Data.SqlDbType]::BigInt} 
        'Single' {[Data.SqlDbType]::Decimal}
        default {[Data.SqlDbType]::VarChar} 
    } 
     
} #Get-SqlType

####################### 
<# 
.SYNOPSIS 
Creates a SQL Server table from a DataTable 
.DESCRIPTION 
Creates a SQL Server table from a DataTable using SMO. 
.EXAMPLE 
$dt = Invoke-Sqlcmd2 -ServerInstance "Z003\R2" -Database pubs "select *  from authors"; Add-SqlTable -ServerInstance "Z003\R2" -Database pubscopy -TableName authors -DataTable $dt 
This example loads a variable dt of type DataTable from a query and creates an empty SQL Server table 
.EXAMPLE 
$dt = Get-Alias | Out-DataTable; Add-SqlTable -ServerInstance "Z003\R2" -Database pubscopy -TableName alias -DataTable $dt 
This example creates a DataTable from the properties of Get-Alias and creates an empty SQL Server table. 
.NOTES 
Add-SqlTable uses SQL Server Management Objects (SMO). SMO is installed with SQL Server Management Studio and is available 
as a separate download: http://www.microsoft.com/downloads/details.aspx?displaylang=en&FamilyID=ceb4346f-657f-4d28-83f5-aae0c5c83d52 
Version History 
v1.0   - Chad Miller - Initial Release 
v1.1   - Chad Miller - Updated documentation
v1.2   - Chad Miller - Add loading Microsoft.SqlServer.ConnectionInfo
v1.3   - Chad Miller - Added error handling
v1.4   - Chad Miller - Add VarCharMax and VarBinaryMax handling
v1.5   - Chad Miller - Added AsScript switch to output script instead of creating table
v1.6   - Chad Miller - Updated Get-SqlType types
v1.7   - Jana Sattainathan - Added quotes in "$sqlDbType" in every occurance of - new-object ("Microsoft.SqlServer.Management.Smo.DataType") "$sqlDbType"
#> 
function Add-SqlTable 
{ 
 
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance, 
    [Parameter(Position=1, Mandatory=$true)] [string]$Database, 
    [Parameter(Position=2, Mandatory=$true)] [String]$TableName, 
    [Parameter(Position=3, Mandatory=$true)] [System.Data.DataTable]$DataTable, 
    [Parameter(Position=4, Mandatory=$false)] [string]$Username, 
    [Parameter(Position=5, Mandatory=$false)] [string]$Password, 
    [ValidateRange(0,8000)] 
    [Parameter(Position=6, Mandatory=$false)] [Int32]$MaxLength=1000,
    [Parameter(Position=7, Mandatory=$false)] [switch]$AsScript
    ) 
 
 try {
    if($Username) 
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $ServerInstance,$Username,$Password } 
    else 
    { $con = new-object ("Microsoft.SqlServer.Management.Common.ServerConnection") $ServerInstance } 
     
    $con.Connect() 
 
    $server = new-object ("Microsoft.SqlServer.Management.Smo.Server") $con 
    $db = $server.Databases[$Database] 
    $table = new-object ("Microsoft.SqlServer.Management.Smo.Table") $db, $TableName 
 
    foreach ($column in $DataTable.Columns) 
    { 
        $sqlDbType = [Microsoft.SqlServer.Management.Smo.SqlDataType]"$(Get-SqlType $column.DataType.Name)" 
        if ($sqlDbType -eq 'VarBinary' -or $sqlDbType -eq 'VarChar') 
        { 
            if ($MaxLength -gt 0) 
            {$dataType = new-object ("Microsoft.SqlServer.Management.Smo.DataType") "$sqlDbType", $MaxLength}
            else
            { $sqlDbType  = [Microsoft.SqlServer.Management.Smo.SqlDataType]"$(Get-SqlType $column.DataType.Name)Max"
              $dataType = new-object ("Microsoft.SqlServer.Management.Smo.DataType") "$sqlDbType"
            }
        } 
        else 
        { $dataType = new-object ("Microsoft.SqlServer.Management.Smo.DataType") "$sqlDbType" } 
        $col = new-object ("Microsoft.SqlServer.Management.Smo.Column") $table, $column.ColumnName, $dataType 
        $col.Nullable = $column.AllowDBNull 
        $table.Columns.Add($col) 
    } 
 
    if ($AsScript) {
        $table.Script()
    }
    else {
        $table.Create()
    }
}
catch {
    $message = $_.Exception.GetBaseException().Message
    Write-Error $message
}
  
} #Add-SqlTable