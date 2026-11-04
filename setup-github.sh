#!/bin/bash
# Einmaliges GitHub-Setup für cast-apt-repo.
#
# Vorarbeit (User):
#   gh auth login     — interaktiv (Browser oder Token)
#   gh auth status    — bestätigen dass castlaunchertv-svg zugänglich ist
#
# Was dieses Skript macht:
#   1. Repo castlaunchertv-svg/cast-apt-repo als public anlegen (falls noch nicht da)
#   2. Lokales git-remote auf dieses Repo setzen + main pushen
#   3. GPG-Private-Key aus /srv/cast-system/secrets/ als Secret APT_GPG_PRIVATE_KEY setzen
#   4. GitHub Pages aktivieren (source: main, path: /)
#
# Idempotent — kann wiederholt aufgerufen werden.

set -euo pipefail

OWNER=castlaunchertv-svg
REPO=cast-apt-repo
PRIV_KEY=/srv/cast-system/secrets/cast-apt-repo.gpg.priv

# Vorbedingungen
command -v gh >/dev/null || { echo "gh CLI fehlt — apt install gh"; exit 1; }
gh auth status 2>&1 | grep -q "Logged in" || { echo "nicht eingeloggt — gh auth login ausführen"; exit 2; }
[[ -f "$PRIV_KEY" ]] || { echo "Private Key fehlt: $PRIV_KEY"; exit 3; }

cd "$(dirname "$0")"
[[ -d .git ]] || { echo "muss im cast-apt-repo-Working-Tree laufen"; exit 4; }

echo "=== 1/4 Repo anlegen (falls nötig) ==="
if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
    echo "repo $OWNER/$REPO existiert — überspringe create"
else
    gh repo create "$OWNER/$REPO" \
        --public \
        --description "Cast System APT Repository — signierter Debian-Feed für Hotel-Server" \
        --homepage "https://$OWNER.github.io/$REPO"
fi

echo ""
echo "=== 2/4 Remote setzen + push ==="
if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "https://github.com/$OWNER/$REPO.git"
else
    git remote add origin "https://github.com/$OWNER/$REPO.git"
fi
git push -u origin main

echo ""
echo "=== 3/4 GPG Private Key als Secret setzen ==="
gh secret set APT_GPG_PRIVATE_KEY --repo "$OWNER/$REPO" < "$PRIV_KEY"
echo "Secret APT_GPG_PRIVATE_KEY gesetzt."

echo ""
echo "=== 4/4 GitHub Pages aktivieren ==="
# Erst versuchen update, dann create (Reihenfolge egal — eins wird erfolgreich sein)
PAGES_STATE=$(gh api "repos/$OWNER/$REPO/pages" 2>/dev/null | head -5 || echo "")
if [[ -n "$PAGES_STATE" ]]; then
    echo "Pages bereits aktiv:"
    gh api "repos/$OWNER/$REPO/pages" --jq '.html_url, .status'
else
    # Pages via Actions (workflow deployed), nicht via branch source
    gh api -X POST "repos/$OWNER/$REPO/pages" \
        -f 'build_type=workflow' \
        -F 'source[branch]=main' \
        -F 'source[path]=/' 2>&1 | head -5 || \
    gh api -X PATCH "repos/$OWNER/$REPO/pages" \
        -f 'build_type=workflow'
    echo "Pages aktiviert."
fi

echo ""
echo "=== fertig ==="
echo "Repo:     https://github.com/$OWNER/$REPO"
echo "Pages:    https://$OWNER.github.io/$REPO/"
echo "Actions:  https://github.com/$OWNER/$REPO/actions"
echo ""
echo "Nächster Schritt: GitHub Actions-Lauf anstoßen —"
echo "  gh workflow run 'Publish .deb to apt repo' --repo $OWNER/$REPO -f channel=testing"
