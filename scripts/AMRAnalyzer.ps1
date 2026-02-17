# scripts\AMRAnalyzer.ps1

function Analyze-AMRGenes {
    param(
        [array]$Sequences,
        [string]$ReferenceDB,
        [PSCustomObject]$Config
    )
    
    Write-Host "  Loading reference database..."
    $referenceGenes = Load-ReferenceDatabase -Path $ReferenceDB
    
    $results = @()
    $totalSeqs = $Sequences.Count
    $currentSeq = 0
    
    foreach ($sequence in $Sequences) {
        $currentSeq++
        $percentComplete = [math]::Round(($currentSeq / $totalSeqs) * 100, 2)
        
        Write-Progress -Activity "AMR Gene Analysis" -Status "Analyzing $($sequence.Id)" -PercentComplete $percentComplete
        
        $foundMatches = Find-AMRMatches -Sequence $sequence.Sequence -References $referenceGenes -Config $Config
        
        if ($foundMatches.Count -gt 0) {
            $results += [PSCustomObject]@{
                SequenceId = $sequence.Id
                SourceFile = $sequence.SourceFile
                Matches = $foundMatches
                MatchCount = $foundMatches.Count
                AnalysisDate = Get-Date
            }
        }
    }
    
    Write-Progress -Activity "AMR Gene Analysis" -Completed
    return $results
}

function Load-ReferenceDatabase {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Host "  Reference database not found. Creating minimal database..." -ForegroundColor Yellow
        return Create-MinimalReferenceDB
    }
    
    try {
        $db = Import-Csv $Path
        # Ensure sequences are clean (remove any line breaks or extra spaces)
        foreach ($gene in $db) {
            $gene.Sequence = $gene.Sequence -replace "`n|`r| ", ""
        }
        Write-Host "  Loaded $($db.Count) reference genes" -ForegroundColor Gray
        return $db
    } catch {
        Write-Warning "Error loading reference database: $_"
        return Create-MinimalReferenceDB
    }
}

function Create-MinimalReferenceDB {
    # Create a minimal reference database with common AMR genes
    $minimalDB = @(
        [PSCustomObject]@{
            GeneId = "blaCTX-M-15"
            Family = "Beta-lactamase"
            Resistance = "Cephalosporins"
            Sequence = "ATGGTTAAAAAATCACTGCGTCAGTTCACGCTGATGGCGACGGCAACCGTCACG"
            Confidence = 0.95
        },
        [PSCustomObject]@{
            GeneId = "mecA"
            Family = "PBP2a"
            Resistance = "Methicillin"
            Sequence = "AAAAATGATGGTAAAAGGTTGGCAAAGATATCAACATAACCGAAAATACTG"
            Confidence = 0.98
        },
        [PSCustomObject]@{
            GeneId = "vanA"
            Family = "Vancomycin resistance"
            Resistance = "Vancomycin"
            Sequence = "ATGAATAGAATAAAAGTTGCAATACTGTTTGGGGGTTACTCACGGGTCATC"
            Confidence = 0.97
        },
        [PSCustomObject]@{
            GeneId = "NDM-1"
            Family = "Carbapenemase"
            Resistance = "Carbapenems"
            Sequence = "ATGGAATTGCCCAATATTATGCACCCGGTCGCGAAGCTTCAGCACAGAC"
            Confidence = 0.96
        }
    )
    
    # Save to file for future use
    $minimalDB | Export-Csv -Path ".\data\reference\amr_genes_minimal.csv" -NoTypeInformation
    
    return $minimalDB
}

function Find-AMRMatches {
    param(
        [string]$Sequence,
        [array]$References,
        [PSCustomObject]$Config
    )
    
    $matchedGenes = @()
    $sequence = $sequence.ToUpper()
    
    # Debug output: show first 60 chars of the sequence being checked
    Write-Host "Debug: Checking sequence (first 60 chars): $($sequence.Substring(0, [Math]::Min(60, $sequence.Length)))" -ForegroundColor DarkYellow
    
    foreach ($ref in $References) {
        $refSeq = $ref.Sequence.ToUpper()
        Write-Host "Debug: Looking for reference: $refSeq" -ForegroundColor DarkYellow
        
        # Use .Contains() for simple substring matching (avoid regex issues)
        if ($sequence.Contains($refSeq)) {
            $match = [PSCustomObject]@{
                GeneId = $ref.GeneId
                Family = $ref.Family
                Resistance = $ref.Resistance
                MatchLength = $refSeq.Length
                Position = $sequence.IndexOf($refSeq)
                Confidence = $ref.Confidence
            }
            $matchedGenes += $match
            Write-Host "Debug: Match found for $($ref.GeneId)!" -ForegroundColor Green
        }
    }
    
    return $matchedGenes
}

function Get-Kmers {
    param(
        [string]$Sequence,
        [int]$K = 21
    )
    
    $kmers = @()
    
    for ($i = 0; $i -le $Sequence.Length - $K; $i++) {
        $kmers += $Sequence.Substring($i, $K)
    }
    
    return $kmers | Select-Object -Unique
}

function Predict-Resistance {
    param(
        [array]$AMRResults,
        [PSCustomObject]$Config
    )
    
    Write-Host "  Predicting resistance patterns based on detected genes..."
    
    # Debug: show how many results we received
    Write-Host "Debug: Predict-Resistance received $($AMRResults.Count) result(s)" -ForegroundColor Cyan
    if ($AMRResults.Count -gt 0) {
        Write-Host "Debug: First result has MatchCount = $($AMRResults[0].MatchCount)" -ForegroundColor Cyan
    }
    
    $predictions = @()
    
    foreach ($result in $AMRResults) {
        Write-Host "Debug: Processing result for $($result.SequenceId) with $($result.MatchCount) matches" -ForegroundColor Cyan
        
        $resistanceProfile = @{}
        
        foreach ($match in $result.Matches) {
            $drugs = $match.Resistance -split ", "
            foreach ($drug in $drugs) {
                # Initialize if not exists
                if (-not $resistanceProfile.ContainsKey($drug)) {
                    $resistanceProfile[$drug] = @{
                        Count = 0
                        Genes = @()
                    }
                }
                $resistanceProfile[$drug].Count++
                $resistanceProfile[$drug].Genes += $match.GeneId
            }
        }
        
        # Calculate confidence scores
        $totalGenes = $result.MatchCount
        foreach ($drug in $resistanceProfile.Keys) {
            $confidence = if ($totalGenes -gt 0) { [math]::Round(($resistanceProfile[$drug].Count / $totalGenes) * 100, 2) } else { 0 }
            $resistanceProfile[$drug].Confidence = $confidence
        }
        
        $predictions += [PSCustomObject]@{
            SequenceId = $result.SequenceId
            SourceFile = $result.SourceFile
            ResistanceProfile = $resistanceProfile
            TotalGenes = $totalGenes
            PredictionDate = Get-Date
            RiskLevel = Get-RiskLevel -Profile $resistanceProfile
        }
        
        Write-Host "Debug: Added prediction with TotalGenes = $totalGenes" -ForegroundColor Cyan
    }
    
    Write-Host "Debug: Predict-Resistance returning $($predictions.Count) prediction(s)" -ForegroundColor Cyan
    return $predictions
}

function Get-RiskLevel {
    param([hashtable]$Profile)
    
    $highRiskDrugs = @("Carbapenems", "Vancomycin", "Colistin")
    $mediumRiskDrugs = @("Cephalosporins", "Fluoroquinolones", "Aminoglycosides")
    
    $highRiskCount = 0
    $mediumRiskCount = 0
    
    foreach ($drug in $Profile.Keys) {
        if ($drug -in $highRiskDrugs) {
            $highRiskCount++
        } elseif ($drug -in $mediumRiskDrugs) {
            $mediumRiskCount++
        }
    }
    
    if ($highRiskCount -gt 0) {
        return "HIGH"
    } elseif ($mediumRiskCount -gt 2) {
        return "MEDIUM"
    } elseif ($mediumRiskCount -gt 0) {
        return "LOW"
    } else {
        return "NEGLIGIBLE"
    }
}