# scripts\SequenceProcessor.ps1

function Validate-Input {
    param(
        [string]$Path,
        [string]$Format
    )
    
    $files = @()
    
    if (Test-Path $Path -PathType Container) {
        $files = Get-ChildItem -Path $Path -Filter "*.$Format" -Recurse
    } elseif (Test-Path $Path -PathType Leaf) {
        $files = @(Get-Item $Path)
    } else {
        throw "Input path not found: $Path"
    }
    
    if ($files.Count -eq 0) {
        throw "No $Format files found in the specified path"
    }
    
    Write-Host "  Found $($files.Count) files to process"
    return $files
}

function Process-Sequences {
    param(
        [array]$Files,
        [PSCustomObject]$Config
    )
    
    $processedSequences = @()
    $totalFiles = $Files.Count
    $currentFile = 0
    
    foreach ($file in $Files) {
        $currentFile++
        $percentComplete = [math]::Round(($currentFile / $totalFiles) * 100, 2)
        
        Write-Progress -Activity "Processing Sequences" -Status "Processing $($file.Name)" -PercentComplete $percentComplete
        
        try {
            # Read sequence file
            $content = Get-Content $file.FullName -Raw
            
            # Parse based on format
            $sequences = Parse-Sequence -Content $content -Format $Config.InputFormat
            
            # Quality control
            $filteredSequences = $sequences | Where-Object {
                $_.Length -ge $Config.MinSequenceLength -and
                $_.GCContent -ge $Config.MinGCContent
            }
            
            # Add metadata
            foreach ($seq in $filteredSequences) {
                $processedSequences += [PSCustomObject]@{
                    Id = $seq.Id
                    Sequence = $seq.Sequence
                    Length = $seq.Length
                    GCContent = $seq.GCContent
                    SourceFile = $file.Name
                    ProcessingDate = Get-Date
                    QualityScore = $seq.QualityScore
                }
            }
            
            Write-Host "  Processed $($filteredSequences.Count) sequences from $($file.Name)" -ForegroundColor Gray
            
        } catch {
            Write-Warning "Error processing $($file.Name): $_"
        }
    }
    
    Write-Progress -Activity "Processing Sequences" -Completed
    return $processedSequences
}

function Parse-Sequence {
    param(
        [string]$Content,
        [string]$Format
    )
    
    $sequences = @()
    
    switch ($Format) {
        "fasta" {
            # Parse FASTA format
            $currentId = ""
            $currentSeq = ""
            
            $Content -split "`n" | ForEach-Object {
                $line = $_.Trim()
                if ($line -match "^>(.+)") {
                    if ($currentId -ne "") {
                        $sequences += New-SequenceObject -Id $currentId -Sequence $currentSeq
                    }
                    $currentId = $matches[1]
                    $currentSeq = ""
                } else {
                    $currentSeq += $line
                }
            }
            
            if ($currentId -ne "") {
                $sequences += New-SequenceObject -Id $currentId -Sequence $currentSeq
            }
        }
        
        "fastq" {
            # Parse FASTQ format (simplified)
            $lines = $Content -split "`n"
            for ($i = 0; $i -lt $lines.Count; $i += 4) {
                if ($i + 3 -lt $lines.Count) {
                    $id = $lines[$i] -replace "^@", ""
                    $sequence = $lines[$i + 1]
                    $quality = $lines[$i + 3]
                    
                    $sequences += New-SequenceObject -Id $id -Sequence $sequence -Quality $quality
                }
            }
        }
        
        "genbank" {
            # Parse GenBank format (simplified)
            # This would need a proper parser in production
            Write-Warning "GenBank parsing is simplified - use dedicated tools for production"
        }
    }
    
    return $sequences
}

function New-SequenceObject {
    param(
        [string]$Id,
        [string]$Sequence,
        [string]$Quality = ""
    )
    
    $gcContent = Calculate-GCContent -Sequence $Sequence
    $qualityScore = Calculate-QualityScore -Sequence $Sequence -Quality $Quality
    
    return [PSCustomObject]@{
        Id = $Id
        Sequence = $Sequence
        Length = $Sequence.Length
        GCContent = $gcContent
        QualityScore = $qualityScore
    }
}

function Calculate-GCContent {
    param([string]$Sequence)
    
    $gc = ($Sequence.ToUpper() -replace "[^GC]", "").Length
    $total = $Sequence.Length
    
    if ($total -gt 0) {
        return [math]::Round(($gc / $total) * 100, 2)
    }
    return 0
}

function Calculate-QualityScore {
    param(
        [string]$Sequence,
        [string]$Quality
    )
    
    if ($Quality -ne "") {
        # Calculate average quality score from FASTQ
        $scores = $Quality.ToCharArray() | ForEach-Object { [int][char]$_ - 33 }
        return [math]::Round(($scores | Measure-Object -Average).Average, 2)
    }
    
    # Default quality score based on sequence characteristics
    return 100
}