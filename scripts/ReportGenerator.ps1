# scripts\ReportGenerator.ps1
function Generate-Report {
    param(
        [array]$Predictions,
        [string]$OutputPath,
        [PSCustomObject]$Config
    )
    
    # Debug: see how many predictions we receive
    Write-Host "Debug: Generate-Report received $($Predictions.Count) predictions" -ForegroundColor Magenta
    
    # Detailed debug of the first prediction
    if ($Predictions.Count -gt 0) {
        $first = $Predictions[0]
        Write-Host "Debug: First prediction properties:" -ForegroundColor Magenta
        $first.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name) = $($_.Value)" -ForegroundColor Magenta
        }
    }
    
    # Manual calculation to avoid pipeline issues
    $samplesWithResistance = 0
    $highRisk = 0
    $mediumRisk = 0
    $lowRisk = 0
    foreach ($p in $Predictions) {
        if ($p.TotalGenes -gt 0) { $samplesWithResistance++ }
        if ($p.RiskLevel -eq "HIGH") { $highRisk++ }
        elseif ($p.RiskLevel -eq "MEDIUM") { $mediumRisk++ }
        elseif ($p.RiskLevel -eq "LOW") { $lowRisk++ }
    }
    
    # Debug: show manual counts
    Write-Host "Debug: Manual counts - HIGH: $highRisk, MEDIUM: $mediumRisk, LOW: $lowRisk" -ForegroundColor Magenta
    
    # Create summary statistics
    $summary = [PSCustomObject]@{
        TotalSamples = $Predictions.Count
        SamplesWithResistance = $samplesWithResistance
        HighRiskSamples = $highRisk
        MediumRiskSamples = $mediumRisk
        LowRiskSamples = $lowRisk
        MostCommonGenes = Get-MostCommonGenes -Predictions $Predictions
        AnalysisDate = Get-Date
        ConfigUsed = $Config
    }
    
    # Debug: show computed value
    Write-Host "Debug: Summary SamplesWithResistance = $($summary.SamplesWithResistance)" -ForegroundColor Magenta
    Write-Host "Debug: Summary LowRiskSamples = $($summary.LowRiskSamples)" -ForegroundColor Magenta
    
    # Generate HTML report
    $htmlReport = Generate-HTMLReport -Predictions $Predictions -Summary $summary
    $htmlReport | Out-File "$OutputPath\AMR_Report_$(Get-Date -Format 'yyyyMMdd').html"
    
    # Generate CSV for data analysis
    Export-AnalysisData -Predictions $Predictions -OutputPath $OutputPath
    
    return $summary
}

function Get-MostCommonGenes {
    param([array]$Predictions)
    
    $geneCount = @{}
    
    foreach ($pred in $Predictions) {
        if ($pred.TotalGenes -gt 0) {
            # Extract genes from matches (would need proper parsing)
            # Simplified version
        }
    }
    
    return $geneCount
}

function Generate-HTMLReport {
    param(
        [array]$Predictions,
        [PSCustomObject]$Summary
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>AMR Prediction Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        h2 { color: #34495e; }
        .summary { background-color: #ecf0f1; padding: 15px; border-radius: 5px; }
        .high-risk { color: #e74c3c; font-weight: bold; }
        .medium-risk { color: #e67e22; font-weight: bold; }
        .low-risk { color: #f1c40f; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #3498db; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Antimicrobial Resistance Prediction Report</h1>
    <p>Generated: $(Get-Date)</p>
    
    <div class="summary">
        <h2>Summary Statistics</h2>
        <p>Total Samples Analyzed: $($Summary.TotalSamples)</p>
        <p>Samples with Resistance Genes: $($Summary.SamplesWithResistance)</p>
        <p>High Risk Samples: <span class="high-risk">$($Summary.HighRiskSamples)</span></p>
        <p>Medium Risk Samples: <span class="medium-risk">$($Summary.MediumRiskSamples)</span></p>
        <p>Low Risk Samples: <span class="low-risk">$($Summary.LowRiskSamples)</span></p>
    </div>
    
    <h2>Detailed Results</h2>
    <table>
        <tr>
            <th>Sample ID</th>
            <th>Source File</th>
            <th>Risk Level</th>
            <th>Detected Genes</th>
            <th>Resistance Profile</th>
        </tr>
"@
    
    foreach ($pred in $Predictions) {
        $riskClass = switch ($pred.RiskLevel) {
            "HIGH" { "high-risk" }
            "MEDIUM" { "medium-risk" }
            "LOW" { "low-risk" }
            default { "" }
        }
        
        $genes = if ($pred.TotalGenes -gt 0) {
            # This would need proper gene list - simplified for now
            "Multiple genes detected"
        } else { "None detected" }
        
        $profile = if ($pred.ResistanceProfile) {
            ($pred.ResistanceProfile.Keys | ForEach-Object { "$_ ($($pred.ResistanceProfile[$_].Confidence)%)" }) -join "<br>"
        } else { "None" }
        
        $html += @"
        <tr>
            <td>$($pred.SequenceId)</td>
            <td>$($pred.SourceFile)</td>
            <td class="$riskClass">$($pred.RiskLevel)</td>
            <td>$genes</td>
            <td>$profile</td>
        </tr>
"@
    }
    
    $html += @"
    </table>
</body>
</html>
"@
    
    return $html
}

function Export-AnalysisData {
    param(
        [array]$Predictions,
        [string]$OutputPath
    )
    
    $exportData = @()
    
    foreach ($pred in $Predictions) {
        $exportData += [PSCustomObject]@{
            SampleID = $pred.SequenceId
            SourceFile = $pred.SourceFile
            RiskLevel = $pred.RiskLevel
            TotalGenes = $pred.TotalGenes
            PredictionDate = $pred.PredictionDate
        }
    }
    
    $exportData | Export-Csv -Path "$OutputPath\amr_predictions.csv" -NoTypeInformation
}

function Show-Summary {
    param(
        [array]$Predictions,
        [PSCustomObject]$Report
    )
    
    Write-Host "`n" + "="*50 -ForegroundColor Cyan
    Write-Host "ANALYSIS SUMMARY" -ForegroundColor Cyan
    Write-Host "="*50 -ForegroundColor Cyan
    
    Write-Host "`nSamples Analyzed: $($Report.TotalSamples)" -ForegroundColor White
    Write-Host "Resistance Detected: $($Report.SamplesWithResistance)" -ForegroundColor White
    Write-Host "`nRisk Distribution:" -ForegroundColor White
    Write-Host "  HIGH: $($Report.HighRiskSamples)" -ForegroundColor Red
    Write-Host "  MEDIUM: $($Report.MediumRiskSamples)" -ForegroundColor Yellow
    Write-Host "  LOW: $($Report.LowRiskSamples)" -ForegroundColor Green
}