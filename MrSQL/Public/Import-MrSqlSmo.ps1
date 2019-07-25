#Requires -Version 3.0
function Import-MrSqlSmo {

<#
.SYNOPSIS
    Imports the SQL Server SMO Assembly.
 
.DESCRIPTION
    Import-MrSqlSmo is an advanced function that imports the SQL Server SMO (SQL Management Objects) Assembly.
 
.PARAMETER PassThru
    Return the information for the SQL SMO assembly that was loaded.
 
.EXAMPLE
     Import-MrSqlSmo

.EXAMPLE
     Import-MrSqlSmo -PassThru

.INPUTS
    None
 
.OUTPUTS
    None
 
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>

    [CmdletBinding()]
    param (
        [switch]$PassThru
    )

    $SmoPath = "$env:windir\assembly\GAC_MSIL\Microsoft.SqlServer.Smo"
    $PreAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()

    if ($PreAssemblies.ManifestModule.Name -contains 'Microsoft.SqlServer.Smo.dll') {
        Write-Verbose -Message 'Aborting: SMO has already been loaded.'
        Break
    }
    elseif (Test-Path -Path $SmoPath -PathType Container) {
        Write-Verbose -Message "Path: '$SmoPath' successfully validated."

        $SmoDllPath = "$((Get-ChildItem -Path $SmoPath |
        Sort-Object -Property Name -Descending |
        Select-Object -First 1 -OutVariable SmoVersionPath).FullName)\Microsoft.SqlServer.Smo.dll"
    }
    else {
        Write-Warning -Message "Unable to find SMO DLL"
        Break
    }

    try {
        $SmoVersion = $SmoVersionPath.Name -split '__'
        Write-Verbose -Message "Attempting to load SMO Version: $($SmoVersion[0]) with PublicKeyToken: $($SmoVersion[1])"

        Add-Type -Path $SmoDllPath -ErrorAction Stop
    }
    catch {
        Write-Warning -Message $_.Exception.Message
        Break
    }

    if ($PSBoundParameters.PassThru -or $PSBoundParameters.Verbose) {
        $PostAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()

        if ($PostAssemblies.ManifestModule.Name -contains 'Microsoft.SqlServer.Smo.dll') {
            Write-Verbose -Message "SMO successfully loaded."
        }
        
        if ($PSBoundParameters.PassThru) {
            Compare-Object -ReferenceObject $PreAssemblies -DifferenceObject $PostAssemblies |
            Where-Object {$_.SideIndicator -eq '=>' -and $_.InputObject.ManifestModule -match 'SqlServer'} |
            Select-Object -ExpandProperty InputObject
        }
        
    } 
    
}