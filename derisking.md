# Security Audit Report - Derisking Action Items

**Date**: 2025-01-28
**Repository**: Public dotfiles repository
**Status**: CRITICAL - Immediate action required

---

## Executive Summary

This repository contains **CRITICAL security vulnerabilities** that must be addressed immediately. The following sensitive information is currently exposed in the public repository:

- 🔴 OpenAI API key (can be used to charge your account)
- 🔴 AWS credentials (full AWS access)
- 🟠 Personal email addresses
- 🟡 VPN/proxy configurations
- 🟡 WiFi passwords
- 🟡 Various private keys

**All secrets must be rotated (revoked and regenerated) immediately, even after removing them from the repository.**

---

## CRITICAL Issues - Act Immediately!

### 1. OpenAI API Key Exposed
- **File**: `oh-my-zsh/.zshrc:137`
- **Risk Level**: 🔴 **CRITICAL**
- **Exposed Data**: `sk-e8be341407c049d4ac2c444616570197`
- **Impact**: Anyone can use this key to make API charges to your OpenAI account
- **Action Required**:
  1. Immediately revoke this key at https://platform.openai.com/api-keys
  2. Remove the key from `.zshrc`
  3. Use environment variable instead: `export OPENAI_API_KEY="your-key-here"`
  4. Never commit API keys to public repositories

### 2. AWS Credentials Exposed
- **File**: `oh-my-zsh/.zshrc:141-142`
- **Risk Level**: 🔴 **CRITICAL**
- **Exposed Data**:
  - `AWS_ACCESS_KEY_ID`: `3oKbnnJVn5DoEMYS`
  - `AWS_SECRET_ACCESS_KEY`: `NB6ui64uM7lvTMML`
- **Impact**: Full AWS account access - can create resources, steal data, charge services
- **Action Required**:
  1. Immediately revoke these credentials in AWS IAM Console
  2. Remove credentials from `.zshrc`
  3. Use AWS credentials file (`~/.aws/credentials`) with proper permissions (600)
  4. Or use AWS IAM roles for EC2/containers
  5. Set up AWS MFA on your account

---

## HIGH Risk Issues

### 3. Personal Email Exposed
- **File**: `doom_emacs/init.el:172`
- **Risk Level**: 🟠 **HIGH**
- **Exposed Data**: `linxichen88@gmail.com`
- **Impact**: Spam, targeted phishing attacks, social engineering
- **Action Required**:
  1. Replace with a placeholder or environment variable
  2. Consider using a separate email address for public code
  3. Or remove personal identifiers entirely

### 4. SSH Private Repository URL
- **File**: `.gitmodules:3`
- **Risk Level**: 🟠 **HIGH** (if SSH key is exposed)
- **Exposed Data**: `ssh://git@github.com/linxichen/kickstart.nvim.git`
- **Impact**: If your SSH key is compromised, attackers could access your private repo
- **Action Required**:
  1. Ensure this is intentional
  2. Consider using HTTPS with personal access token instead
  3. Rotate SSH keys if any concerns

---

## MEDIUM Risk Issues

### 5. Shadowsocks VPN Configuration
- **File**: `shadowsocks/client_config.json:2-9`
- **Risk Level**: 🟡 **MEDIUM**
- **Exposed Data**:
  - Server: `empirechen.colab.duke.edu:9394`
  - Password: `880420`
- **Impact**: Attackers could use your VPN server, potentially logging traffic
- **Action Required**:
  1. Change VPN server password immediately
  2. Remove this config from public repo
  3. Use environment variables or separate config file
  4. Add `*.json` config files to `.gitignore`

### 6. eval() Usage in SSH Agent Script
- **File**: `ubuntu_profile_d/ssh-agent.sh:1`
- **Risk Level**: 🟡 **MEDIUM**
- **Issue**: Using eval with ssh-agent output can be exploited
- **Impact**: Potential command injection vulnerability
- **Action Required**:
  1. Use ssh-agent directly without eval
  2. Or use: `eval "$(ssh-agent -s)"` with proper quoting

### 7. GitHub Token Reference
- **File**: `spacemacs/dotspacemacs_linuxmint:362`
- **Risk Level**: 🟡 **MEDIUM**
- **Exposed Data**: `(paradox-github-token t)`
- **Impact**: May reference a token - verify it's not stored elsewhere
- **Action Required**:
  1. Ensure token is stored securely (not in this file)
  2. Use environment variable or auth source

---

## LOW Risk Issues

### 8. WiFi Password
- **File**: `scripts/mba_wifi.sh:1-3`
- **Risk Level**: 🟢 **LOW**
- **Exposed Data**: WiFi password `pieordie`
- **Impact**: Local network access (if attacker is physically nearby)
- **Action Required**:
  1. Remove device-specific configs from public repo
  2. Add to `.gitignore`

### 9. OpenVPN Static Key
- **File**: `install/ta.key:4-21`
- **Risk Level**: 🟢 **LOW**
- **Exposed Data**: 2048-bit OpenVPN static key
- **Impact**: If this is a real key, VPN traffic could be decrypted
- **Action Required**:
  1. Verify if this is a test key or production
  2. Remove any keys from public repositories
  3. Regenerate if production key

---

## IMMEDIATE ACTION CHECKLIST

### Step 1: Rotate All Credentials (Do This First)
- [ ] Revoke OpenAI API key at platform.openai.com
- [ ] Revoke AWS credentials in AWS IAM Console
- [ ] Change VPN password
- [ ] Rotate SSH keys if needed
- [ ] Change WiFi password
- [ ] Regenerate OpenVPN key if needed

### Step 2: Remove Sensitive Data from Files
- [ ] Remove API key from `oh-my-zsh/.zshrc`
- [ ] Remove AWS keys from `oh-my-zsh/.zshrc`
- [ ] Remove email from `doom_emacs/init.el` or use placeholder
- [ ] Remove VPN config from `shadowsocks/client_config.json`
- [ ] Remove WiFi script from `scripts/mba_wifi.sh`
- [ ] Remove OpenVPN key from `install/ta.key`

### Step 3: Clean Git History
**CRITICAL**: Even after removing files from current version, they still exist in git history!

```bash
# Option 1: Remove sensitive files from history
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch oh-my-zsh/.zshrc" \
  --prune-empty --tag-name-filter cat -- --all

# Option 2: Use BFG Repo-Cleaner (faster)
# Download: https://rtyley.github.io/bfg-repo-cleaner/
java -jar bfg.jar --delete-files oh-my-zsh/.zshrc
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Option 3: Create new clean repo (safest)
git init new-clean-repo
# Copy files (excluding sensitive ones)
# Force push to new remote
```

### Step 4: Prevent Future Exposure
- [ ] Create `.env.example` file with placeholders
- [ ] Add `.env` to `.gitignore`
- [ ] Add `*.secret`, `*.key`, `credentials.yml` to `.gitignore`
- [ ] Set up git-secrets or similar to prevent future commits
- [ ] Review all commits before pushing

---

## Recommended Security Structure

### 1. Create Secure Template Files

```bash
# .env.example (commit this)
OPENAI_API_KEY=your_openai_api_key_here
AWS_ACCESS_KEY_ID=your_aws_access_key_here
AWS_SECRET_ACCESS_KEY=your_aws_secret_key_here

# .env.local (don't commit this)
OPENAI_API_KEY=sk-actual-key-here
AWS_ACCESS_KEY_ID=actual-key-here
AWS_SECRET_ACCESS_KEY=actual-secret-here
```

### 2. Update .gitignore

```gitignore
# Environment files
.env
.env.local
.env.*.local

# Keys and secrets
*.key
*.secret
*.pem
id_rsa
id_rsa.pub

# Sensitive configs
shadowsocks/client_config.json
scripts/mba_wifi.sh
install/ta.key
```

### 3. Update Scripts to Use Environment Variables

Instead of hardcoding in `.zshrc`:
```bash
# Don't do this:
export OPENAI_API_KEY="sk-exposed-key"

# Do this:
if [ -f "$HOME/.env.local" ]; then
    source "$HOME/.env.local"
fi
```

---

## Ongoing Security Best Practices

### Preventive Measures

1. **Use git-secrets** to prevent future commits:
   ```bash
   git install-secrets
   git secrets --add "sk_"
   git secrets --add "AWS_ACCESS_KEY_ID"
   git secrets --register-aws
   ```

2. **Pre-commit Hooks**:
   ```bash
   # .git/hooks/pre-commit
   git diff --cached --name-only | grep -E "\.(env|key|pem)$" && {
       echo "Commit rejected: attempting to commit sensitive file"
       exit 1
   }
   ```

3. **Regular Audits**:
   - Scan repo with [git-secrets](https://github.com/awslabs/git-secrets)
   - Use [truffleHog](https://github.com/trufflesecurity/trufflehog) to find secrets
   - Review GitHub Security advisories

4. **Monitor Exposure**:
   - Check [Have I Been Pwned](https://haveibeenpwned.com/)
   - Monitor GitHub for forks that may contain exposed secrets
   - Set up alerts for API usage

---

## Tools to Help

### Scanning Tools
- **git-secrets**: AWS's tool to prevent secrets in commits
- **truffleHog**: Finds secrets in git history
- **gitleaks**: Audits repo for secrets
- **GitGuardian**: Monitors repos for exposed secrets

### Secret Management Options
- **Environment variables**: Simple, not versioned
- **git-secret**: GPG encryption in git
- **git-crypt**: Transparent file encryption
- **Vault (HashiCorp)**: Enterprise secret management
- **AWS Secrets Manager**: Cloud-native for AWS

---

## Next Steps

1. ✅ Read through this entire document
2. 🔴 **Immediately** rotate all exposed credentials
3. 📝 Create a plan for which method to use for secrets
4. 🧹 Clean up the repository (remove sensitive data)
5. 🔄 Clean git history
6. 🛡️ Set up preventive measures
7. ✅ Test that everything still works

---

## Additional Resources

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Security Best Practices](https://docs.github.com/en/security)
- [Git Secrets Documentation](https://github.com/awslabs/git-secrets)
- [12 Factor App - Config](https://12factor.net/config)

---

**Remember**: Once something is committed to a public git repository, it's potentially already been scraped, even if you delete it later. **Always rotate credentials after exposure.**

**Last Updated**: 2025-01-28
