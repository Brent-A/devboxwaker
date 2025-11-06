# Hibernate-DevBox.ps1
# Script to hibernate a DevBox
# Called from toast notification button

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
    exit 1
}

# Log file path
$logPath = Join-Path $PSScriptRoot "wake-devbox.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - [HIBERNATE] $Message"
    [System.IO.File]::AppendAllText($logPath, "$logMessage`r`n", [System.Text.UTF8Encoding]::new($false))
}

function Get-AzureAccessToken {
    param([string]$Resource = "https://devcenter.azure.com")
    
    try {
        $azPath = (Get-Command az -ErrorAction SilentlyContinue).Source
        if ($azPath) {
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

Write-Log "Starting DevBox hibernate process..."

try {
    # Get access token
    $token = Get-AzureAccessToken
    
    if (-not $token) {
        Write-Log "ERROR: Could not obtain access token."
        exit 1
    }
    
    # Get tenant ID from Azure CLI
    $accountInfo = az account show | ConvertFrom-Json
    $tenantId = $accountInfo.tenantId
    
    # Build the DevBox API endpoint
    $endpoint = "https://$tenantId-$DevCenterName.$Location.devcenter.azure.com"
    $apiVersion = "2023-04-01"
    $uri = "$endpoint/projects/$ProjectName/users/me/devboxes/$($DevBoxName):stop?api-version=$apiVersion&hibernate=true"
    
    # Create headers
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }
    
    # Make the API call to hibernate the DevBox
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ErrorAction Stop
    
    Write-Log "DevBox hibernate command sent successfully!"
    Write-Log "Response: $($response | ConvertTo-Json -Depth 3)"
    
} catch {
    Write-Log "ERROR: Failed to hibernate DevBox - $($_.Exception.Message)"
    exit 1
}

Write-Log "DevBox hibernate process completed successfully."
