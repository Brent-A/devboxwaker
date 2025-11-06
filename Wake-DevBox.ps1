# Wake-DevBox.ps1
# Script to wake a DevBox from hibernation using REST API
# This script runs automatically on Windows login

param(
    [string]$DevBoxName = "",
    [string]$ProjectName = "",
    [string]$DevCenterName = "",
    [string]$Location = ""
)

# Configuration file path
$configPath = Join-Path $PSScriptRoot "config.json"

# Load configuration from file if it exists
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    
    if ([string]::IsNullOrWhiteSpace($DevBoxName)) { $DevBoxName = $config.DevBoxName }
    if ([string]::IsNullOrWhiteSpace($ProjectName)) { $ProjectName = $config.ProjectName }
    if ([string]::IsNullOrWhiteSpace($DevCenterName)) { $DevCenterName = $config.DevCenterName }
    if ([string]::IsNullOrWhiteSpace($Location)) { $Location = $config.Location }
}

# Validate required parameters
if ([string]::IsNullOrWhiteSpace($DevBoxName) -or 
    [string]::IsNullOrWhiteSpace($ProjectName) -or 
    [string]::IsNullOrWhiteSpace($DevCenterName) -or 
    [string]::IsNullOrWhiteSpace($Location)) {
    Write-Error "Missing required parameters. Please configure config.json with DevBoxName, ProjectName, DevCenterName, and Location."
    exit 1
}

# Log file path
$logPath = Join-Path $PSScriptRoot "wake-devbox.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    # Use UTF8 encoding without BOM for better compatibility
    [System.IO.File]::AppendAllText($logPath, "$logMessage`r`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host $Message
}

function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$DevBoxUri = "",
        [string]$HibernateScriptPath = ""
    )
    
    Write-Log "Notification: $Title - $Message"
    
    # Use helper script with Windows PowerShell 5.1 for toast notifications
    try {
        $toastScript = Join-Path $PSScriptRoot "Show-Toast.ps1"
        
        if (Test-Path $toastScript) {
            # Run in Windows PowerShell (not Core) for better WinRT support
            $args = @(
                "-ExecutionPolicy", "Bypass",
                "-File", $toastScript,
                "-Title", $Title,
                "-Message", $Message
            )
            
            if ($DevBoxUri) {
                $args += @("-DevBoxUri", $DevBoxUri)
            }
            
            if ($HibernateScriptPath) {
                $args += @("-HibernateScriptPath", $HibernateScriptPath)
            }
            
            $result = powershell.exe @args 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Toast notification displayed successfully"
                return
            } else {
                Write-Log "Toast script failed: $result"
            }
        } else {
            Write-Log "Toast script not found at: $toastScript"
        }
    } catch {
        Write-Log "Failed to show toast notification: $($_.Exception.Message)"
    }
    
    # Fallback to popup if toast fails
    try {
        $wshell = New-Object -ComObject Wscript.Shell
        $null = $wshell.Popup($Message, 10, $Title, 0x40)
        Write-Log "Showed popup notification as fallback"
    } catch {
        Write-Log "Failed to show any notification: $($_.Exception.Message)"
    }
}

function Get-OperationStatus {
    param(
        [string]$OperationId,
        [string]$Endpoint,
        [string]$Token
    )
    
    try {
        $apiVersion = "2023-04-01"
        $uri = "$Endpoint/projects/$ProjectName/operationstatuses/$($OperationId)?api-version=$apiVersion"
        
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
        return $response
    } catch {
        Write-Log "Failed to get operation status: $($_.Exception.Message)"
        return $null
    }
}

function Get-DevBoxState {
    param(
        [string]$Endpoint,
        [string]$Token
    )
    
    try {
        $apiVersion = "2023-04-01"
        $uri = "$Endpoint/projects/$ProjectName/users/me/devboxes/$($DevBoxName)?api-version=$apiVersion"
        
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
        
        Write-Log "DevBox current state: $($response.powerState)"
        return $response
    } catch {
        Write-Log "Failed to get DevBox state: $($_.Exception.Message)"
        return $null
    }
}

function Get-DevBoxConnectionUri {
    param(
        [string]$Endpoint,
        [string]$Token
    )
    
    try {
        $apiVersion = "2025-02-01"
        $uri = "$Endpoint/projects/$ProjectName/users/me/devboxes/$($DevBoxName)/remoteConnection?api-version=$apiVersion"
        
        $headers = @{
            "Authorization" = "Bearer $Token"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
        
        # Log all available connection URLs for debugging
        Write-Log "Available connection URLs:"
        if ($response.cloudPcConnectionUrl) { Write-Log "  cloudPcConnectionUrl: $($response.cloudPcConnectionUrl)" }
        if ($response.rdpConnectionUrl) { Write-Log "  rdpConnectionUrl: $($response.rdpConnectionUrl)" }
        if ($response.webUrl) { Write-Log "  webUrl: $($response.webUrl)" }
        
        # Check if rdpConnectionUrl uses a supported protocol
        $supportedProtocols = @('ms-cloudpc:', 'ms-remotedesktop:', 'ms-remotedesktop-launch:', 'ms-cp:')
        $useRdpUrl = $false
        
        if ($response.rdpConnectionUrl) {
            foreach ($protocol in $supportedProtocols) {
                if ($response.rdpConnectionUrl -like "$protocol*") {
                    $useRdpUrl = $true
                    break
                }
            }
        }
        
        # Priority: cloudPcConnectionUrl (Windows App native) > supported RDP protocols > webUrl
        if ($response.cloudPcConnectionUrl) {
            Write-Log "Using Cloud PC connection URL (Windows App native)"
            return $response.cloudPcConnectionUrl
        } elseif ($useRdpUrl) {
            Write-Log "Using RDP connection URL (supported protocol)"
            return $response.rdpConnectionUrl
        } elseif ($response.webUrl) {
            Write-Log "Using web connection URL (fallback)"
            return $response.webUrl
        } elseif ($response.rdpConnectionUrl) {
            Write-Log "Using RDP connection URL (may not be supported)"
            return $response.rdpConnectionUrl
        } else {
            Write-Log "No connection URL in response"
            return $null
        }
    } catch {
        Write-Log "Failed to get DevBox connection URI: $($_.Exception.Message)"
        return $null
    }
}

function Get-AzureAccessToken {
    param([string]$Resource = "https://devcenter.azure.com")
    
    try {
        # Try to get token using az CLI (more reliable with managed devices)
        $azPath = (Get-Command az -ErrorAction SilentlyContinue).Source
        if ($azPath) {
            Write-Log "Using Azure CLI for authentication..."
            $tokenJson = az account get-access-token --resource $Resource 2>$null | ConvertFrom-Json
            if ($tokenJson.accessToken) {
                return $tokenJson.accessToken
            }
        }
    } catch {
        Write-Log "Azure CLI authentication not available: $($_.Exception.Message)"
    }
    
    return $null
}

Write-Log "Starting DevBox wake process..."
Write-Log "DevBox: $DevBoxName, Project: $ProjectName, DevCenter: $DevCenterName, Location: $Location"

# Download icon if not present
$iconPath = Join-Path $PSScriptRoot "devbox-icon.png"
if (-not (Test-Path $iconPath)) {
    try {
        Write-Log "Downloading DevBox icon..."
        $iconUrl = "https://img.icons8.com/fluency/96/laptop.png"
        Invoke-WebRequest -Uri $iconUrl -OutFile $iconPath -UseBasicParsing -ErrorAction Stop
        Write-Log "Icon downloaded successfully"
    } catch {
        Write-Log "Failed to download icon: $($_.Exception.Message)"
    }
}

try {
    # Get access token
    Write-Log "Authenticating with Azure..."
    $token = Get-AzureAccessToken
    
    if (-not $token) {
        Write-Log "ERROR: Could not obtain access token."
        Write-Log "Please ensure Azure CLI is installed and you are logged in:"
        Write-Log "  1. Install Azure CLI from: https://aka.ms/installazurecliwindows"
        Write-Log "  2. Run: az login"
        throw "Authentication failed - Azure CLI not configured"
    }
    
    Write-Log "Successfully authenticated."
    
    # Get tenant ID from Azure CLI
    $accountInfo = az account show | ConvertFrom-Json
    $tenantId = $accountInfo.tenantId
    Write-Log "Tenant ID: $tenantId"
    
    # Build the DevBox API endpoint
    # Try different endpoint formats
    $endpoints = @(
        "https://$tenantId-$DevCenterName.$Location.devcenter.azure.com",
        "https://$DevCenterName-$tenantId.$Location.devcenter.azure.com",
        "https://$DevCenterName.$Location.devcenter.azure.com"
    )
    
    $apiVersion = "2023-04-01"
    $success = $false
    $workingEndpoint = $null
    
    # First, find a working endpoint by checking DevBox state
    foreach ($endpoint in $endpoints) {
        Write-Log "Trying endpoint: $endpoint"
        
        try {
            # Get DevBox state to check if it's already running
            $devBoxState = Get-DevBoxState -Endpoint $endpoint -Token $token
            
            if ($devBoxState) {
                $workingEndpoint = $endpoint
                Write-Log "Successfully connected to endpoint: $endpoint"
                Write-Log "DevBox power state: $($devBoxState.powerState)"
                
                # Check if DevBox is already running
                if ($devBoxState.powerState -eq "Running") {
                    Write-Log "DevBox is already running - no need to wake"
                    
                    # Get the connection URI
                    $connectionUri = Get-DevBoxConnectionUri -Endpoint $endpoint -Token $token
                    
                    # Get the hibernate script path
                    $hibernateScript = Join-Path $PSScriptRoot "Hibernate-DevBox.ps1"
                    
                    if ($connectionUri) {
                        Show-Notification -Title "DevBox Ready" -Message "Your DevBox '$DevBoxName' is already running and ready to use." -DevBoxUri $connectionUri -HibernateScriptPath $hibernateScript
                    } else {
                        Show-Notification -Title "DevBox Ready" -Message "Your DevBox '$DevBoxName' is already running and ready to use."
                    }
                    
                    Write-Log "DevBox wake process completed - already running."
                    exit 0
                } elseif ($devBoxState.powerState -eq "Stopping" -or $devBoxState.powerState -eq "Deallocating") {
                    Write-Log "DevBox is currently shutting down (state: $($devBoxState.powerState)) - cannot wake yet"
                    Show-Notification -Title "DevBox Shutting Down" -Message "Your DevBox '$DevBoxName' is currently shutting down. Please wait and try again in a few moments."
                    Write-Log "DevBox wake process aborted - DevBox is shutting down."
                    exit 0
                } elseif ($devBoxState.powerState -eq "Starting") {
                    Write-Log "DevBox is already starting - no need to wake"
                    Show-Notification -Title "DevBox Starting" -Message "Your DevBox '$DevBoxName' is already starting up. Please wait..."
                    Write-Log "DevBox wake process completed - already starting."
                    exit 0
                }
                
                # DevBox is not running, proceed with wake
                break
            }
        } catch {
            Write-Log "Failed with endpoint $endpoint - $($_.Exception.Message)"
            continue
        }
    }
    
    if (-not $workingEndpoint) {
        throw "Could not connect to DevBox API with any known endpoint format"
    }
    
    # Show notification that we're waking the DevBox
    Show-Notification -Title "Waking DevBox" -Message "Starting your DevBox '$DevBoxName'... This may take a few minutes."
    
    # Now send the wake command
    Write-Log "Sending wake command to DevBox..."
    $uri = "$workingEndpoint/projects/$ProjectName/users/me/devboxes/$($DevBoxName):start?api-version=$apiVersion"
    
    # Create headers
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    try {
        # Make the API call to start the DevBox
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ErrorAction Stop
        
        Write-Log "DevBox wake command sent successfully!"
        Write-Log "Response: $($response | ConvertTo-Json -Depth 3)"
        
        # Extract operation ID from response
        if ($response.id) {
            $operationId = $response.name
            Write-Log "Monitoring operation: $operationId"
            
            # Poll for operation completion (max 5 minutes)
            $maxAttempts = 60  # 5 minutes with 5-second intervals
            $attempt = 0
            $operationComplete = $false
            
            while ($attempt -lt $maxAttempts -and -not $operationComplete) {
                Start-Sleep -Seconds 5
                $attempt++
                
                $status = Get-OperationStatus -OperationId $operationId -Endpoint $workingEndpoint -Token $token
                
                if ($status) {
                    Write-Log "Operation status: $($status.status)"
                    
                    if ($status.status -eq "Succeeded") {
                        $operationComplete = $true
                        Write-Log "DevBox is now running!"
                        
                        # Get the RDP connection URI
                        $connectionUri = Get-DevBoxConnectionUri -Endpoint $workingEndpoint -Token $token
                        
                        # Get the hibernate script path
                        $hibernateScript = Join-Path $PSScriptRoot "Hibernate-DevBox.ps1"
                        
                        if ($connectionUri) {
                            Show-Notification -Title "DevBox Ready" -Message "Click to connect to '$DevBoxName'" -DevBoxUri $connectionUri -HibernateScriptPath $hibernateScript
                        } else {
                            Show-Notification -Title "DevBox Ready" -Message "Your DevBox '$DevBoxName' is now running and ready to use."
                        }
                        break
                    } elseif ($status.status -eq "Failed") {
                        Write-Log "Operation failed: $($status.error | ConvertTo-Json -Depth 3)"
                        Show-Notification -Title "DevBox Failed" -Message "Failed to wake DevBox '$DevBoxName'. Check logs for details."
                        break
                    }
                    # Continue polling if status is "Running", "NotStarted", etc.
                }
            }
            
            if (-not $operationComplete -and $attempt -ge $maxAttempts) {
                Write-Log "Operation monitoring timed out after 5 minutes"
                Show-Notification -Title "DevBox Status Unknown" -Message "DevBox '$DevBoxName' wake initiated, but status check timed out."
            }
        }
        
        $success = $true
    } catch {
        Write-Log "Failed to send wake command - $($_.Exception.Message)"
        throw
    }
    
    if (-not $success) {
        throw "Failed to wake DevBox"
    }
    
} catch {
    Write-Log "ERROR: Failed to wake DevBox - $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $responseBody = $reader.ReadToEnd()
        Write-Log "API Response: $responseBody"
    }
    Write-Log "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}

Write-Log "DevBox wake process completed successfully."
