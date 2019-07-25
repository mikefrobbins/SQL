#Requires -Version 3.0
function Convert-MrSqlLogSequenceNumber {

<#
.SYNOPSIS
    Converts a SQL LSN (log sequence number) from a three part hexadecimal number
    format to a decimal based string format.
 
.DESCRIPTION
    Convert-MrSqlLogSequenceNumber is an advanced PowerShell function that converts
    one or more SQL transaction log sequence numbers from a three part hexadecimal
    format that is obtained from querying a transaction log backup or the active
    transaction log to a decimal based string format which can be used to perform
    point in time recovery of a SQL Server database using the StopAtMark option.
 
.PARAMETER LogSequenceNumber
    The three part hexadecimal SQL log sequence number obtained from an insert, update,
    or delete operation that has been recorded in the transaction log or log backup.
 
.EXAMPLE
     Convert-MrSqlLogSequenceNumber -LogSequenceNumber '0000002e:00000158:0001'

.EXAMPLE
     '0000002e:00000158:0001' | Convert-MrSqlLogSequenceNumber

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
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [ValidateScript({
          If ($_ -match '^[0-9A-Fa-f]+:[0-9A-Fa-f]+:[0-9A-Fa-f]+$') {
            $True
          }
          else {
            Throw "$_ is not a valid three part hexadecimal SQL log sequence number from a transaction log backup."
          }
        })]
        [Alias('LSN', 'Current LSN')]
        [string[]]$LogSequenceNumber
    )
    
    PROCESS {
        
        foreach ($Number in $LogSequenceNumber) {
            $i = 1

            $Results = foreach ($n in $Number -split ':') {
                $Int = [convert]::ToInt32($n, 16)
                switch ($i) {
                    1 {$Int; break}
                    2 {"$([string]0*(10-(([string]$Int).Length)))$Int"; break}
                    3 {"$([string]0*(5-(([string]$Int).Length)))$Int"; break}
                    Default {Throw 'An unexpected error has occured.'}
                }
                $i++
            }

            [pscustomobject]@{
                'OriginalLSN' = $Number
                'ConvertedLSN' = $Results -join ''
            }            

        }

    }

}