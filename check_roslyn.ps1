# Roslyn Language Server Verification Script
Write-Host "=== Roslyn Language Server Verification ===" -ForegroundColor Cyan
Write-Host ""

# Check Neovim version (user reported 0.11.5)
Write-Host "1. Neovim version: 0.11.5 (>= 0.11.0)" -ForegroundColor Green

# Check .NET SDK
Write-Host ""
Write-Host "2. Checking .NET SDK..." -ForegroundColor Yellow
$dotnetVersion = dotnet --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ dotnet $dotnetVersion found" -ForegroundColor Green
} else {
    Write-Host "   ✗ dotnet command not found" -ForegroundColor Red
    Write-Host "     Install from: https://dotnet.microsoft.com/download" -ForegroundColor Gray
}

# Check Roslyn server locations
Write-Host ""
Write-Host "3. Checking Roslyn Language Server..." -ForegroundColor Yellow
$found = $false

# Check Mason location
$masonPath = "$env:LOCALAPPDATA\nvim-data\mason\bin\roslyn.cmd"
if (Test-Path $masonPath) {
    Write-Host "   ✓ Found in Mason: $masonPath" -ForegroundColor Green
    $found = $true
} else {
    Write-Host "   ✗ Not found in Mason: $masonPath" -ForegroundColor Red
}

# Check PATH
$roslynInPath = Get-Command "roslyn.cmd" -ErrorAction SilentlyContinue
if ($roslynInPath) {
    Write-Host "   ✓ Found in PATH: $($roslynInPath.Source)" -ForegroundColor Green
    $found = $true
} else {
    Write-Host "   ✗ Not found in PATH (roslyn.cmd)" -ForegroundColor Red
}

# Check Microsoft.CodeAnalysis.LanguageServer
$langserverInPath = Get-Command "Microsoft.CodeAnalysis.LanguageServer" -ErrorAction SilentlyContinue
if ($langserverInPath) {
    Write-Host "   ✓ Found in PATH: $($langserverInPath.Source)" -ForegroundColor Green
    $found = $true
} else {
    Write-Host "   ✗ Not found in PATH (Microsoft.CodeAnalysis.LanguageServer)" -ForegroundColor Red
}

if (-not $found) {
    Write-Host ""
    Write-Host "=== Installation Required ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "The Roslyn language server is not installed." -ForegroundColor White
    Write-Host ""
    Write-Host "Option 1: Install via Mason (Recommended)" -ForegroundColor Cyan
    Write-Host "  1. Open Neovim" -ForegroundColor Gray
    Write-Host "  2. Run: :Mason" -ForegroundColor Gray
    Write-Host "  3. Search for 'roslyn' and install it" -ForegroundColor Gray
    Write-Host "  4. Or run: :MasonInstall roslyn" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 2: Manual Installation" -ForegroundColor Cyan
    Write-Host "  1. Visit: https://dev.azure.com/azure-public/vside/_artifacts/feed/vs-impl/NuGet/Microsoft.CodeAnalysis.LanguageServer.win-x64/overview" -ForegroundColor Gray
    Write-Host "  2. Download the latest .nupkg file" -ForegroundColor Gray
    Write-Host "  3. Extract it (NuGet packages are ZIP files)" -ForegroundColor Gray
    Write-Host "  4. Add the extracted folder to your PATH" -ForegroundColor Gray
    Write-Host ""
}

Write-Host ""
Write-Host "=== Verification Complete ===" -ForegroundColor Cyan
