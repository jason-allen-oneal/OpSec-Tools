# OpSec Tools - Secure Privacy & Anonymity Suite

A comprehensive, security-focused toolkit for installing and running privacy and anonymity tools across multiple platforms. This project provides hardened installation and management scripts for Tor Browser, I2P, and ProxyChains-NG with enterprise-grade security features.

## 🛡️ Security Features

### ✅ **Fixed Critical Issues**

- **DNS Leak Protection**: All ProxyChains configurations now include `proxy_dns` to prevent DNS leaks
- **Version Pinning**: All tools use specific, tested versions for reproducible deployments
- **Health Checks**: Comprehensive verification that services are actually running and accessible
- **Signature Verification**: Secure downloads with hash verification where possible
- **Dynamic Path Detection**: No more hardcoded paths - scripts automatically find installations
- **Idempotent Installations**: Safe to run multiple times without breaking existing setups
- **Comprehensive Logging**: Detailed logs for troubleshooting and audit trails

### 🔒 **Concrete Hardening Measures**

- **Dynamic Chain Mode**: ProxyChains uses `dynamic_chain` for better resilience than `strict_chain`
- **Tor Egress Verification**: Comprehensive testing with `torsocks` and `proxychains4`
- **I2P Health Monitoring**: Automatic verification of I2P router status and connectivity
- **Platform-Specific Security**: 
  - **Windows**: Uses `winget` for Tor (updates & signatures), handles both ProgramFiles paths
  - **macOS**: Uses `proxychains-ng` from Homebrew with signature verification
  - **Debian**: Uses `torbrowser-launcher` (handles signature verification), enables I2P service
- **Smoke Tests**: Automated comprehensive testing suite for all components

### 🔒 **Security Enhancements**

- **Error Handling**: Robust error handling with graceful failures
- **System Requirements**: Pre-flight checks for OS compatibility and resources
- **Backup Creation**: Automatic backup of existing configurations
- **Process Verification**: Ensures services are actually running, not just started
- **Network Testing**: Connectivity tests to verify proxy functionality
- **Secure Defaults**: Hardened configurations out of the box

## 🚀 Quick Start

### Prerequisites

- **Linux (Debian/Ubuntu)**: `sudo` access, 2GB+ free disk space
- **macOS**: 10.14+ (Mojave), Xcode Command Line Tools, 2GB+ free disk space  
- **Windows**: Windows 10/11, PowerShell 5.1+, Administrator access, 2GB+ free disk space

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-repo/OpSec-Tools.git
   cd OpSec-Tools
   ```

2. **Run the appropriate installation script**:

   **Linux (Debian/Ubuntu)**:
   ```bash
   chmod +x tool_install/debian.sh
   ./tool_install/debian.sh
   ```

   **macOS**:
   ```bash
   chmod +x tool_install/mac.sh
   ./tool_install/mac.sh
   ```

   **Windows** (Run as Administrator):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\tool_install\windows.ps1
   ```

3. **Start the services**:

   **Linux**:
   ```bash
   chmod +x tool_run/debian.sh
   ./tool_run/debian.sh
   ```

   **macOS**:
   ```bash
   chmod +x tool_run/mac.sh
   ./tool_run/mac.sh
   ```

   **Windows**:
   ```powershell
   .\tool_run\windows.ps1
   ```

4. **Run smoke tests**:
   ```bash
   chmod +x smoke_tests.sh
   ./smoke_tests.sh
   ```

## 📦 What Gets Installed

### Core Tools

- **Tor Browser** (v13.0.12): Anonymous web browsing
- **I2P** (v1.9.0): Invisible Internet Project for anonymous communication
- **ProxyChains-NG** (v4.16): Advanced proxy chaining with DNS leak protection

### Security Features

- **DNS Leak Protection**: All DNS queries routed through proxies
- **Version Pinning**: Reproducible, tested versions
- **Health Monitoring**: Real-time service verification
- **Secure Configurations**: Hardened default settings
- **Dynamic Chain Mode**: More resilient proxy chaining

## 🔧 Configuration

### ProxyChains Configuration

All installations include a secure ProxyChains configuration with:

```bash
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
```

### Port Configuration

- **Tor SOCKS**: 127.0.0.1:9050
- **I2P HTTP**: 127.0.0.1:7657
- **I2P Proxy**: 127.0.0.1:4444

## 🧪 Testing & Verification

### Smoke Tests

Run comprehensive automated tests:

```bash
./smoke_tests.sh
```

The smoke tests verify:
1. **Tor Egress**: `torsocks curl -s https://check.torproject.org/ | head -n 5`
2. **DNS Leak Protection**: `proxychains4 dig example.com`
3. **I2P Health**: `curl http://127.0.0.1:7657`
4. **ProxyChains Configuration**: Verifies `dynamic_chain` and `proxy_dns`
5. **ProxyChains Connectivity**: Tests actual proxy routing
6. **Service Processes**: Verifies all services are running
7. **Port Availability**: Checks all required ports are listening

### Health Checks

The run scripts perform comprehensive health checks:

1. **Installation Verification**: Ensures all tools are properly installed
2. **Service Status**: Checks if processes are running
3. **Port Verification**: Confirms services are listening on expected ports
4. **Connectivity Testing**: Tests actual proxy functionality
5. **DNS Leak Protection**: Verifies ProxyChains configuration

### Manual Testing

**Test Tor Connectivity**:
```bash
# Linux/macOS
torsocks curl -s https://check.torproject.org/
proxychains4 curl -s https://check.torproject.org/

# Windows (PowerShell)
$webClient = New-Object System.Net.WebClient
$webClient.Proxy = New-Object System.Net.WebProxy("socks5://127.0.0.1:9050")
$webClient.DownloadString("https://check.torproject.org")
```

**Test I2P Connectivity**:
```bash
# Linux/macOS
curl http://127.0.0.1:7657
curl --proxy http://127.0.0.1:4444 http://127.0.0.1:7657

# Windows (PowerShell)
$webClient = New-Object System.Net.WebClient
$webClient.Proxy = New-Object System.Net.WebProxy("http://127.0.0.1:7657")
$webClient.DownloadString("http://127.0.0.1:7657")
```

**Test ProxyChains**:
```bash
# Linux/macOS
proxychains4 curl https://httpbin.org/ip
proxychains4 dig example.com

# Windows (WSL)
wsl proxychains4 curl https://httpbin.org/ip
wsl proxychains4 dig example.com
```

## 📋 Usage Examples

### Basic Usage

**Route a command through Tor**:
```bash
proxychains4 your_command
torsocks your_command
```

**Use Tor Browser**: Simply launch and browse anonymously

**Access I2P Console**: Visit `http://127.0.0.1:7657` in your browser

### Advanced Usage

**Chain multiple proxies**:
```bash
# Route through Tor, then I2P
proxychains4 -f /path/to/custom/config.conf your_command
```

**Custom ProxyChains configuration**:
```bash
# Create custom config
cat > ~/.proxychains/custom.conf << EOF
dynamic_chain
proxy_dns
socks5 127.0.0.1 9050
http 127.0.0.1 4444
EOF

# Use custom config
proxychains4 -f ~/.proxychains/custom.conf your_command
```

## 🔍 Troubleshooting

### Common Issues

**"Missing tools" error**:
- Run the installation script first
- Check system requirements
- Verify internet connectivity

**"DNS leak protection not configured"**:
- Re-run the installation script
- Check ProxyChains configuration file
- Verify file permissions

**"Service not listening"**:
- Wait for services to fully start (I2P can take 1-2 minutes)
- Check if ports are already in use
- Review logs in `/tmp/opsec_*.log`

**"Tor egress test failed"**:
- Ensure Tor Browser is running
- Check if Tor SOCKS port 9050 is listening
- Verify torsocks is installed

### Log Files

All operations are logged to:
- **Linux/macOS**: `/tmp/opsec_install_*.log`, `/tmp/opsec_run_*.log`, `/tmp/opsec_smoke_tests_*.log`
- **Windows**: `C:\temp\opsec_install_*.log`, `C:\temp\opsec_run_*.log`

### Debug Mode

Enable verbose logging by setting the environment variable:
```bash
export OP_SEC_DEBUG=1
./tool_install/debian.sh
```

## 🔒 Security Considerations

### Best Practices

1. **Regular Updates**: Keep tools updated for security patches
2. **Network Isolation**: Consider using a VPN in addition to these tools
3. **Browser Security**: Use Tor Browser's security slider appropriately
4. **No Personal Data**: Never use these tools with personal accounts
5. **Legal Compliance**: Ensure usage complies with local laws
6. **Regular Testing**: Run smoke tests weekly to verify security

### Limitations

- **No Perfect Anonymity**: These tools improve privacy but don't guarantee complete anonymity
- **Performance Impact**: Proxy chaining can slow down connections
- **Compatibility**: Some applications may not work with proxies
- **Updates**: Manual intervention may be required for major version updates

## 🤝 Contributing

### Development

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on target platforms
5. Submit a pull request

### Testing

Before submitting changes:
- Test on all supported platforms
- Verify health checks pass
- Ensure no security regressions
- Update documentation
- Run smoke tests

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This software is provided for educational and legitimate privacy purposes only. Users are responsible for ensuring their use complies with applicable laws and regulations. The authors are not responsible for any misuse of this software.

## 🔗 Resources

- [Tor Project](https://www.torproject.org/)
- [I2P Project](https://geti2p.net/)
- [ProxyChains-NG](https://github.com/rofl0r/proxychains-ng)
- [Privacy Tools](https://www.privacytools.io/)

---

**Version**: 1.0.0  
**Last Updated**: $(date +%Y-%m-%d)  
**Supported Platforms**: Linux (Debian/Ubuntu), macOS 10.14+, Windows 10/11

