# HydraaLabs DNS — installer

Encrypted public DNS resolver. One-line install on Linux, macOS, Windows. Profile + instructions for iOS, Android, browsers, routers.

| Endpoint | Address |
|---|---|
| Hostname | `dns.hydrabrowser.net` |
| IPv4 | `45.8.125.44` (Saint Petersburg, RU) — `185.125.168.124` (Sandefjord, NO) |
| DoT | `dns.hydrabrowser.net:853` |
| DoH | `https://dns.hydrabrowser.net/dns-query` |
| Plain DNS | port `53` (UDP/TCP) |

DNSSEC validation enabled. No query logs. ANY queries refused (anti-amplification).

---

## Linux / macOS

One line, default DoT:

```bash
curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | sh
```

Plain DNS (no encryption) instead:

```bash
curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | sh -s -- --plain
```

Uninstall / rollback:

```bash
curl -fsSL https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.sh | sh -s -- --uninstall
```

The script auto-detects your DNS manager (`systemd-resolved`, NetworkManager, `resolvconf`) and applies the right config. macOS uses `networksetup` for plain DNS; for system-wide DoT install the [.mobileconfig](ios/hydrabrowser-dns.mobileconfig).

## Windows

PowerShell **as Administrator**:

```powershell
irm https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.ps1 | iex
```

Windows 11 22H2+ gets DNS-over-HTTPS automatically. Older Windows gets plain DNS only — configure DoH in your browser instead (see [browsers.md](docs/browsers.md)).

Force plain DNS or uninstall:

```powershell
$args = @{ Mode = 'plain' }; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.ps1))) @args
$args = @{ Uninstall = $true }; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/install.ps1))) @args
```

## iOS / iPadOS / macOS (DoT or DoH profile)

1. On the device, download one of:
   - [DoT profile](https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/ios/hydrabrowser-dns.mobileconfig)
   - [DoH profile](https://raw.githubusercontent.com/HydraaLabs/dns-installer/main/ios/hydrabrowser-dns-doh.mobileconfig)
2. Open the file. iOS prompts to install in Settings.
3. Settings → General → VPN & Device Management → Profile downloaded → Install
4. Enter device passcode → Install

Profiles are unsigned; iOS shows a "Not Verified" warning — that's expected for community profiles.

To remove: Settings → General → VPN & Device Management → tap the profile → Remove Profile.

## Android (9+)

Built-in **Private DNS** (DNS over TLS):

1. Settings → Network & Internet → Private DNS
2. Select **Private DNS provider hostname**
3. Enter: `dns.hydrabrowser.net`
4. Save

That's it. All apps now use encrypted DNS.

## Routers

See [docs/routers.md](docs/routers.md) for OpenWrt, OPNsense, pfSense, Mikrotik snippets.

## Browsers (DoH only)

If you don't want to change system DNS, just configure the browser. See [docs/browsers.md](docs/browsers.md).

Quick:
- **Firefox**: Settings → Privacy & Security → DNS over HTTPS → Custom: `https://dns.hydrabrowser.net/dns-query`
- **Chrome / Edge**: Settings → Privacy & Security → Use secure DNS → Custom: `https://dns.hydrabrowser.net/dns-query`

## Verifying

After install, verify your DNS is being used:

```bash
# Should resolve normally
dig +short example.com

# Linux: confirm DoT is active
resolvectl status | grep -E "DNSOverTLS|DNS Server"

# Show what's actually answering (TLS = DoT working)
sudo tcpdump -i any 'host 45.8.125.44 or host 185.125.168.124' -nn -c 5
```

## Privacy

- **No query logs** — we do not record DNS queries to disk or any third party.
- **DNSSEC validation** — enabled.
- **No filtering** — vanilla recursive resolver, no blocklists, no rewrites.
- **TLS certificate** — Let's Encrypt, auto-renewing.

Abuse: `abuse@hydrabrowser.net`

## Uninstall summary

| Platform | Command |
|---|---|
| Linux / macOS | `curl -fsSL .../install.sh \| sh -s -- --uninstall` |
| Windows | `& ([scriptblock]::Create((irm .../install.ps1))) -Uninstall` |
| iOS / macOS profile | Settings → Profiles → Remove |
| Android | Settings → Private DNS → Off |

## License

MIT — see [LICENSE](LICENSE).
