# OpSec Tools Security Checklist

This checklist ensures your OpSec Tools installation is secure and properly configured. Complete each section before using the tools in production.

## ✅ Pre-Installation Security

- [ ] **System Requirements Verified**
  - [ ] Operating system is supported (Linux Debian/Ubuntu, macOS 10.14+, Windows 10/11)
  - [ ] At least 2GB free disk space available
  - [ ] System is up to date with latest security patches
  - [ ] No unauthorized software or services running

- [ ] **Network Security**
  - [ ] Firewall is enabled and properly configured
  - [ ] No unnecessary network services running
  - [ ] Network is not compromised or monitored
  - [ ] VPN is considered for additional protection

- [ ] **User Permissions**
  - [ ] Running with appropriate user privileges (not root/admin unless required)
  - [ ] User account has strong password
  - [ ] No unnecessary user accounts with elevated privileges

## ✅ Installation Security

- [ ] **Download Verification**
  - [ ] Installation script downloaded from trusted source
  - [ ] Script integrity verified (if checksums provided)
  - [ ] No suspicious modifications to scripts

- [ ] **Installation Process**
  - [ ] Installation completed without errors
  - [ ] All tools installed successfully
  - [ ] Version pinning confirmed (correct versions installed)
  - [ ] Installation logs reviewed for any warnings

- [ ] **Configuration Security**
  - [ ] ProxyChains DNS leak protection enabled (`proxy_dns` in config)
  - [ ] ProxyChains dynamic_chain mode enabled (`dynamic_chain` in config)
  - [ ] Backup of original configurations created
  - [ ] No hardcoded credentials in configurations
  - [ ] File permissions set correctly

## ✅ Post-Installation Verification

- [ ] **Health Checks Passed**
  - [ ] All services start successfully
  - [ ] Port verification shows services listening on correct ports
  - [ ] Connectivity tests pass for all tools
  - [ ] DNS leak protection verified

- [ ] **Tool-Specific Verification**

  **Tor Browser**:
  - [ ] Tor Browser launches without errors
  - [ ] Visit https://check.torproject.org confirms Tor usage
  - [ ] Security slider set to appropriate level
  - [ ] No JavaScript vulnerabilities (if disabled)
  - [ ] Tor egress test passes: `torsocks curl -s https://check.torproject.org/ | head -n 5`

  **I2P**:
  - [ ] I2P router starts successfully
  - [ ] I2P console accessible at http://127.0.0.1:7657
  - [ ] Router is properly configured
  - [ ] No error messages in I2P logs
  - [ ] I2P health check passes: `curl http://127.0.0.1:7657` responds

  **ProxyChains**:
  - [ ] ProxyChains configuration file exists and is readable
  - [ ] DNS leak protection enabled in configuration (`proxy_dns`)
  - [ ] Dynamic chain mode enabled (`dynamic_chain`)
  - [ ] Test command works: `proxychains4 curl https://httpbin.org/ip`
  - [ ] DNS leak test passes: `proxychains4 dig example.com`

## ✅ Concrete Hardening Measures

- [ ] **ProxyChains Configuration**
  - [ ] `dynamic_chain` configured (more resilient than strict_chain)
  - [ ] `proxy_dns` enabled (prevents DNS leaks)
  - [ ] `socks5 127.0.0.1 9050` (Tor default)
  - [ ] `http 127.0.0.1 4444` (I2P default)
  - [ ] Local network exclusions configured

- [ ] **Tor Egress Verification**
  - [ ] Tor SOCKS port 9050 listening
  - [ ] Egress test passes: `proxychains4 curl https://check.torproject.org/ | head -n 5`
  - [ ] torsocks available and working
  - [ ] No direct connections bypassing Tor

- [ ] **I2P Health Verification**
  - [ ] I2P router process running
  - [ ] HTTP port 7657 responding
  - [ ] Health check passes: `curl http://127.0.0.1:7657`
  - [ ] Router console accessible

- [ ] **Platform-Specific Hardening**

  **Windows**:
  - [ ] winget used for Tor installation (updates & signatures)
  - [ ] Both %ProgramFiles% and %ProgramFiles(x86)% handled
  - [ ] Hash verification for I2P installer
  - [ ] WSL properly configured for ProxyChains

  **macOS**:
  - [ ] proxychains-ng installed via Homebrew
  - [ ] Xcode Command Line Tools installed
  - [ ] Homebrew signature verification working
  - [ ] User configuration in ~/.proxychains/

  **Debian**:
  - [ ] torbrowser-launcher used (handles signature verification)
  - [ ] i2p/i2p-router installed and service enabled
  - [ ] systemctl enable i2p executed
  - [ ] Package manager signatures verified

## ✅ Operational Security

- [ ] **Usage Guidelines**
  - [ ] Never use personal accounts with these tools
  - [ ] No sensitive data transmitted through these proxies
  - [ ] Regular security updates applied
  - [ ] Logs monitored for suspicious activity

- [ ] **Network Monitoring**
  - [ ] Monitor for unusual network activity
  - [ ] Check for DNS leaks using online tools
  - [ ] Verify no traffic bypassing proxies
  - [ ] Monitor system resources for anomalies

- [ ] **Maintenance**
  - [ ] Regular backup of configurations
  - [ ] Tools updated when new versions available
  - [ ] Logs rotated and archived
  - [ ] Security patches applied promptly

## ✅ Advanced Security (Optional)

- [ ] **Additional Hardening**
  - [ ] System-wide firewall rules configured
  - [ ] Network isolation implemented
  - [ ] Additional VPN layer added
  - [ ] System monitoring tools installed

- [ ] **Audit and Compliance**
  - [ ] Regular security audits performed
  - [ ] Compliance with organizational policies
  - [ ] Incident response plan in place
  - [ ] Documentation maintained

## 🔍 Security Testing

### DNS Leak Testing
```bash
# Test for DNS leaks
proxychains4 nslookup google.com
proxychains4 dig example.com
```

### IP Address Testing
```bash
# Verify IP address through proxy
proxychains4 curl https://httpbin.org/ip
proxychains4 curl https://check.torproject.org
```

### Tor Egress Testing
```bash
# Test Tor connectivity
torsocks curl -s https://check.torproject.org/ | head -n 5
proxychains4 curl -s https://check.torproject.org/ | head -n 5
```

### I2P Health Testing
```bash
# Test I2P router health
curl http://127.0.0.1:7657
```

### WebRTC Leak Testing
- [ ] WebRTC disabled in browsers
- [ ] No WebRTC leaks detected
- [ ] Browser fingerprinting minimized

### Traffic Analysis
- [ ] No unencrypted traffic
- [ ] All traffic routed through proxies
- [ ] No direct connections bypassing tools

## ⚠️ Warning Signs

**Immediate Action Required If You See**:
- [ ] DNS queries not going through proxy
- [ ] Direct connections to external sites
- [ ] Unusual network activity
- [ ] Error messages about proxy failures
- [ ] Services not starting or listening
- [ ] Unauthorized access attempts
- [ ] Tor egress tests failing
- [ ] I2P health checks failing

## 📋 Regular Maintenance Checklist

**Weekly**:
- [ ] Review logs for errors or warnings
- [ ] Test all proxy connections
- [ ] Verify DNS leak protection
- [ ] Check for tool updates
- [ ] Run smoke tests: `./smoke_tests.sh`

**Monthly**:
- [ ] Full security audit
- [ ] Configuration backup
- [ ] Performance review
- [ ] Update security documentation

**Quarterly**:
- [ ] Comprehensive security assessment
- [ ] Tool version updates
- [ ] Policy review and updates
- [ ] Training and awareness updates

## 🚨 Emergency Procedures

**If Compromise Suspected**:
1. **Immediate Actions**:
   - [ ] Disconnect from network
   - [ ] Stop all OpSec tools
   - [ ] Document incident details
   - [ ] Preserve evidence

2. **Investigation**:
   - [ ] Review all logs
   - [ ] Check system integrity
   - [ ] Identify attack vector
   - [ ] Assess damage scope

3. **Recovery**:
   - [ ] Clean compromised systems
   - [ ] Reinstall tools if necessary
   - [ ] Update all passwords
   - [ ] Implement additional security measures

## 📞 Support and Resources

- **Documentation**: Review README.md for detailed instructions
- **Logs**: Check `/tmp/opsec_*.log` for troubleshooting
- **Smoke Tests**: Run `./smoke_tests.sh` for comprehensive testing
- **Community**: Seek help from privacy and security communities
- **Professional**: Consider consulting security professionals for critical deployments

---

**Last Updated**: $(date +%Y-%m-%d)  
**Version**: 1.0.0  
**Next Review**: $(date -d "+3 months" +%Y-%m-%d)
