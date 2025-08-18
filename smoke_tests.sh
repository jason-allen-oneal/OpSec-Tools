#!/bin/bash
# OpSec Tools Smoke Tests
# Version: 1.0.0
# Last Updated: $(date +%Y-%m-%d)

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/opsec_smoke_tests_$(date +%Y%m%d_%H%M%S).log"

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
    return 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if port is listening
check_port() {
    local port=$1
    local service=$2
    
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 0
    else
        return 1
    fi
}

# Test 1: Tor egress connectivity with torsocks
test_tor_egress() {
    log "Test 1: Tor egress connectivity with torsocks"
    
    # Check if Tor SOCKS port is listening
    if ! check_port "$TOR_SOCKS_PORT" "Tor"; then
        error "Tor SOCKS port $TOR_SOCKS_PORT not listening"
        return 1
    fi
    
    # Test Tor egress using torsocks
    if ! command -v torsocks &> /dev/null; then
        error "torsocks not available"
        return 1
    fi
    
    local test_result
    test_result=$(timeout 30 torsocks curl -s https://check.torproject.org/ 2>/dev/null | head -n 5 || echo "FAILED")
    
    if echo "$test_result" | grep -q "Congratulations\|You are using Tor"; then
        success "✓ Tor egress test passed: Connection confirmed through Tor"
        return 0
    else
        error "✗ Tor egress test failed: Not connecting through Tor"
        return 1
    fi
}

# Test 2: DNS leak protection with proxychains
test_dns_leak_protection() {
    log "Test 2: DNS leak protection with proxychains"
    
    if ! command -v dig &> /dev/null; then
        error "dig not available for DNS testing"
        return 1
    fi
    
    if ! command -v proxychains4 &> /dev/null; then
        error "proxychains4 not available"
        return 1
    fi
    
    # Test DNS resolution through proxychains
    local test_result
    test_result=$(timeout 30 proxychains4 dig example.com 2>/dev/null || echo "FAILED")
    
    if echo "$test_result" | grep -q "example.com"; then
        success "✓ DNS leak protection test passed: DNS resolved via proxy"
        return 0
    else
        error "✗ DNS leak protection test failed: DNS not resolving via proxy"
        return 1
    fi
}

# Test 3: I2P health check
test_i2p_health() {
    log "Test 3: I2P health check"
    
    # Check if I2P HTTP port is listening
    if ! check_port "$I2P_HTTP_PORT" "I2P HTTP"; then
        error "I2P HTTP port $I2P_HTTP_PORT not listening"
        return 1
    fi
    
    # Test I2P health endpoint
    local test_result
    test_result=$(timeout 30 curl -s http://127.0.0.1:$I2P_HTTP_PORT 2>/dev/null || echo "FAILED")
    
    if echo "$test_result" | grep -q "I2P\|router"; then
        success "✓ I2P health test passed: Router responding"
        return 0
    else
        error "✗ I2P health test failed: Router not responding properly"
        return 1
    fi
}

# Test 4: ProxyChains configuration verification
test_proxychains_config() {
    log "Test 4: ProxyChains configuration verification"
    
    local config_file="/etc/proxychains4.conf"
    local user_config="$HOME/.proxychains/proxychains.conf"
    
    # Check which config file exists
    if [[ -f "$config_file" ]]; then
        local config_to_check="$config_file"
    elif [[ -f "$user_config" ]]; then
        local config_to_check="$user_config"
    else
        error "No ProxyChains configuration file found"
        return 1
    fi
    
    local checks_passed=0
    local total_checks=2
    
    # Check for dynamic_chain
    if grep -q "dynamic_chain" "$config_to_check"; then
        success "✓ dynamic_chain configured"
        ((checks_passed++))
    else
        warning "⚠ dynamic_chain not configured"
    fi
    
    # Check for proxy_dns
    if grep -q "proxy_dns" "$config_to_check"; then
        success "✓ proxy_dns configured"
        ((checks_passed++))
    else
        warning "⚠ proxy_dns not configured"
    fi
    
    if [[ $checks_passed -eq $total_checks ]]; then
        success "✓ ProxyChains configuration test passed"
        return 0
    else
        error "✗ ProxyChains configuration test failed"
        return 1
    fi
}

# Test 5: ProxyChains connectivity test
test_proxychains_connectivity() {
    log "Test 5: ProxyChains connectivity test"
    
    if ! command -v proxychains4 &> /dev/null; then
        error "proxychains4 not available"
        return 1
    fi
    
    # Test connectivity through proxychains
    local test_result
    test_result=$(timeout 30 proxychains4 curl -s --connect-timeout 10 --max-time 15 "https://httpbin.org/ip" 2>/dev/null || echo "FAILED")
    
    if echo "$test_result" | grep -q "origin"; then
        success "✓ ProxyChains connectivity test passed: Traffic routed through proxy"
        return 0
    else
        error "✗ ProxyChains connectivity test failed: Traffic not routed through proxy"
        return 1
    fi
}

# Test 6: Service process verification
test_service_processes() {
    log "Test 6: Service process verification"
    
    local checks_passed=0
    local total_checks=2
    
    # Check Tor Browser process
    if pgrep -f "firefox.*tor" > /dev/null; then
        success "✓ Tor Browser process running"
        ((checks_passed++))
    else
        warning "⚠ Tor Browser process not running"
    fi
    
    # Check I2P router process
    if pgrep -f "i2prouter" > /dev/null; then
        success "✓ I2P router process running"
        ((checks_passed++))
    else
        warning "⚠ I2P router process not running"
    fi
    
    if [[ $checks_passed -eq $total_checks ]]; then
        success "✓ Service process test passed"
        return 0
    else
        error "✗ Service process test failed"
        return 1
    fi
}

# Test 7: Port availability verification
test_port_availability() {
    log "Test 7: Port availability verification"
    
    local checks_passed=0
    local total_checks=3
    
    # Check Tor SOCKS port
    if check_port "$TOR_SOCKS_PORT" "Tor SOCKS"; then
        success "✓ Tor SOCKS port $TOR_SOCKS_PORT listening"
        ((checks_passed++))
    else
        warning "⚠ Tor SOCKS port $TOR_SOCKS_PORT not listening"
    fi
    
    # Check I2P HTTP port
    if check_port "$I2P_HTTP_PORT" "I2P HTTP"; then
        success "✓ I2P HTTP port $I2P_HTTP_PORT listening"
        ((checks_passed++))
    else
        warning "⚠ I2P HTTP port $I2P_HTTP_PORT not listening"
    fi
    
    # Check I2P proxy port
    if check_port "$I2P_PROXY_PORT" "I2P proxy"; then
        success "✓ I2P proxy port $I2P_PROXY_PORT listening"
        ((checks_passed++))
    else
        warning "⚠ I2P proxy port $I2P_PROXY_PORT not listening"
    fi
    
    if [[ $checks_passed -eq $total_checks ]]; then
        success "✓ Port availability test passed"
        return 0
    else
        error "✗ Port availability test failed"
        return 1
    fi
}

# Run all smoke tests
run_all_tests() {
    log "Starting OpSec Tools smoke tests..."
    log "Configuration: TOR_SOCKS_PORT=$TOR_SOCKS_PORT, I2P_HTTP_PORT=$I2P_HTTP_PORT, I2P_PROXY_PORT=$I2P_PROXY_PORT"
    
    local tests_passed=0
    local total_tests=7
    
    # Run each test
    if test_tor_egress; then
        ((tests_passed++))
    fi
    
    if test_dns_leak_protection; then
        ((tests_passed++))
    fi
    
    if test_i2p_health; then
        ((tests_passed++))
    fi
    
    if test_proxychains_config; then
        ((tests_passed++))
    fi
    
    if test_proxychains_connectivity; then
        ((tests_passed++))
    fi
    
    if test_service_processes; then
        ((tests_passed++))
    fi
    
    if test_port_availability; then
        ((tests_passed++))
    fi
    
    # Summary
    echo
    echo -e "${BLUE}=== Smoke Test Summary ===${NC}"
    echo "Tests passed: $tests_passed/$total_tests"
    
    if [[ $tests_passed -eq $total_tests ]]; then
        success "All smoke tests passed! OpSec Tools are working correctly."
        return 0
    else
        error "Some smoke tests failed. Check the configuration and logs."
        return 1
    fi
}

# Main function
main() {
    log "OpSec Tools Smoke Tests"
    log "Log file: $LOG_FILE"
    
    run_all_tests
    
    log "Smoke tests completed. Check $LOG_FILE for detailed results."
}

# Run main function
main "$@"
