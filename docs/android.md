# Android (Private DNS)

Android 9+ has built-in DNS-over-TLS support — called "Private DNS".

## Enable

1. Open **Settings**
2. Tap **Network & Internet** (on some skins: **Connections** → **More connection settings**)
3. Tap **Private DNS**
4. Select **Private DNS provider hostname**
5. Enter: `dns.hydrabrowser.net`
6. Tap **Save**

That's it. All DNS queries from all apps (browsers, system, third-party) will go encrypted to HydraaLabs DNS.

## Per-app: Intra (open source DoH client)

If you want DoH instead of DoT, or fine-grained control:

1. Install [Intra](https://play.google.com/store/apps/details?id=app.intra) from Google Play
2. Open Intra → **Settings** → **DoH server**
3. Custom URL: `https://dns.hydrabrowser.net/dns-query`
4. Toggle Intra on (it runs as a local VPN tunnel and forwards DNS only)

## Verify

- Browse any site — it will work normally.
- Check via <https://1.1.1.1/help> in your mobile browser.

## Disable

Settings → Private DNS → **Off** or **Automatic**.

## Notes

- Some VPN apps override Private DNS. Check the VPN's DNS leak settings.
- "Automatic" mode falls back to whatever the carrier/Wi-Fi provides.
