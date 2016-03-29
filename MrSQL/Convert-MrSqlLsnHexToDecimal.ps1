function Convert-MrSqlLsnHexToDecimal {

    [cmdletBinding()]
    param (
        [Parameter(Mandatory,
                   ValueFromPipeline)]
        [ValidateScript({
          If ($_ -match '^[0-9A-Fa-f]+:[0-9A-Fa-f]+:[0-9A-Fa-f]+$') {
            $True
          }
          else {
            Throw "$_ is not a valid three part hexadecimal SQL log sequence number from a transaction log dump."
          }
        })]
        [string[]]$LSN
    )
    
    PROCESS {
        
        foreach ($Number in $LSN) {
            $i = 1

            $Results = foreach ($n in $Number -split ':') {
                $Hex = [convert]::ToInt32($n, 16)
                switch ($i) {
                    1 {$Hex; break}
                    2 {"$([string]0*(10-(([string]$Hex).Length)))$Hex"; break}
                    3 {"$([string]0*(5-(([string]$Hex).Length)))$Hex"; break}
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