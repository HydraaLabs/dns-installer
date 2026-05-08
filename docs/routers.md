# Routers

Set HydraaLabs DNS at the router level so every device on the network uses it.

## Common settings

- **Primary DNS**: `185.125.168.124` (Norway, EU)
- **Secondary DNS**: `45.8.125.44` (Russia, fallback)
- **DoT hostname**: `dns.hydrabrowser.net`

---

## OpenWrt

Edit `/etc/config/dhcp` or via LuCI: Network → DHCP and DNS → Resolve and Hosts Files.

```
config dnsmasq
    list server '185.125.168.124'
    list server '45.8.125.44'
    option noresolv '1'
```

For DoT install `dnsmasq-full` and use stubby or https-dns-proxy. Or replace dnsmasq with [unbound](https://openwrt.org/docs/guide-user/services/dns/unbound).

## OPNsense

Services → Unbound DNS → General → Forwarding mode.

Add forwarder:
- Server IP: `185.125.168.124`, Forward TLS Upstream, Verify CN: `dns.hydrabrowser.net`
- Server IP: `45.8.125.44`, same as above

Enable: System → Settings → General → DNS servers, add the two IPs, **uncheck "Allow DNS server list to be overridden"**.

## pfSense

Services → DNS Resolver → Display Custom Options:

```
forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 185.125.168.124@853#dns.hydrabrowser.net
    forward-addr: 45.8.125.44@853#dns.hydrabrowser.net
```

Also tick **Use SSL/TLS for outgoing DNS Queries to Forwarding Servers**.

## Mikrotik RouterOS

Plain DNS only (RouterOS up to 7.x has no native DoT for forwarding):

```
/ip dns set servers=185.125.168.124,45.8.125.44 allow-remote-requests=yes
```

For DoT use a downstream pi-hole / unbound box.

## ASUS Merlin / DD-WRT

Administration → DNSMasq → custom DNS:

```
no-resolv
server=185.125.168.124
server=45.8.125.44
```

## Generic ISP router (UI)

Most consumer routers expose "Manual DNS" in the LAN/DHCP page. Set:
1. Primary DNS server: `185.125.168.124`
2. Secondary DNS server: `45.8.125.44`
3. Save & reboot router (or renew leases)

DoT/DoH won't work on dumb routers — combine with per-device installer for encryption.
