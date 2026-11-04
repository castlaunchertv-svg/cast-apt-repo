# Cast System APT Repository

Signierter Debian-Paket-Feed für Cast-System-Hotels (castadmin, cast-web, cast-castlauncher, cast-meta).

## Kanäle

| Kanal     | Zweck                                      | Wer nutzt es           |
|-----------|--------------------------------------------|------------------------|
| `testing` | Entwicklung auf 192.168.5.3 (Annapertl)    | Dev-Box, Validierung   |
| `stable`  | Freigegebene Releases                      | Alle anderen Hotels    |

## Einbinden auf einem neuen Hotel-Server

```bash
# 1) Public-Signing-Key installieren
curl -fsSL https://castlaunchertv-svg.github.io/cast-apt-repo/cast-apt-repo.gpg.pub \
  | sudo gpg --dearmor -o /etc/apt/keyrings/cast-apt-repo.gpg

# 2) Repo registrieren (stable-Kanal)
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/cast-apt-repo.gpg] \
https://castlaunchertv-svg.github.io/cast-apt-repo stable main" \
  | sudo tee /etc/apt/sources.list.d/cast-system.list

# 3) Installieren
sudo apt-get update
sudo apt-get install cast-meta
```

Für die Dev-Box (192.168.5.3): `stable` durch `testing` ersetzen.

## Signing-Key

- Key-ID: `0FC0FFA28DB07FEE`
- Fingerprint: `C7A3 35E0 0D2E B570 EA79 D784 0FC0 FFA2 8DB0 7FEE`
- Gültig bis: 2031-11-03
- Public-Key: [`cast-apt-repo.gpg.pub`](./cast-apt-repo.gpg.pub)

## Pakete einspielen

1. .deb-Datei in `incoming/` legen
2. Commit + Push nach `main`
3. GitHub Actions läuft:
   - importiert Signing-Key aus Secret `APT_GPG_PRIVATE_KEY`
   - `reprepro includedeb testing <deb>` (bzw. `stable` via `workflow_dispatch`)
   - verschiebt .deb von `incoming/` nach `archive/`
   - committed `dists/`, `pool/`, `archive/` zurück
   - deployed auf GitHub Pages

## Lokaler Test

```bash
cd /srv/cast-system/cast-apt-repo
reprepro --ignore=wrongdistribution includedeb testing \
  ../cast-installer/output/castadmin_1.1.0-1_amd64.deb
```
