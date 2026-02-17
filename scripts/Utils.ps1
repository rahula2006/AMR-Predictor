# scripts\Utils.ps1

function Get-DefaultConfig {
    return [PSCustomObject]@{
        InputFormat = "fasta"
        OutputFormat = "html"
        MinSequenceLength = 100
        MinGCContent = 30
        KmerSize = 21
        MatchThreshold = 0.8
        Threads = 4
        Verbose = $true
    }
}

function Export-Results {
    param(
        [array]$Predictions,
        [string]$OutputPath,
        [string]$Format
    )
    
    switch ($Format) {
        "json" {
            $Predictions | ConvertTo-Json -Depth 3 | Out-File "$OutputPath\predictions.json"
        }
        "xml" {
            $Predictions | Export-Clixml -Path "$OutputPath\predictions.xml"
        }
        "csv" {
            $Predictions | Export-Csv -Path "$OutputPath\predictions.csv" -NoTypeInformation
        }
        default {
            # Already handled by report generator
        }
    }
}