#!/bin/bash
# OpSec Tools Runner for macOS
# Version: 1.0.0
# Last Updated: $(date +%Y-%m-%d)

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/opsec_run_$(date +%Y%m%d_%H%M%S).log"
readonly TOR_SOCKS_PORT="9050"
readonly I2P_HTTP_PORT="4444"
readonly I2P_SOCKS_PORT="4447"

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

# Check if services are installed
check_installations() {
    log "Checking tool installations..."
    
    local missing_tools=()
    
    if [[ ! -d "/Applications/Tor Browser.app" ]]; then
        missing_tools+=("Tor Browser")
    fi
    
    if [[ ! -d "/Applications/I2P.app" ]]; then
        missing_tools+=("I2P")
    fi
    
    if ! command -v proxychains4 &> /dev/null; then
        missing_tools+=("ProxyChains-NG")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing tools: ${missing_tools[*]}. Please run the installation script first."
    fi
    
    success "All tools are installed"
}

# Check if port is listening
check_port() {
    local port=$1
    local service=$2
    
    if lsof -i :$port > /dev/null 2>&1; then
        success "✓ $service is listening on port $port"
        return 0
    else
        warning "⚠ $service is not listening on port $port"
        return 1
    fi
}

# Test Tor connectivity
test_tor_connectivity() {
    log "Testing Tor connectivity..."
    
    # Check if Tor SOCKS port is listening
    if ! check_port "$TOR_SOCKS_PORT" "Tor"; then
        warning "Tor SOCKS proxy not available"
        return 1
    fi
    
    # Test Tor connectivity using curl
    local tor_test_url="https://check.torproject.org"
    local test_result
    
    if command -v curl &> /dev/null; then
        test_result=$(curl --socks5 127.0.0.1:$TOR_SOCKS_PORT --connect-timeout 10 --max-time 30 -s "$tor_test_url" 2>/dev/null || echo "FAILED")
        
        if echo "$test_result" | grep -q "Congratulations"; then
            success "✓ Tor connectivity test passed"
            return 0
        else
            warning "⚠ Tor connectivity test failed"
            return 1
        fi
    else
        warning "⚠ curl not available, skipping Tor connectivity test"
        return 1
    fi
}

# Test I2P connectivity
test_i2p_connectivity() {
    log "Testing I2P connectivity..."
    
    # Check if I2P HTTP port is listening
    if ! check_port "$I2P_HTTP_PORT" "I2P HTTP"; then
        warning "I2P HTTP proxy not available"
        return 1
    fi
    
    # Check if I2P SOCKS port is listening
    if ! check_port "$I2P_SOCKS_PORT" "I2P SOCKS"; then
        warning "I2P SOCKS proxy not available"
        return 1
    fi
    
    # Test I2P connectivity using curl
    local i2p_test_url="http://127.0.0.1:$I2P_HTTP_PORT"
    local test_result
    
    if command -v curl &> /dev/null; then
        test_result=$(curl --proxy "http://127.0.0.1:$I2P_HTTP_PORT" --connect-timeout 10 --max-time 30 -s "$i2p_test_url" 2>/dev/null || echo "FAILED")
        
        if echo "$test_result" | grep -q "I2P"; then
            success "✓ I2P connectivity test passed"
            return 0
        else
            warning "⚠ I2P connectivity test failed"
            return 1
        fi
    else
        warning "⚠ curl not available, skipping I2P connectivity test"
        return 1
    fi
}

# Start Tor Browser
start_tor_browser() {
    log "Starting Tor Browser..."
    
    # Check if Tor Browser is already running
    if pgrep -f "Tor Browser" > /dev/null; then
        success "Tor Browser is already running"
        return 0
    fi
    
    # Start Tor Browser
    if open -a "Tor Browser"; then
        log "Tor Browser launch command sent"
        
        # Wait a moment for Tor to start
        sleep 5
        
        # Check if Tor Browser process is running
        if pgrep -f "Tor Browser" > /dev/null; then
            success "Tor Browser started successfully"
            return 0
        else
            warning "Tor Browser may still be starting up"
            return 1
        fi
    else
        error "Failed to start Tor Browser"
    fi
}

# Start I2P router
start_i2p_router() {
    log "Starting I2P router..."
    
    # Check if I2P is already running
    if pgrep -f "I2P" > /dev/null; then
        success "I2P router is already running"
        return 0
    fi
    
    # Start I2P router
    if open -a "I2P Router"; then
        log "I2P router launch command sent"
        
        # Wait for I2P to start (it can take a while)
        log "Waiting for I2P router to initialize..."
        local attempts=0
        local max_attempts=30
        
        while [[ $attempts -lt $max_attempts ]]; do
            if check_port "$I2P_HTTP_PORT" "I2P HTTP" > /dev/null 2>&1; then
                success "I2P router started successfully"
                return 0
            fi
            sleep 2
            ((attempts++))
        done
        
        warning "I2P router may still be starting up (timeout reached)"
        return 1
    else
        error "Failed to start I2P router"
    fi
}

# Test ProxyChains configuration
test_proxychains() {
    log "Testing ProxyChains configuration..."
    
    # Check if ProxyChains config has DNS leak protection
    if grep -q "proxy_dns" "$HOME/.proxychains/proxychains.conf" 2>/dev/null; then
        success "✓ ProxyChains DNS leak protection enabled"
    else
        warning "⚠ ProxyChains DNS leak protection not configured"
    fi
    
    # Test ProxyChains with a simple command
    if command -v curl &> /dev/null; then
        local test_result
        test_result=$(timeout 10 proxychains4 curl -s --connect-timeout 5 --max-time 10 "https://httpbin.org/ip" 2>/dev/null || echo "FAILED")
        
        if echo "$test_result" | grep -q "origin"; then
            success "✓ ProxyChains connectivity test passed"
            return 0
        else
            warning "⚠ ProxyChains connectivity test failed"
            return 1
        fi
    else
        warning "⚠ curl not available, skipping ProxyChains connectivity test"
        return 1
    fi
}

# Display service status
show_status() {
    log "Service Status Summary:"
    echo
    echo -e "${BLUE}=== Service Status ===${NC}"
    
    # Tor status
    if pgrep -f "Tor Browser" > /dev/null; then
        echo -e "${GREEN}✓ Tor Browser: Running${NC}"
    else
        echo -e "${RED}✗ Tor Browser: Not running${NC}"
    fi
    
    # I2P status
    if pgrep -f "I2P" > /dev/null; then
        echo -e "${GREEN}✓ I2P Router: Running${NC}"
    else
        echo -e "${RED}✗ I2P Router: Not running${NC}"
    fi
    
    # Port status
    echo
    echo -e "${BLUE}=== Port Status ===${NC}"
    check_port "$TOR_SOCKS_PORT" "Tor SOCKS" > /dev/null 2>&1 || echo -e "${RED}✗ Tor SOCKS (port $TOR_SOCKS_PORT): Not listening${NC}"
    check_port "$I2P_HTTP_PORT" "I2P HTTP" > /dev/null 2>&1 || echo -e "${RED}✗ I2P HTTP (port $I2P_HTTP_PORT): Not listening${NC}"
    check_port "$I2P_SOCKS_PORT" "I2P SOCKS" > /dev/null 2>&1 || echo -e "${RED}✗ I2P SOCKS (port $I2P_SOCKS_PORT): Not listening${NC}"
    
    echo
    echo -e "${BLUE}=== Usage Examples ===${NC}"
    echo "• Tor Browser: Already started"
    echo "• I2P Console: http://127.0.0.1:$I2P_HTTP_PORT"
    echo "• Test Tor: curl --socks5 127.0.0.1:$TOR_SOCKS_PORT https://check.torproject.org"
    echo "• Test I2P: curl --proxy http://127.0.0.1:$I2P_HTTP_PORT http://127.0.0.1:$I2P_HTTP_PORT"
    echo "• Use ProxyChains: proxychains4 your_command"
}

# Health check function
health_check() {
    log "Performing health checks..."
    
    local checks_passed=0
    local total_checks=3
    
    # Test Tor connectivity
    if test_tor_connectivity; then
        ((checks_passed++))
    fi
    
    # Test I2P connectivity
    if test_i2p_connectivity; then
        ((checks_passed++))
    fi
    
    # Test ProxyChains
    if test_proxychains; then
        ((checks_passed++))
    fi
    
    log "Health check results: $checks_passed/$total_checks checks passed"
    
    if [[ $checks_passed -eq $total_checks ]]; then
        success "All services are running and accessible!"
    else
        warning "Some services may not be fully operational"
    fi
}

# Main function
main() {
    log "Starting OpSec Tools for macOS..."
    log "Log file: $LOG_FILE"
    
    check_installations
    start_tor_browser
    start_i2p_router
    health_check
    show_status
    
    log "OpSec Tools started. Log saved to: $LOG_FILE"
    echo
    echo -e "${GREEN}OpSec Tools are now running!${NC}"
    echo "• Tor Browser: Check for the browser window"
    echo "• I2P Console: http://127.0.0.1:$I2P_HTTP_PORT"
    echo "• ProxyChains: Use 'proxychains4 your_command' to route traffic through Tor/I2P"
    echo
    echo "Press Ctrl+C to stop all services"
    
    # Keep script running and handle cleanup
    trap 'log "Stopping OpSec Tools..."; pkill -f "Tor Browser"; pkill -f "I2P"; exit 0' INT TERM
    
    # Wait for user interrupt
    while true; do
        sleep 1
    done
}

# Run main function
main "$@"