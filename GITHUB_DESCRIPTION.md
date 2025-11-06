# DevBox Waker

🚀 Automatically wake your Azure DevBox from hibernation when you log in to Windows

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey.svg)](https://www.microsoft.com/windows)

## Quick Start

1. Install [Azure CLI](https://aka.ms/installazurecliwindows)
2. Copy `config.example.json` to `config.json` and configure your DevBox details
3. Run `.\Setup-ScheduledTask.ps1` as Administrator
4. Done! Your DevBox will wake automatically when you log in

See [README.md](README.md) for detailed instructions.

## Features

✅ Automatic wake on Windows login  
✅ Status monitoring until DevBox is ready  
✅ Windows toast notifications with action buttons  
✅ Connect or Hibernate directly from notification  
✅ Detailed logging  
✅ Azure CLI authentication (corporate-friendly)

## Screenshot

*Toast notification appears when DevBox is running with Connect and Hibernate options*

## Tech Stack

- PowerShell 5.1+
- Azure CLI
- Windows Task Scheduler
- Windows Toast Notifications
