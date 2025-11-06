# Security Policy

## Supported Versions

We support the latest version of DevBox Waker. Please ensure you're using the most recent release.

## Reporting a Vulnerability

If you discover a security vulnerability, please:

1. **Do NOT** open a public issue
2. Email the details to the repository maintainers (or use GitHub's private security advisory feature)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond as quickly as possible and work with you to address the issue.

## Security Best Practices for Users

- **Never commit `config.json`** to version control - it contains your DevBox details
- Store credentials securely using Azure CLI authentication
- Review scheduled task permissions
- Keep Azure CLI updated
- Monitor DevBox wake logs for unexpected activity
- Use the provided `.gitignore` to prevent accidental credential exposure
