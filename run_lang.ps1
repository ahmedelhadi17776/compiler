# Script to compile and run a source file for the custom language.
#
# Usage:
#   ./run_lang.ps1 <path_to_source_file>
#
# Example:
#   ./run_lang.ps1 test.txt

param (
    [string]$sourceFile
)

if (-not $sourceFile) {
    Write-Host "Error: Please provide a source file to compile."
    Write-Host "Usage: ./run_lang.ps1 <path_to_source_file>"
    exit 1
}

if (-not (Test-Path $sourceFile)) {
    Write-Host "Error: Source file not found at '$sourceFile'"
    exit 1
}

$outputDir = "out"
$cOutputFile = "$outputDir/output.c"
$exeOutputFile = "$outputDir/output.exe"

# Create output directory if it doesn't exist
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir
}

Write-Host "--- 1. Compiling your language file: $sourceFile ---"
./my_compiler.exe $sourceFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "Compiler failed. Aborting."
    exit 1
}

# Move the generated C file to the output directory
Move-Item -Path "output.c" -Destination $cOutputFile -Force

Write-Host "--- 2. Compiling generated C code ---"
gcc $cOutputFile -o $exeOutputFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "GCC compilation failed. Aborting."
    exit 1
}

Write-Host "--- 3. Running the compiled program ---"
Write-Host "----------------- Program Output -----------------"
& $exeOutputFile
Write-Host "--------------------------------------------------"

Write-Host "--- Script finished successfully! ---"
