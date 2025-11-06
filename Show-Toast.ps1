# Show-Toast.ps1
# Helper script to show Windows toast notifications
# Must run in Windows PowerShell 5.1 (not PowerShell Core)

param(
    [string]$Title = "Notification",
    [string]$Message = "Message",
    [string]$DevBoxUri = "",
    [string]$HibernateScriptPath = ""
)

try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null

    $APP_ID = 'DevBox Waker'

    # XML-encode the URI and message to prevent parsing errors
    function Convert-XmlString {
        param([string]$text)
        return [System.Security.SecurityElement]::Escape($text)
    }

    $escapedTitle = Convert-XmlString $Title
    $escapedMessage = Convert-XmlString $Message
    $escapedUri = Convert-XmlString $DevBoxUri
    
    # Convert Windows path to file:/// URI for batch file
    $hibernateFileUri = ""
    if ($HibernateScriptPath) {
        # Change .ps1 to .bat and create file:/// URI
        $batPath = $HibernateScriptPath -replace '\\.ps1$','.bat'
        $hibernateFileUri = "file:///$($batPath -replace '\\','/')"
    }
    $escapedHibernateUri = Convert-XmlString $hibernateFileUri

    # Build actions section with both Connect and Hibernate buttons
    $actionsXml = ""
    if ($DevBoxUri -and $hibernateFileUri) {
        # Both buttons: Connect and Hibernate
        $actionsXml = @"
    <actions>
        <action content="Connect Now" arguments="$escapedUri" activationType="protocol"/>
        <action content="Hibernate" arguments="$escapedHibernateUri" activationType="protocol" hint-toolTip="Put DevBox back to sleep"/>
    </actions>
"@
    } elseif ($DevBoxUri) {
        # Just Connect button
        $actionsXml = @"
    <actions>
        <action content="Connect Now" arguments="$escapedUri" activationType="protocol"/>
    </actions>
"@
    }

    # Build the toast XML with activation URI
    # Use local icon file if available
    $iconPath = Join-Path (Split-Path -Parent $PSCommandPath) "devbox-icon.png"
    $iconXml = ""
    if (Test-Path $iconPath) {
        $iconUri = "file:///$($iconPath -replace '\\','/')"
        $iconXml = "<image placement=`"appLogoOverride`" hint-crop=`"circle`" src=`"$iconUri`/>"
    }
    
    $template = @"
<toast launch="$escapedUri" activationType="protocol">
    <visual>
        <binding template="ToastGeneric">
            <text>$escapedTitle</text>
            <text>$escapedMessage</text>
            $iconXml
        </binding>
    </visual>
$actionsXml
    <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
    
    exit 0
} catch {
    Write-Error "Failed to show toast: $_"
    exit 1
}