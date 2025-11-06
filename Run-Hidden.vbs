' Run-Hidden.vbs
' VBScript to launch PowerShell script completely hidden (no window flash)

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get the directory where this VBScript is located
strScriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPowerShellScript = objFSO.BuildPath(strScriptDir, "Wake-DevBox.ps1")

' Build the PowerShell command
strCommand = "powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive -WindowStyle Hidden -File """ & strPowerShellScript & """"

' Run completely hidden (0 = hidden window, False = don't wait)
objShell.Run strCommand, 0, False

Set objShell = Nothing
Set objFSO = Nothing
