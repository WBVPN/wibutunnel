# Wibutunnel Auto Installer

One-command automation untuk install Wibutunnel VPN ke VPS dengan GitHub token authentication.

## Quick Start

```bash
./wibu_installer.sh \
  --vps YOUR_VPS_IP \
  --user root \
  --pass 'YOUR_PASSWORD' \
  --domain your.domain.com \
  --github-token ghp_xxxxxxxxxxxxx
```

## Features

- ✅ Auto-handle dependencies (git, curl, sshpass)
- ✅ Auto-fix Debian repository conflicts
- ✅ GitHub token authentication
- ✅ Auto-wait VPS reboot
- ✅ Post-install validation report

## Options

```
Required:
  --vps IP            VPS IP address
  --pass PASS         VPS SSH password
  --domain DOMAIN     Domain untuk SSL certificate
  --github-token TOKEN GitHub fine-grained token

Optional:
  --user USER         SSH username (default: root)
  --port PORT         SSH port (default: 22)
  --skip-prereq       Skip prerequisite check
```

## GitHub Token

Create token di: https://github.com/settings/tokens?type=beta
- Repository: `WBVPN/wibutunnel-izin`
- Permission: Contents (Read-only)

## Full Documentation

See [main README](README.md) untuk Wibutunnel features dan manual installation.

## Troubleshooting

Resolved automatically:
- Missing sshpass → auto-install
- Git not on VPS → auto-install
- Debian perl conflicts → auto-downgrade
- License auth → GitHub token
- VPS reboot → auto-wait

## Multi-VPS

```bash
for vps in "110.x.x.x|vpn1.com" "103.x.x.x|vpn2.com"; do
  IFS='|' read ip domain <<< "$vps"
  ./wibu_installer.sh --vps "$ip" --pass "Pass" \
    --domain "$domain" --github-token "ghp_xxx"
done
```
