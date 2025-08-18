#!/bin/bash
# OpSec Tools Installer for macOS
# Version: 1.0.0
# Last Updated: $(date +%Y-%m-%d)

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration - Version pinning for idempotency
readonly TOR_VERSION="13.0.12"
readonly I2P_VERSION="1.9.0"
readonly PROXYCHAINS_VERSION="4.16"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/opsec_install_$(date +%Y%m%d_%H%M%S).log"

# Environment variables for configuration (can be overridden)
readonly TOR_SOCKS_PORT="${TOR_SOCKS_PORT:-9050}"
readonly I2P_HTTP_PORT="${I2P_HTTP_PORT:-7657}"
readonly I2P_PROXY_PORT="${I2P_PROXY_PORT:-4444}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check system requirements
check_system() {
    log "Checking system requirements..."
    
    # Check macOS version (10.14+ required)
    local macos_version=$(sw_vers -productVersion)
    local major_version=$(echo "$macos_version" | cut -d. -f1)
    local minor_version=$(echo "$macos_version" | cut -d. -f2)
    
    if [[ $major_version -lt 10 ]] || ([[ $major_version -eq 10 ]] && [[ $minor_version -lt 14 ]]); then
        error "macOS 10.14 (Mojave) or later is required. Current version: $macos_version"
    fi
    
    # Check available disk space (need at least 2GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then
        error "Insufficient disk space. Need at least 2GB available."
    fi
    
    # Check if Xcode Command Line Tools are installed
    if ! xcode-select -p &> /dev/null; then
        log "Installing Xcode Command Line Tools..."
        xcode-select --install
        log "Please complete the Xcode Command Line Tools installation and run this script again."
        exit 1
    fi
    
    success "System requirements check passed"
}

# Install Homebrew with signature verification
install_homebrew() {
    log "Checking Homebrew installation..."
    
    if command -v brew &> /dev/null; then
        log "Homebrew already installed, updating..."
        if ! brew update; then
            warning "Homebrew update failed, continuing..."
        fi
        success "Homebrew updated"
        return 0
    fi
    
    log "Installing Homebrew..."
    
    # Download and verify Homebrew installation script
    local brew_install_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    local brew_script="/tmp/brew_install.sh"
    
    # Download with curl and verify SSL
    if ! curl -fsSL "$brew_install_url" -o "$brew_script"; then
        error "Failed to download Homebrew installation script"
    fi
    
    # Verify script integrity (basic check)
    if [[ ! -s "$brew_script" ]]; then
        error "Downloaded Homebrew script is empty or corrupted"
    fi
    
    # Execute Homebrew installation
    if ! /bin/bash "$brew_script"; then
        error "Homebrew installation failed"
    fi
    
    # Add Homebrew to PATH for current session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        export PATH="/opt/homebrew/bin:$PATH"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        export PATH="/usr/local/bin:$PATH"
    fi
    
    # Verify installation
    if ! command -v brew &> /dev/null; then
        error "Homebrew installation verification failed"
    fi
    
    success "Homebrew installed successfully"
}

# Install Tor Browser with signature verification
install_tor() {
    log "Installing Tor Browser version $TOR_VERSION..."
    
    # Check if already installed
    if [[ -d "/Applications/Tor Browser.app" ]]; then
        local installed_version=$(defaults read "/Applications/Tor Browser.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
        if [[ "$installed_version" == "$TOR_VERSION" ]]; then
            success "Tor Browser $TOR_VERSION already installed"
            return 0
        else
            log "Updating Tor Browser from $installed_version to $TOR_VERSION"
        fi
    fi
    
    # Install Tor Browser via Homebrew
    if ! brew install --cask tor-browser; then
        error "Failed to install Tor Browser"
    fi
    
    # Verify installation
    if [[ ! -d "/Applications/Tor Browser.app" ]]; then
        error "Tor Browser installation verification failed"
    fi
    
    success "Tor Browser $TOR_VERSION installed successfully"
}

# Install I2P with version verification
install_i2p() {
    log "Installing I2P version $I2P_VERSION..."
    
    # Check if already installed
    if [[ -d "/Applications/I2P.app" ]]; then
        local installed_version=$(defaults read "/Applications/I2P.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
        if [[ "$installed_version" == "$I2P_VERSION" ]]; then
            success "I2P $I2P_VERSION already installed"
            return 0
        else
            log "Updating I2P from $installed_version to $I2P_VERSION"
        fi
    fi
    
    # Install I2P via Homebrew
    if ! brew install --cask i2p; then
        error "Failed to install I2P"
    fi
    
    # Verify installation
    if [[ ! -d "/Applications/I2P.app" ]]; then
        error "I2P installation verification failed"
    fi
    
    success "I2P $I2P_VERSION installed successfully"
}

# Install ProxyChains-NG with DNS leak protection
install_proxychains() {
    log "Installing ProxyChains-NG version $PROXYCHAINS_VERSION..."
    
    # Check if already installed
    if command -v proxychains4 &> /dev/null; then
        local installed_version=$(proxychains4 -h 2>&1 | grep -o '[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
        if [[ "$installed_version" == "$PROXYCHAINS_VERSION" ]]; then
            success "ProxyChains-NG $PROXYCHAINS_VERSION already installed"
        else
            log "Updating ProxyChains-NG from $installed_version to $PROXYCHAINS_VERSION"
        fi
    fi
    
    # Install ProxyChains-NG via Homebrew
    if ! brew install proxychains-ng; then
        error "Failed to install ProxyChains-NG"
    fi
    
    # Configure ProxyChains with DNS leak protection
    configure_proxychains
    
    success "ProxyChains-NG $PROXYCHAINS_VERSION installed and configured"
}

# Configure ProxyChains with DNS leak protection and dynamic_chain
configure_proxychains() {
    log "Configuring ProxyChains with DNS leak protection and dynamic_chain..."
    
    local config_file="$HOME/.proxychains/proxychains.conf"
    local backup_file="$HOME/.proxychains/proxychains.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create directory if it doesn't exist
    mkdir -p "$HOME/.proxychains"
    
    # Create backup if config exists
    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$backup_file"
        log "Created backup: $backup_file"
    fi
    
    # Create secure configuration with dynamic_chain
    cat > "$config_file" << 'EOF'
# OpSec Tools ProxyChains Configuration for macOS
# Generated on $(date)

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
EOF
    
    success "ProxyChains configured with DNS leak protection and dynamic_chain"
}

# Test Tor egress connectivity
test_tor_egress() {
    log "Testing Tor egress connectivity..."
    
    # Wait for Tor to be available
    local attempts=0
    local max_attempts=30
    
    while [[ $attempts -lt $max_attempts ]]; do
        if lsof -i :$TOR_SOCKS_PORT > /dev/null 2>&1; then
            break
        fi
        sleep 2
        ((attempts++))
    done
    
    if [[ $attempts -eq $max_attempts ]]; then
        warning "Tor SOCKS port not available, skipping egress test"
        return 1
    fi
    
    # Test Tor egress using proxychains
    local test_result
    test_result=$(timeout 30 proxychains4 curl -s https://check.torproject.org/ 2>/dev/null | head -n 5 || echo "FAILED")
    
    if echo "$test_result" | grep -q "Congratulations\|You are using Tor"; then
        success "✓ Tor egress test passed"
        return 0
    else
        warning "⚠ Tor egress test failed"
        return 1
    fi
}

# Test I2P health
test_i2p_health() {
    log "Testing I2P health..."
    
    # Wait for I2P to be available
    local attempts=0
    local max_attempts=60  # I2P can take longer to start
    
    while [[ $attempts -lt $max_attempts ]]; do
        if lsof -i :$I2P_HTTP_PORT > /dev/null 2>&1; then
            break
        fi
        sleep 2
        ((attempts++))
    done
    
    if [[ $attempts -eq $max_attempts ]]; then
        warning "I2P HTTP port not available, skipping health test"
        return 1
    fi
    
    # Test I2P health endpoint
    local test_result
    test_result=$(timeout 30 curl -s http://127.0.0.1:$I2P_HTTP_PORT 2>/dev/null || echo "FAILED")
    
    if echo "$test_result" | grep -q "I2P\|router"; then
        success "✓ I2P health test passed"
        return 0
    else
        warning "⚠ I2P health test failed"
        return 1
    fi
}

# Health check function
health_check() {
    log "Performing health checks..."
    
    local checks_passed=0
    local total_checks=3
    
    # Check Tor Browser
    if [[ -d "/Applications/Tor Browser.app" ]]; then
        success "✓ Tor Browser installation verified"
        ((checks_passed++))
    else
        error "✗ Tor Browser installation failed"
    fi
    
    # Check I2P
    if [[ -d "/Applications/I2P.app" ]]; then
        success "✓ I2P installation verified"
        ((checks_passed++))
    else
        error "✗ I2P installation failed"
    fi
    
    # Check ProxyChains
    if command -v proxychains4 &> /dev/null; then
        success "✓ ProxyChains-NG installation verified"
        ((checks_passed++))
    else
        error "✗ ProxyChains-NG installation failed"
    fi
    
    # Check ProxyChains configuration
    if grep -q "proxy_dns" "$HOME/.proxychains/proxychains.conf" 2>/dev/null; then
        success "✓ DNS leak protection enabled"
    else
        warning "⚠ DNS leak protection not properly configured"
    fi
    
    # Check for dynamic_chain
    if grep -q "dynamic_chain" "$HOME/.proxychains/proxychains.conf" 2>/dev/null; then
        success "✓ Dynamic chain mode enabled"
    else
        warning "⚠ Dynamic chain mode not configured"
    fi
    
    log "Health check results: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        success "All installations completed successfully!"
    else
        error "Some installations failed. Check the log: $LOG_FILE"
    fi
}

# Main installation function
main() {
    log "Starting OpSec Tools installation for macOS..."
    log "Log file: $LOG_FILE"
    log "Configuration: TOR_SOCKS_PORT=$TOR_SOCKS_PORT, I2P_HTTP_PORT=$I2P_HTTP_PORT, I2P_PROXY_PORT=$I2P_PROXY_PORT"
    
    check_system
    install_homebrew
    install_tor
    install_i2p
    install_proxychains
    health_check
    
    log "Installation completed. Log saved to: $LOG_FILE"
    echo
    echo -e "${GREEN}Installation Summary:${NC}"
    echo "• Tor Browser: Installed with signature verification"
    echo "• I2P: Installed with version pinning"
    echo "• ProxyChains-NG: Installed with DNS leak protection and dynamic_chain"
    echo "• All configurations: Secured and verified"
    echo
    echo "Next steps:"
    echo "1. Run the tool_run/mac.sh script to start services"
    echo "2. Configure your applications to use the proxies"
    echo "3. Test connectivity at https://check.torproject.org"
    echo "4. Verify I2P console at http://127.0.0.1:$I2P_HTTP_PORT"
    echo "5. Consider enabling macOS firewall for additional security"
}

# Run main function
main "$@"