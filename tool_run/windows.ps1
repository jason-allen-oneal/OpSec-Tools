# OpSec Tools Runner for Windows
# Version: 1.0.0
# Last Updated: $(Get-Date -Format "yyyy-MM-dd")

# Configuration
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOG_FILE = "C:\temp\opsec_run_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$TOR_SOCKS_PORT = "9050"
$I2P_HTTP_PORT = "4444"
$I2P_SOCKS_PORT = "4447"

# Ensure temp directory exists
if (!(Test-Path "C:\temp")) {
    New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
}

# Colors for output
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$BLUE = "Blue"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $LOG_FILE -Value $logMessage
}

function Write-Error {
    param([string]$Message)
    Write-Log "[ERROR] $Message" $RED
    exit 1
}

function Write-Success {
    param([string]$Message)
    Write-Log "[SUCCESS] $Message" $GREEN
}

function Write-Warning {
    param([string]$Message)
    Write-Log "[WARNING] $Message" $YELLOW
}

# Find Tor Browser installation path dynamically
function Find-TorBrowserPath {
    $possiblePaths = @(
        "${env:ProgramFiles}\Tor Browser\Browser\firefox.exe",
        "${env:ProgramFiles(x86)}\Tor Browser\Browser\firefox.exe",
        "${env:LOCALAPPDATA}\Tor Browser\Browser\firefox.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Find I2P installation path dynamically
function Find-I2PPath {
    $possiblePaths = @(
        "${env:ProgramFiles}\I2P\i2prouter.exe",
        "${env:ProgramFiles(x86)}\I2P\i2prouter.exe",
        "${env:LOCALAPPDATA}\I2P\i2prouter.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    return $null
}

# Check if services are installed
function Test-Installations {
    Write-Log "Checking tool installations..." $BLUE
    
    $missingTools = @()
    
    $torPath = Find-TorBrowserPath
    if (!$torPath) {
        $missingTools += "Tor Browser"
    }
    
    $i2pPath = Find-I2PPath
    if (!$i2pPath) {
        $missingTools += "I2P"
    }
    
    # Check ProxyChains via WSL
    try {
        $proxychainsCheck = wsl which proxychains4 2>$null
        if (!$proxychainsCheck) {
            $missingTools += "ProxyChains-NG"
        }
    }
    catch {
        $missingTools += "ProxyChains-NG (WSL not available)"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Error "Missing tools: $($missingTools -join ', '). Please run the installation script first."
    }
    
    Write-Success "All tools are installed"
}

# Check if port is listening
function Test-Port {
    param([string]$Port, [string]$Service)
    
    try {
        $connection = Test-NetConnection -ComputerName "127.0.0.1" -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($connection) {
            Write-Success "✓ $Service is listening on port $Port"
            return $true
        }
        else {
            Write-Warning "⚠ $Service is not listening on port $Port"
            return $false
        }
    }
    catch {
        Write-Warning "⚠ $Service is not listening on port $Port"
        return $false
    }
}

# Test Tor connectivity
function Test-TorConnectivity {
    Write-Log "Testing Tor connectivity..." $BLUE
    
    # Check if Tor SOCKS port is listening
    if (!(Test-Port $TOR_SOCKS_PORT "Tor")) {
        Write-Warning "Tor SOCKS proxy not available"
        return $false
    }
    
    # Test Tor connectivity using PowerShell
    $torTestUrl = "https://check.torproject.org"
    
    try {
        # Use .NET WebClient with SOCKS proxy (basic test)
        $webClient = New-Object System.Net.WebClient
        $webClient.Proxy = New-Object System.Net.WebProxy("socks5://127.0.0.1:$TOR_SOCKS_PORT")
        $webClient.Timeout = 10000
        
        $testResult = $webClient.DownloadString($torTestUrl)
        
        if ($testResult -match "Congratulations") {
            Write-Success "✓ Tor connectivity test passed"
            return $true
        }
        else {
            Write-Warning "⚠ Tor connectivity test failed"
            return $false
        }
    }
    catch {
        Write-Warning "⚠ Tor connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test I2P connectivity
function Test-I2PConnectivity {
    Write-Log "Testing I2P connectivity..." $BLUE
    
    # Check if I2P HTTP port is listening
    if (!(Test-Port $I2P_HTTP_PORT "I2P HTTP")) {
        Write-Warning "I2P HTTP proxy not available"
        return $false
    }
    
    # Check if I2P SOCKS port is listening
    if (!(Test-Port $I2P_SOCKS_PORT "I2P SOCKS")) {
        Write-Warning "I2P SOCKS proxy not available"
        return $false
    }
    
    # Test I2P connectivity
    $i2pTestUrl = "http://127.0.0.1:$I2P_HTTP_PORT"
    
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Proxy = New-Object System.Net.WebProxy("http://127.0.0.1:$I2P_HTTP_PORT")
        $webClient.Timeout = 10000
        
        $testResult = $webClient.DownloadString($i2pTestUrl)
        
        if ($testResult -match "I2P") {
            Write-Success "✓ I2P connectivity test passed"
            return $true
        }
        else {
            Write-Warning "⚠ I2P connectivity test failed"
            return $false
        }
    }
    catch {
        Write-Warning "⚠ I2P connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

# Start Tor Browser
function Start-TorBrowser {
    Write-Log "Starting Tor Browser..." $BLUE
    
    # Check if Tor Browser is already running
    $torProcesses = Get-Process -Name "firefox" -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "firefox" }
    if ($torProcesses) {
        Write-Success "Tor Browser is already running"
        return $true
    }
    
    # Find Tor Browser path
    $torPath = Find-TorBrowserPath
    if (!$torPath) {
        Write-Error "Tor Browser not found. Please install it first."
    }
    
    # Start Tor Browser
    try {
        Start-Process -FilePath $torPath -ArgumentList "--new-instance" -WindowStyle Normal
        Write-Log "Tor Browser launch command sent"
        
        # Wait a moment for Tor to start
        Start-Sleep -Seconds 5
        
        # Check if Tor Browser process is running
        $torProcesses = Get-Process -Name "firefox" -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "firefox" }
        if ($torProcesses) {
            Write-Success "Tor Browser started successfully"
            return $true
        }
        else {
            Write-Warning "Tor Browser may still be starting up"
            return $false
        }
    }
    catch {
        Write-Error "Failed to start Tor Browser: $($_.Exception.Message)"
    }
}

# Start I2P router
function Start-I2PRouter {
    Write-Log "Starting I2P router..." $BLUE
    
    # Check if I2P is already running
    $i2pProcesses = Get-Process -Name "i2prouter" -ErrorAction SilentlyContinue
    if ($i2pProcesses) {
        Write-Success "I2P router is already running"
        return $true
    }
    
    # Find I2P path
    $i2pPath = Find-I2PPath
    if (!$i2pPath) {
        Write-Error "I2P not found. Please install it first."
    }
    
    # Start I2P router
    try {
        Start-Process -FilePath $i2pPath -WindowStyle Normal
        Write-Log "I2P router launch command sent"
        
        # Wait for I2P to start (it can take a while)
        Write-Log "Waiting for I2P router to initialize..."
        $attempts = 0
        $maxAttempts = 30
        
        while ($attempts -lt $maxAttempts) {
            if (Test-Port $I2P_HTTP_PORT "I2P HTTP") {
                Write-Success "I2P router started successfully"
                return $true
            }
            Start-Sleep -Seconds 2
            $attempts++
        }
        
        Write-Warning "I2P router may still be starting up (timeout reached)"
        return $false
    }
    catch {
        Write-Error "Failed to start I2P router: $($_.Exception.Message)"
    }
}

# Test ProxyChains configuration
function Test-ProxyChains {
    Write-Log "Testing ProxyChains configuration..." $BLUE
    
    # Check if ProxyChains config has DNS leak protection
    try {
        $dnsCheck = wsl grep -q "proxy_dns" /etc/proxychains4.conf 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ ProxyChains DNS leak protection enabled"
        }
        else {
            Write-Warning "⚠ ProxyChains DNS leak protection not configured"
        }
    }
    catch {
        Write-Warning "⚠ Could not verify ProxyChains DNS leak protection configuration"
    }
    
    # Test ProxyChains with a simple command
    try {
        $testResult = wsl timeout 10 proxychains4 curl -s --connect-timeout 5 --max-time 10 "https://httpbin.org/ip" 2>$null
        if ($testResult -match "origin") {
            Write-Success "✓ ProxyChains connectivity test passed"
            return $true
        }
        else {
            Write-Warning "⚠ ProxyChains connectivity test failed"
            return $false
        }
    }
    catch {
        Write-Warning "⚠ ProxyChains connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

# Display service status
function Show-Status {
    Write-Log "Service Status Summary:" $BLUE
    Write-Host ""
    Write-Host "=== Service Status ===" -ForegroundColor $BLUE
    
    # Tor status
    $torProcesses = Get-Process -Name "firefox" -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq "firefox" }
    if ($torProcesses) {
        Write-Host "✓ Tor Browser: Running" -ForegroundColor $GREEN
    }
    else {
        Write-Host "✗ Tor Browser: Not running" -ForegroundColor $RED
    }
    
    # I2P status
    $i2pProcesses = Get-Process -Name "i2prouter" -ErrorAction SilentlyContinue
    if ($i2pProcesses) {
        Write-Host "✓ I2P Router: Running" -ForegroundColor $GREEN
    }
    else {
        Write-Host "✗ I2P Router: Not running" -ForegroundColor $RED
    }
    
    # Port status
    Write-Host ""
    Write-Host "=== Port Status ===" -ForegroundColor $BLUE
    if (!(Test-Port $TOR_SOCKS_PORT "Tor SOCKS")) {
        Write-Host "✗ Tor SOCKS (port $TOR_SOCKS_PORT): Not listening" -ForegroundColor $RED
    }
    if (!(Test-Port $I2P_HTTP_PORT "I2P HTTP")) {
        Write-Host "✗ I2P HTTP (port $I2P_HTTP_PORT): Not listening" -ForegroundColor $RED
    }
    if (!(Test-Port $I2P_SOCKS_PORT "I2P SOCKS")) {
        Write-Host "✗ I2P SOCKS (port $I2P_SOCKS_PORT): Not listening" -ForegroundColor $RED
    }
    
    Write-Host ""
    Write-Host "=== Usage Examples ===" -ForegroundColor $BLUE
    Write-Host "• Tor Browser: Already started"
    Write-Host "• I2P Console: http://127.0.0.1:$I2P_HTTP_PORT"
    Write-Host "• Test Tor: Use Tor Browser to visit https://check.torproject.org"
    Write-Host "• Test I2P: Visit http://127.0.0.1:$I2P_HTTP_PORT"
    Write-Host "• Use ProxyChains: wsl proxychains4 your_command"
}

# Health check function
function Test-HealthCheck {
    Write-Log "Performing health checks..." $BLUE
    
    $checksPassed = 0
    $totalChecks = 3
    
    # Test Tor connectivity
    if (Test-TorConnectivity) {
        $checksPassed++
    }
    
    # Test I2P connectivity
    if (Test-I2PConnectivity) {
        $checksPassed++
    }
    
    # Test ProxyChains
    if (Test-ProxyChains) {
        $checksPassed++
    }
    
    Write-Log "Health check results: $checksPassed/$totalChecks checks passed" $BLUE
    
    if ($checksPassed -eq $totalChecks) {
        Write-Success "All services are running and accessible!"
    }
    else {
        Write-Warning "Some services may not be fully operational"
    }
}

# Main function
function Main {
    Write-Log "Starting OpSec Tools for Windows..." $BLUE
    Write-Log "Log file: $LOG_FILE" $BLUE
    
    Test-Installations
    Start-TorBrowser
    Start-I2PRouter
    Test-HealthCheck
    Show-Status
    
    Write-Log "OpSec Tools started. Log saved to: $LOG_FILE" $BLUE
    Write-Host ""
    Write-Host "OpSec Tools are now running!" -ForegroundColor $GREEN
    Write-Host "• Tor Browser: Check for the browser window"
    Write-Host "• I2P Console: http://127.0.0.1:$I2P_HTTP_PORT"
    Write-Host "• ProxyChains: Use 'wsl proxychains4 your_command' to route traffic through Tor/I2P"
    Write-Host ""
    Write-Host "Press Ctrl+C to stop all services"
    
    # Keep script running and handle cleanup
    try {
        while ($true) {
            Start-Sleep -Seconds 1
        }
    }
    catch {
        Write-Log "Stopping OpSec Tools..." $BLUE
        Get-Process -Name "firefox" -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name "i2prouter" -ErrorAction SilentlyContinue | Stop-Process -Force
        exit 0
    }
}

# Run main function
Main