# Browsers (DoH)

If you can't or don't want to change system DNS, configure DoH directly in the browser. The traffic is encrypted (port 443) end-to-end to `dns.hydrabrowser.net`.

DoH endpoint: `https://dns.hydrabrowser.net/dns-query`

---

## Firefox

1. Menu → **Settings** → **Privacy & Security**
2. Scroll to **DNS over HTTPS**
3. Choose **Max Protection** (or **Increased Protection**)
4. Provider → **Custom**
5. Enter: `https://dns.hydrabrowser.net/dns-query`
6. Save

Verify: visit `about:networking#dns` after a few queries.

## Chrome / Brave / Vivaldi / Opera

1. **Settings** → **Privacy and security** → **Security**
2. Scroll to **Advanced** → **Use secure DNS**
3. Choose **With** → **Custom**
4. Enter: `https://dns.hydrabrowser.net/dns-query`

Note: Chrome falls back to system DNS if your OS already has secure DNS configured.

## Microsoft Edge

1. **Settings** → **Privacy, search, and services** → **Security**
2. Toggle **Use secure DNS to specify how to lookup the network address for websites**
3. Choose **Choose a service provider**
4. Custom: `https://dns.hydrabrowser.net/dns-query`

## Safari

Safari uses system DNS only — no per-app DoH setting. Use the [iOS/macOS configuration profile](../ios/hydrabrowser-dns-doh.mobileconfig) instead.

## Verifying it works

- Cloudflare's DoH check: <https://1.1.1.1/help> — bottom of page shows what resolver you're using.
- Mozilla DoH check (Firefox): <https://www.cloudflare.com/cdn-cgi/trace> — look for `dns_provider`.
