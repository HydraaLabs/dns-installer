# HydraaLabs DNS - Windows installer
# Sets dns.hydrabrowser.net (45.8.125.44, 185.125.168.124) as system resolver,
# with DNS-over-HTTPS by default on Windows 11.
#
# Usage (PowerShell as Administrator):
#   irm https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.ps1 | iex
#
# Or download then run:
#   iwr https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.ps1 -OutFile install.ps1
#   .\install.ps1                # install with DoH (Win11) / clear (Win10)
#   .\install.ps1 -Mode plain    # force plain DNS
#   .\install.ps1 -Uninstall     # rollback

[CmdletBinding()]
param(
    [ValidateSet('doh','plain')]
    [string]$Mode = 'doh',
    [switch]$Uninstall,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

# ----- Constants ------------------------------------------------------------
$Hostname    = 'dns.hydrabrowser.net'
# Order matters: Windows tries the first server first, fallback to the next.
# Norway (EU) primary for lower latency + EEA privacy. Russia secondary as fallback.
$IPv4Servers = @('185.125.168.124','45.8.125.44')
$DohTemplate = "https://$Hostname/dns-query"

# ----- Helpers --------------------------------------------------------------
function Write-Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "!! $msg" -ForegroundColor Yellow }
function Die($msg) { Write-Host "!! $msg" -ForegroundColor Red; exit 1 }

# Must be admin
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Die "This script must be run as Administrator. Right-click PowerShell -> Run as Administrator."
}

# Confirm prompt
function Confirm($msg) {
    if ($Yes) { return $true }
    Write-Host "$msg [y/N] " -NoNewline
    $a = Read-Host
    return ($a -match '^(y|yes)$')
}

# Detect Windows version
$WinVer = [System.Environment]::OSVersion.Version
$IsWin11 = ($WinVer.Major -eq 10 -and $WinVer.Build -ge 22000)
$DohSupported = $IsWin11 -and (Get-Command Add-DnsClientDohServerAddress -ErrorAction SilentlyContinue)

# ----- Banner ---------------------------------------------------------------
Write-Host ""
Write-Host "HydraaLabs DNS installer (Windows)" -ForegroundColor Cyan
Write-Host "  Hostname : $Hostname"
Write-Host "  Servers  : $($IPv4Servers -join ', ')"
Write-Host "  Mode     : $(if ($Mode -eq 'doh' -and $DohSupported) {'DNS-over-HTTPS'} else {'Plain DNS'})"
Write-Host "  Action   : $(if ($Uninstall) {'uninstall'} else {'install'})"
Write-Host "  Windows  : $($WinVer) ($(if ($IsWin11) {'11'} else {'10 or earlier'}))"
Write-Host ""

if (-not $Uninstall) { if (-not (Confirm "Continue?")) { Write-Info "Aborted"; exit 0 } }

# ----- Action: get all active interfaces ------------------------------------
$ifs = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Virtual -eq $false } | Select-Object -ExpandProperty InterfaceIndex
if (-not $ifs) { Die "No active physical network interfaces found" }

if ($Uninstall) {
    foreach ($i in $ifs) {
        Write-Info "Resetting DNS on interface $i"
        Set-DnsClientServerAddress -InterfaceIndex $i -ResetServerAddresses
        if ($DohSupported) {
            foreach ($ip in $IPv4Servers) {
                Remove-DnsClientDohServerAddress -ServerAddress $ip -ErrorAction SilentlyContinue
            }
        }
    }
    Clear-DnsClientCache
    Write-Info "DNS settings reverted to DHCP defaults"
    exit 0
}

# Install path
foreach ($i in $ifs) {
    Write-Info "Setting DNS on interface $i to $($IPv4Servers -join ', ')"
    Set-DnsClientServerAddress -InterfaceIndex $i -ServerAddresses $IPv4Servers
}

if ($Mode -eq 'doh') {
    if ($DohSupported) {
        Write-Info "Registering DoH for both servers"
        foreach ($ip in $IPv4Servers) {
            Add-DnsClientDohServerAddress -ServerAddress $ip -DohTemplate $DohTemplate -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
        }
        # Force DoH on
        try {
            Set-DnsClientServerAddress -InterfaceIndex $ifs[0] -ServerAddresses $IPv4Servers
        } catch {}
        Write-Info "DoH active for $($IPv4Servers -join ', ')"
    } else {
        Write-Warn "Windows 10 or older: DoH not supported via PowerShell. Plain DNS configured. To enable DoH per-app, configure your browser:"
        Write-Host "  Firefox/Chrome/Edge: set DoH URL to $DohTemplate"
    }
}

Clear-DnsClientCache

Write-Host ""
Write-Info "Done. Test with: Resolve-DnsName example.com"
Write-Info "Rollback: irm https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.ps1 | iex -ArgumentList -Uninstall"
