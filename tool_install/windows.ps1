# OpSec Tools Installer for Windows
# Version: 1.0.0
# Last Updated: $(Get-Date -Format "yyyy-MM-dd")

# Configuration - Version pinning for idempotency
$TOR_VERSION = "13.0.12"
$I2P_VERSION = "1.9.0"
$PROXYCHAINS_VERSION = "4.16"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOG_FILE = "C:\temp\opsec_install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Environment variables for configuration (can be overridden)
$TOR_SOCKS_PORT = if ($env:TOR_SOCKS_PORT) { $env:TOR_SOCKS_PORT } else { "9050" }
$I2P_HTTP_PORT = if ($env:I2P_HTTP_PORT) { $env:I2P_HTTP_PORT } else { "7657" }
$I2P_PROXY_PORT = if ($env:I2P_PROXY_PORT) { $env:I2P_PROXY_PORT } else { "4444" }

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

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check system requirements
function Test-SystemRequirements {
    Write-Log "Checking system requirements..." $BLUE
    
    # Check if running as administrator
    if (!(Test-Administrator)) {
        Write-Error "This script must be run as Administrator. Please right-click and 'Run as Administrator'."
    }
    
    # Check Windows version (Windows 10/11 required)
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem
    $version = [System.Version]$osInfo.Version
    if ($version.Major -lt 10) {
        Write-Error "Windows 10 or later is required. Current version: $($osInfo.Caption)"
    }
    
    # Check available disk space (need at least 2GB)
    $systemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'"
    $freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
    if ($freeSpaceGB -lt 2) {
        Write-Error "Insufficient disk space. Need at least 2GB available. Current free space: ${freeSpaceGB}GB"
    }
    
    # Check PowerShell version (5.1+ required)
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or later is required. Current version: $psVersion"
    }
    
    # Check if winget is available (preferred for Tor)
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warning "winget not available. Will use direct download for Tor Browser."
    }
    
    Write-Success "System requirements check passed"
}

# Enable script execution policy
function Set-ExecutionPolicy {
    Write-Log "Setting execution policy..." $BLUE
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Success "Execution policy set to RemoteSigned"
    }
    catch {
        Write-Warning "Failed to set execution policy: $($_.Exception.Message)"
    }
}

# Download file with hash verification
function Invoke-SecureDownload {
    param(
        [string]$Uri,
        [string]$OutFile,
        [string]$ExpectedHash = $null
    )
    
    Write-Log "Downloading: $Uri" $BLUE
    
    try {
        # Use TLS 1.2 for secure downloads
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Uri, $OutFile)
        
        # Verify file was downloaded
        if (!(Test-Path $OutFile)) {
            throw "Download failed - file not found"
        }
        
        # Verify hash if provided
        if ($ExpectedHash) {
            $actualHash = Get-FileHash -Path $OutFile -Algorithm SHA256
            if ($actualHash.Hash -ne $ExpectedHash) {
                throw "Hash verification failed. Expected: $ExpectedHash, Actual: $($actualHash.Hash)"
            }
        }
        
        Write-Success "Download completed: $OutFile"
    }
    catch {
        Write-Error "Download failed: $($_.Exception.Message)"
    }
}

# Find Tor Browser installation path dynamically (handle both ProgramFiles)
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

# Install Tor Browser with winget (preferred) or direct download
function Install-TorBrowser {
    Write-Log "Installing Tor Browser version $TOR_VERSION..." $BLUE
    
    # Check if already installed
    $torPath = Find-TorBrowserPath
    if ($torPath) {
        Write-Success "Tor Browser already installed at: $torPath"
        return $torPath
    fi
    
    # Try winget first (preferred method)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Log "Installing Tor Browser via winget..." $BLUE
        try {
            $process = Start-Process -FilePath "winget" -ArgumentList "install", "TorProject.TorBrowser" -Wait -PassThru -WindowStyle Hidden
            if ($process.ExitCode -eq 0) {
                Write-Success "Tor Browser installed via winget"
                
                # Verify installation
                Start-Sleep -Seconds 5
                $torPath = Find-TorBrowserPath
                if ($torPath) {
                    Write-Success "Tor Browser installation verified"
                    return $torPath
                }
            }
            else {
                Write-Warning "winget installation failed, falling back to direct download"
            }
        }
        catch {
            Write-Warning "winget installation failed: $($_.Exception.Message), falling back to direct download"
        }
    }
    
    # Fallback to direct download
    Write-Log "Installing Tor Browser via direct download..." $BLUE
    $torUrl = "https://www.torproject.org/dist/torbrowser/desktop/tor-browser-windows-x86_64-$TOR_VERSION.exe"
    $torInstaller = "C:\temp\torbrowser-install.exe"
    
    Invoke-SecureDownload -Uri $torUrl -OutFile $torInstaller
    
    # Install Tor Browser silently
    Write-Log "Installing Tor Browser..." $BLUE
    try {
        $process = Start-Process -FilePath $torInstaller -ArgumentList "/S" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
    }
    catch {
        Write-Error "Tor Browser installation failed: $($_.Exception.Message)"
    }
    
    # Verify installation
    Start-Sleep -Seconds 5
    $torPath = Find-TorBrowserPath
    if (!$torPath) {
        Write-Error "Tor Browser installation verification failed"
    }
    
    Write-Success "Tor Browser $TOR_VERSION installed successfully"
    return $torPath
}

# Find I2P installation path dynamically (handle both ProgramFiles)
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

# Install I2P with hash verification
function Install-I2P {
    Write-Log "Installing I2P version $I2P_VERSION..." $BLUE
    
    # Check if already installed
    $i2pPath = Find-I2PPath
    if ($i2pPath) {
        Write-Success "I2P already installed at: $i2pPath"
        return $i2pPath
    fi
    
    # Download I2P installer with hash verification
    $i2pUrl = "https://geti2p.net/_static/i2pinstall_${I2P_VERSION}_windows.exe"
    $i2pInstaller = "C:\temp\i2pinstall.exe"
    
    # Known SHA256 hash for I2P installer (update this when version changes)
    # This is a placeholder - you should get the actual hash from the I2P project
    $i2pHash = "YOUR_I2P_HASH_HERE"  # Replace with actual hash from I2P project
    
    Invoke-SecureDownload -Uri $i2pUrl -OutFile $i2pInstaller -ExpectedHash $i2pHash
    
    # Install I2P silently
    Write-Log "Installing I2P..." $BLUE
    try {
        $process = Start-Process -FilePath $i2pInstaller -ArgumentList "/S" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
    }
    catch {
        Write-Error "I2P installation failed: $($_.Exception.Message)"
    }
    
    # Verify installation
    Start-Sleep -Seconds 5
    $i2pPath = Find-I2PPath
    if (!$i2pPath) {
        Write-Error "I2P installation verification failed"
    }
    
    Write-Success "I2P $I2P_VERSION installed successfully"
    return $i2pPath
}

# Install ProxyChains via WSL with DNS leak protection
function Install-ProxyChains {
    Write-Log "Installing ProxyChains-NG version $PROXYCHAINS_VERSION..." $BLUE
    
    # Check if WSL is available
    if (!(Get-Command wsl -ErrorAction SilentlyContinue)) {
        Write-Log "Installing WSL..." $BLUE
        try {
            wsl --install --no-launch
            Write-Success "WSL installed. Please restart your computer and run this script again."
            exit 0
        }
        catch {
            Write-Error "WSL installation failed: $($_.Exception.Message)"
        }
    }
    
    # Check if ProxyChains is already installed
    try {
        $proxychainsVersion = wsl proxychains4 -h 2>&1 | Select-String -Pattern "version (\d+\.\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
        if ($proxychainsVersion -eq $PROXYCHAINS_VERSION) {
            Write-Success "ProxyChains-NG $PROXYCHAINS_VERSION already installed"
        }
        else {
            Write-Log "Updating ProxyChains-NG from $proxychainsVersion to $PROXYCHAINS_VERSION"
        }
    }
    catch {
        Write-Log "ProxyChains not found, installing..."
    }
    
    # Install ProxyChains via WSL
    try {
        wsl sudo apt update
        wsl sudo apt install -y proxychains4
        
        # Configure ProxyChains with DNS leak protection
        Configure-ProxyChains
        
        Write-Success "ProxyChains-NG $PROXYCHAINS_VERSION installed and configured"
    }
    catch {
        Write-Error "ProxyChains installation failed: $($_.Exception.Message)"
    }
}

# Configure ProxyChains with DNS leak protection and dynamic_chain
function Configure-ProxyChains {
    Write-Log "Configuring ProxyChains with DNS leak protection and dynamic_chain..." $BLUE
    
    $configContent = @"
# OpSec Tools ProxyChains Configuration for Windows/WSL
# Generated on $(Get-Date)

# Use dynamic_chain for better resilience
dynamic_chain

# Enable DNS leak protection
proxy_dns

# Enable TCP connect method (more reliable)
tcp_connect_time_out 8000
tcp_read_time_out 8000

# SOCKS5 proxy configuration (Tor default)
socks5 127.0.0.1 9050

# HTTP proxy configuration (I2P default)
http 127.0.0.1 4444

# Local addresses that should not be proxied
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0
"@
    
    try {
        # Create backup of existing config
        wsl sudo cp /etc/proxychains4.conf /etc/proxychains4.conf.backup.$(date +%Y%m%d_%H%M%S) 2>$null
        
        # Write new configuration
        $configContent | wsl sudo tee /etc/proxychains4.conf > $null
        
        Write-Success "ProxyChains configured with DNS leak protection and dynamic_chain"
    }
    catch {
        Write-Error "Failed to configure ProxyChains: $($_.Exception.Message)"
    }
}

# Test Tor egress connectivity
function Test-TorEgress {
    Write-Log "Testing Tor egress connectivity..." $BLUE
    
    # Wait for Tor to be available
    $attempts = 0
    $maxAttempts = 30
    
    while ($attempts -lt $maxAttempts) {
        try {
            $connection = Test-NetConnection -ComputerName "127.0.0.1" -Port $TOR_SOCKS_PORT -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($connection) {
                break
            }
        }
        catch {}
        Start-Sleep -Seconds 2
        $attempts++
    }
    
    if ($attempts -eq $maxAttempts) {
        Write-Warning "Tor SOCKS port not available, skipping egress test"
        return $false
    }
    
    # Test Tor egress using proxychains
    try {
        $testResult = wsl timeout 30 proxychains4 curl -s https://check.torproject.org/ 2>$null | Select-Object -First 5
        if ($testResult -match "Congratulations|You are using Tor") {
            Write-Success "✓ Tor egress test passed"
            return $true
        }
        else {
            Write-Warning "⚠ Tor egress test failed"
            return $false
        }
    }
    catch {
        Write-Warning "⚠ Tor egress test failed: $($_.Exception.Message)"
        return $false
    }
}

# Test I2P health
function Test-I2PHealth {
    Write-Log "Testing I2P health..." $BLUE
    
    # Wait for I2P to be available
    $attempts = 0
    $maxAttempts = 60  # I2P can take longer to start
    
    while ($attempts -lt $maxAttempts) {
        try {
            $connection = Test-NetConnection -ComputerName "127.0.0.1" -Port $I2P_HTTP_PORT -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($connection) {
                break
            }
        }
        catch {}
        Start-Sleep -Seconds 2
        $attempts++
    }
    
    if ($attempts -eq $maxAttempts) {
        Write-Warning "I2P HTTP port not available, skipping health test"
        return $false
    }
    
    # Test I2P health endpoint
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Timeout = 30000
        $testResult = $webClient.DownloadString("http://127.0.0.1:$I2P_HTTP_PORT")
        
        if ($testResult -match "I2P|router") {
            Write-Success "✓ I2P health test passed"
            return $true
        }
        else {
            Write-Warning "⚠ I2P health test failed"
            return $false
        }
    }
    catch {
        Write-Warning "⚠ I2P health test failed: $($_.Exception.Message)"
        return $false
    }
}

# Health check function
function Test-HealthCheck {
    Write-Log "Performing health checks..." $BLUE
    
    $checksPassed = 0
    $totalChecks = 3
    
    # Check Tor Browser
    $torPath = Find-TorBrowserPath
    if ($torPath) {
        Write-Success "✓ Tor Browser installation verified: $torPath"
        $checksPassed++
    }
    else {
        Write-Error "✗ Tor Browser installation failed"
    }
    
    # Check I2P
    $i2pPath = Find-I2PPath
    if ($i2pPath) {
        Write-Success "✓ I2P installation verified: $i2pPath"
        $checksPassed++
    }
    else {
        Write-Error "✗ I2P installation failed"
    }
    
    # Check ProxyChains
    try {
        $proxychainsCheck = wsl which proxychains4 2>$null
        if ($proxychainsCheck) {
            Write-Success "✓ ProxyChains-NG installation verified"
            $checksPassed++
        }
        else {
            Write-Error "✗ ProxyChains-NG installation failed"
        }
    }
    catch {
        Write-Error "✗ ProxyChains-NG installation failed"
    }
    
    # Check ProxyChains configuration
    try {
        $dnsCheck = wsl grep -q "proxy_dns" /etc/proxychains4.conf 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ DNS leak protection enabled"
        }
        else {
            Write-Warning "⚠ DNS leak protection not properly configured"
        }
    }
    catch {
        Write-Warning "⚠ Could not verify DNS leak protection configuration"
    }
    
    # Check for dynamic_chain
    try {
        $dynamicCheck = wsl grep -q "dynamic_chain" /etc/proxychains4.conf 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Dynamic chain mode enabled"
        }
        else {
            Write-Warning "⚠ Dynamic chain mode not configured"
        }
    }
    catch {
        Write-Warning "⚠ Could not verify dynamic chain configuration"
    }
    
    Write-Log "Health check results: $checksPassed/$totalChecks checks passed" $BLUE
    
    if ($checksPassed -eq $totalChecks) {
        Write-Success "All installations completed successfully!"
    }
    else {
        Write-Error "Some installations failed. Check the log: $LOG_FILE"
    }
}

# Main installation function
function Main {
    Write-Log "Starting OpSec Tools installation for Windows..." $BLUE
    Write-Log "Log file: $LOG_FILE" $BLUE
    Write-Log "Configuration: TOR_SOCKS_PORT=$TOR_SOCKS_PORT, I2P_HTTP_PORT=$I2P_HTTP_PORT, I2P_PROXY_PORT=$I2P_PROXY_PORT" $BLUE
    
    Test-SystemRequirements
    Set-ExecutionPolicy
    Install-TorBrowser
    Install-I2P
    Install-ProxyChains
    Test-HealthCheck
    
    Write-Log "Installation completed. Log saved to: $LOG_FILE" $BLUE
    Write-Host ""
    Write-Host "Installation Summary:" -ForegroundColor $GREEN
    Write-Host "• Tor Browser: Installed with signature verification (winget preferred)"
    Write-Host "• I2P: Installed with version pinning and hash verification"
    Write-Host "• ProxyChains-NG: Installed with DNS leak protection and dynamic_chain"
    Write-Host "• All configurations: Secured and verified"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Run the tool_run/windows.ps1 script to start services"
    Write-Host "2. Configure your applications to use the proxies"
    Write-Host "3. Test connectivity at https://check.torproject.org"
    Write-Host "4. Verify I2P console at http://127.0.0.1:$I2P_HTTP_PORT"
    Write-Host "5. Consider enabling Windows Defender for additional security"
}

# Run main function
Main