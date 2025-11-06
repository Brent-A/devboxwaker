# Setup-ScheduledTask.ps1
# Script to configure Windows Task Scheduler to run Wake-DevBox.ps1 on user login

# Requires Administrator privileges
#Requires -RunAsAdministrator

param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot "Wake-DevBox.ps1")
)

# Task properties
$taskName = "Wake DevBox on Login"
$taskDescription = "Automatically wakes DevBox from hibernation when user logs in or unlocks the workstation"
$taskPath = "\DevBox\"
$vbsWrapperPath = Join-Path $PSScriptRoot "Run-Hidden.vbs"

Write-Host "Setting up scheduled task: $taskName" -ForegroundColor Cyan

try {
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-Host "Existing task found. Removing it first..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    }

    # Create the action - run VBScript wrapper to launch PowerShell completely hidden
    $action = New-ScheduledTaskAction `
        -Execute "wscript.exe" `
        -Argument "`"$vbsWrapperPath`"" `
        -WorkingDirectory $PSScriptRoot

    # Create the triggers - at user logon and on workstation unlock
    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn
    
    # Create unlock trigger using CIM class
    $CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
    $triggerUnlock = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
    $triggerUnlock.StateChange = 8  # 8 = SessionUnlock (TASK_SESSION_STATE_CHANGE_TYPE)
    $triggerUnlock.UserId = $env:USERNAME
    $triggerUnlock.Enabled = $true

    # Create the principal - run as current user
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel Limited

    # Create settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -Hidden

    # Register the scheduled task
    $task = Register-ScheduledTask `
        -TaskName $taskName `
        -TaskPath $taskPath `
        -Action $action `
        -Trigger @($triggerLogon, $triggerUnlock) `
        -Principal $principal `
        -Settings $settings `
        -Description $taskDescription `
        -ErrorAction Stop
    
    # Additional step: Modify the task to run hidden (no window)
    # This ensures the task runs with CREATEPROCESS_NOWINDOW flag
    $task.Settings.Hidden = $true
    $task | Set-ScheduledTask | Out-Null

    Write-Host "`nScheduled task created successfully!" -ForegroundColor Green
    Write-Host "Task Name: $taskName" -ForegroundColor Green
    Write-Host "Task Path: $taskPath" -ForegroundColor Green
    Write-Host "`nThe DevBox wake script will run automatically when you:" -ForegroundColor Green
    Write-Host "  - Log in to Windows" -ForegroundColor Green
    Write-Host "  - Unlock your workstation" -ForegroundColor Green
    
    # Display task information
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath
    $task | Format-List TaskName, TaskPath, State, Description
    
    Write-Host "`nTo manually run the task now, use:" -ForegroundColor Yellow
    Write-Host "Start-ScheduledTask -TaskName '$taskName' -TaskPath '$taskPath'" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}
