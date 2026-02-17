# AMR-Predictor.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("fasta","fastq","genbank")]
    [string]$InputFormat = "fasta",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\results",
    
    [Parameter(Mandatory=$false)]
    [string]$ReferenceDB = ".\data\reference\amr_genes.db",
    
    [Parameter(Mandatory=$false)]
    [switch]$TrainModel,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = ".\config\settings.json"
)

# Import modules
. .\scripts\SequenceProcessor.ps1
. .\scripts\AMRAnalyzer.ps1
. .\scripts\ReportGenerator.ps1
. .\scripts\ModelTrainer.ps1
. .\scripts\Utils.ps1

# Initialize logging
$logFile = ".\logs\amr_predictor_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logFile

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                 AMR-Predictor v1.0                           ║
║         Antimicrobial Resistance Prediction Tool              ║
║              Industrial Bioinformatics Solution               ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

try {
    # Load configuration
    $config = if (Test-Path $ConfigFile) {
        Get-Content $ConfigFile | ConvertFrom-Json
    } else {
        Get-DefaultConfig
    }
    
    Write-Host "`n[1/6] Validating input..." -ForegroundColor Yellow
    $validatedFiles = Validate-Input -Path $InputPath -Format $InputFormat
    
    Write-Host "[2/6] Processing sequences..." -ForegroundColor Yellow
    $processedSequences = Process-Sequences -Files $validatedFiles -Config $config
    
    Write-Host "[3/6] Analyzing AMR genes..." -ForegroundColor Yellow
    $amrResults = Analyze-AMRGenes -Sequences $processedSequences -ReferenceDB $ReferenceDB -Config $config
    
    Write-Host "[4/6] Predicting resistance patterns..." -ForegroundColor Yellow
    $predictions = Predict-Resistance -AMRResults $amrResults -Config $config
    
    Write-Host "[5/6] Generating comprehensive report..." -ForegroundColor Yellow
    $report = Generate-Report -Predictions $predictions -OutputPath $OutputPath -Config $config
    
    Write-Host "[6/6] Exporting results..." -ForegroundColor Yellow
    Export-Results -Predictions $predictions -OutputPath $OutputPath -Format $config.OutputFormat
    
    # Display summary
    Show-Summary -Predictions $predictions -Report $report
    
    Write-Host "`n✓ AMR-Predictor completed successfully!" -ForegroundColor Green
    Write-Host "  Results saved to: $OutputPath" -ForegroundColor Green
    Write-Host "  Log file: $logFile" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
    Write-Host "  Error details:" -ForegroundColor Red
    Write-Host "  Line: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Yellow
    Write-Host "  Line Number: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "  Script Stack Trace:" -ForegroundColor Cyan
    $_.ScriptStackTrace
    Write-Host "  Check log file: $logFile" -ForegroundColor Red
}
