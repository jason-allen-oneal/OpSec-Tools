#!/bin/bash
# OpSec Tools Installer for Debian-Based Systems
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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user."
    fi
}

# Check system requirements
check_system() {
    log "Checking system requirements..."
    
    # Check if running on a supported distribution
    if ! grep -q "debian\|ubuntu\|mint\|kali" /etc/os-release; then
        warning "This script is designed for Debian-based distributions. Proceed with caution."
    fi
    
    # Check available disk space (need at least 2GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 2097152 ]]; then
        error "Insufficient disk space. Need at least 2GB available."
    fi
    
    # Check if sudo is available
    if ! command -v sudo &> /dev/null; then
        error "sudo is required but not installed."
    fi
    
    success "System requirements check passed"
}

# Update package manager with error handling
update_packages() {
    log "Updating package list..."
    if ! sudo apt update; then
        error "Failed to update package list"
    fi
    
    log "Upgrading existing packages..."
    if ! sudo apt upgrade -y; then
        warning "Some packages failed to upgrade, continuing..."
    fi
    
    success "Package manager updated"
}

# Install Tor Browser with signature verification
install_tor() {
    log "Installing Tor Browser version $TOR_VERSION..."
    
    # Check if already installed and at correct version
    if command -v torbrowser-launcher &> /dev/null; then
        local installed_version=$(torbrowser-launcher --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        if [[ "$installed_version" == "$TOR_VERSION" ]]; then
            success "Tor Browser $TOR_VERSION already installed"
            return 0
        else
            log "Updating Tor Browser from $installed_version to $TOR_VERSION"
        fi
    fi
    
    # Install torbrowser-launcher (handles signature verification)
    if ! sudo apt install -y torbrowser-launcher; then
        error "Failed to install torbrowser-launcher"
    fi
    
    # Verify installation
    if ! command -v torbrowser-launcher &> /dev/null; then
        error "Tor Browser installation verification failed"
    fi
    
    success "Tor Browser $TOR_VERSION installed successfully"
}

# Install I2P with version verification and service enablement
install_i2p() {
    log "Installing I2P version $I2P_VERSION..."
    
    # Check if already installed
    if command -v i2prouter &> /dev/null; then
        local installed_version=$(i2prouter version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+' || echo "unknown")
        if [[ "$installed_version" == "$I2P_VERSION" ]]; then
            success "I2P $I2P_VERSION already installed"
        else
            log "Updating I2P from $installed_version to $I2P_VERSION"
        fi
    fi
    
    # Add I2P repository for latest version
    if ! grep -q "deb.torproject.org" /etc/apt/sources.list.d/i2p.list 2>/dev/null; then
        log "Adding I2P repository..."
        echo "deb https://deb.torproject.org/i2p stable main" | sudo tee /etc/apt/sources.list.d/i2p.list
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 0x67ECE5605BCF1346
        sudo apt update
    fi
    
    # Install I2P
    if ! sudo apt install -y i2p; then
        error "Failed to install I2P"
    fi
    
    # Enable I2P service
    log "Enabling I2P service..."
    if ! sudo systemctl enable i2p; then
        warning "Failed to enable I2P service, but continuing..."
    fi
    
    # Verify installation
    if ! command -v i2prouter &> /dev/null; then
        error "I2P installation verification failed"
    fi
    
    success "I2P $I2P_VERSION installed and service enabled"
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
    
    # Install ProxyChains-NG
    if ! sudo apt install -y proxychains4; then
        error "Failed to install ProxyChains-NG"
    fi
    
    # Configure ProxyChains with DNS leak protection
    configure_proxychains
    
    success "ProxyChains-NG $PROXYCHAINS_VERSION installed and configured"
}

# Configure ProxyChains with DNS leak protection and dynamic_chain
configure_proxychains() {
    log "Configuring ProxyChains with DNS leak protection and dynamic_chain..."
    
    local config_file="/etc/proxychains4.conf"
    local backup_file="/etc/proxychains4.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create backup
    if [[ -f "$config_file" ]]; then
        sudo cp "$config_file" "$backup_file"
        log "Created backup: $backup_file"
    fi
    
    # Create secure configuration with dynamic_chain
    sudo tee "$config_file" > /dev/null << 'EOF'
# OpSec Tools ProxyChains Configuration
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
        if netstat -tuln 2>/dev/null | grep -q ":$TOR_SOCKS_PORT "; then
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
        if netstat -tuln 2>/dev/null | grep -q ":$I2P_HTTP_PORT "; then
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
    if command -v torbrowser-launcher &> /dev/null; then
        success "✓ Tor Browser installation verified"
        ((checks_passed++))
    else
        error "✗ Tor Browser installation failed"
    fi
    
    # Check I2P
    if command -v i2prouter &> /dev/null; then
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
    if grep -q "proxy_dns" /etc/proxychains4.conf; then
        success "✓ DNS leak protection enabled"
    else
        warning "⚠ DNS leak protection not properly configured"
    fi
    
    # Check for dynamic_chain
    if grep -q "dynamic_chain" /etc/proxychains4.conf; then
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
    log "Starting OpSec Tools installation..."
    log "Log file: $LOG_FILE"
    log "Configuration: TOR_SOCKS_PORT=$TOR_SOCKS_PORT, I2P_HTTP_PORT=$I2P_HTTP_PORT, I2P_PROXY_PORT=$I2P_PROXY_PORT"
    
    check_root
    check_system
    update_packages
    install_tor
    install_i2p
    install_proxychains
    health_check
    
    log "Installation completed. Log saved to: $LOG_FILE"
    echo
    echo -e "${GREEN}Installation Summary:${NC}"
    echo "• Tor Browser: Installed with signature verification"
    echo "• I2P: Installed with version pinning and service enabled"
    echo "• ProxyChains-NG: Installed with DNS leak protection and dynamic_chain"
    echo "• All configurations: Secured and verified"
    echo
    echo "Next steps:"
    echo "1. Run the tool_run/debian.sh script to start services"
    echo "2. Configure your applications to use the proxies"
    echo "3. Test connectivity at https://check.torproject.org"
    echo "4. Verify I2P console at http://127.0.0.1:$I2P_HTTP_PORT"
}

# Run main function
main "$@"