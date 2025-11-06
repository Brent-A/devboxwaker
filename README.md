# DevBox Waker

Automatically wake your Azure DevBox from hibernation when you log in to your Windows laptop or unlock your workstation.

## Overview

This project contains PowerShell scripts that integrate with Windows Task Scheduler to automatically wake your DevBox from hibernation at `https://devbox.microsoft.com/` whenever you log in to your laptop or unlock your workstation.

**Features:**

- Automatic DevBox wake on Windows login and workstation unlock
- Monitors operation status until DevBox is ready
- Shows Windows toast notification when DevBox is running
- **Two-button notification**: Connect immediately or Hibernate if not needed
- Detailed logging with UTF-8 encoding
- Uses Azure CLI for authentication (works with corporate device policies)

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- Azure DevBox subscription
- **Azure CLI** ([Download here](https://aka.ms/installazurecliwindows))
- Administrator privileges (for initial scheduled task setup only)

## Setup Instructions

### 1. Configure Your DevBox Details

Create a `config.json` file from the example template:

```powershell
Copy-Item config.example.json config.json
```

Then edit `config.json` with your DevBox information:

```json
{
  "DevBoxName": "your-devbox-name",
  "ProjectName": "your-project-name",
  "DevCenterName": "your-devcenter-name",
  "Location": "your-location"
}
```

**How to find these values:**

Run this PowerShell command to list your projects and find the correct values:

```powershell
# You'll need to authenticate first if not already logged in
az login

# This will show your DevCenter name and location
# Look for these in your project details at devbox.microsoft.com
```

Or use the DevBox MCP tools if available in your VS Code environment.

**To find these values:**

- **DevBoxName**: The name of your DevBox (visible at devbox.microsoft.com)
- **ProjectName**: Your DevBox project name
- **DevCenterName**: The actual name of your Dev Center resource (NOT the region)
  - This is the unique identifier given to your Dev Center when it was created
  - Examples: `mycompany-devcenter`, `engineering-dc`, `contoso-dev`
  - You can find this in the Azure Portal or ask your Azure administrator
  - **Note**: This is different from the region - don't use "West US 2" or similar region names here
- **Location**: Azure region code where your Dev Center is hosted
  - Examples: `westus2`, `eastus`, `westus3`, `centralus`
  - Use the short region code, not the display name
  - Must match the region where your Dev Center is actually deployed

**Tip**: To discover your DevCenter name and location:
1. Visit devbox.microsoft.com and inspect your DevBox details
2. Ask your Azure administrator
3. Use the DevBox MCP tools in VS Code if available

### 2. Install and Configure Azure CLI

**Install Azure CLI** if you haven't already:

1. Download from: https://aka.ms/installazurecliwindows
2. Run the installer
3. Open a **new** PowerShell window (to refresh PATH)
4. Login to Azure:
   ```powershell
   az login
   ```

This uses Azure CLI instead of PowerShell modules, which works better with corporate device compliance policies.

Run the wake script to test:

```powershell
.\Wake-DevBox.ps1
```

If successful, you'll see log messages indicating the DevBox wake command was sent.

### 4. Install the Scheduled Task

Run the setup script with **Administrator** privileges:

```powershell
# Right-click PowerShell and select "Run as Administrator"
.\Setup-ScheduledTask.ps1
```

This will create a Windows scheduled task that runs `Wake-DevBox.ps1` automatically when you log in or unlock your workstation.

### 3. Verify the Setup

Check that the task was created successfully:

```powershell
Get-ScheduledTask -TaskName "Wake DevBox on Login" -TaskPath "\DevBox\"
```

### 5. Done!

## Usage

### Automatic Wake on Login/Unlock

Once configured, the script will automatically run when you:

- Log in to Windows
- Unlock your workstation (after locking it with Win+L or screen timeout)

No manual intervention is required.

### Manual Wake

To manually wake your DevBox without logging out:

```powershell
.\Wake-DevBox.ps1
```

Or run the scheduled task:

```powershell
Start-ScheduledTask -TaskName "Wake DevBox on Login" -TaskPath "\DevBox\"
```

## Logs

The script creates a log file at `wake-devbox.log` in the same directory. Check this file if you encounter any issues:

```powershell
Get-Content .\wake-devbox.log -Tail 20
```

## Troubleshooting

### Authentication Issues

**The script now uses Azure CLI** instead of PowerShell modules to avoid device compliance issues.

If you see authentication errors:

1. **Ensure Azure CLI is installed**:
   ```powershell
   az --version
   ```

2. **Login with Azure CLI**:
   ```powershell
   az login
   ```

3. **Run the script manually** to verify it works:
   ```powershell
   .\Wake-DevBox.ps1
   ```

4. Once manual execution succeeds, the scheduled task will work automatically

**Note**: If you previously had device compliance errors (Error 530033), using Azure CLI should resolve this issue.

### Task Not Running

1. Verify the task exists:
   ```powershell
   Get-ScheduledTask -TaskName "Wake DevBox on Login" -TaskPath "\DevBox\"
   ```

2. Check task history in Task Scheduler:
   - Press `Win + R`, type `taskschd.msc`, press Enter
   - Navigate to `DevBox` folder
   - Right-click the task and select "Properties" → "History" tab

### Module Installation Issues

The script no longer uses PowerShell Az modules. It uses Azure CLI instead, which should be installed separately (see Prerequisites).

## Uninstall

To remove the scheduled task:

```powershell
# Run as Administrator
Unregister-ScheduledTask -TaskName "Wake DevBox on Login" -TaskPath "\DevBox\" -Confirm:$false
```

## Files

- `Wake-DevBox.ps1` - Main script that wakes the DevBox and monitors status
- `Hibernate-DevBox.ps1` - Script to hibernate the DevBox
- `Hibernate-DevBox.bat` - Batch wrapper for toast notification button
- `Show-Toast.ps1` - Helper script for Windows toast notifications
- `Setup-ScheduledTask.ps1` - Configures Windows Task Scheduler
- `config.example.json` - Template configuration file (copy to config.json)
- `config.json` - Your personal DevBox configuration (excluded from git)
- `wake-devbox.log` - Log file (created at runtime)
- `README.md` - This file

## Security Notes

- The scheduled task runs with your user privileges (not elevated)
- Azure credentials are managed securely by the Az PowerShell module
- No passwords or secrets are stored in the configuration files

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Security

See [SECURITY.md](SECURITY.md) for security policies and how to report vulnerabilities.

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built for use with [Azure DevBox](https://azure.microsoft.com/products/dev-box/)
- Uses Azure CLI for authentication

## Support

- 🐛 [Report a Bug](https://github.com/Brent-A/devboxwaker/issues)
- 💡 [Request a Feature](https://github.com/Brent-A/devboxwaker/issues)
- 📖 [View Documentation](README.md)

---

**Note**: Remember to update your `config.json` with your actual DevBox details and never commit it to version control!
