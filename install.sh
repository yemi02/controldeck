#!/bin/bash
# One-command install: builds ControlDeck on GitHub's free cloud Macs, then installs it here.
set -e
cd "$(dirname "$0")"
command -v brew >/dev/null || { echo "Please install Homebrew first (https://brew.sh), then run this again."; exit 1; }
command -v gh >/dev/null || brew install gh
gh auth status >/dev/null 2>&1 || gh auth login -w -p https
USER_NAME=$(gh api user -q .login)
[ -d .git ] || git init -q -b main
git add -A && git commit -qm "ControlDeck" 2>/dev/null || true
if ! gh repo view "$USER_NAME/controldeck" >/dev/null 2>&1; then
  gh repo create controldeck --private >/dev/null
fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$USER_NAME/controldeck.git"
git push -q -f -u origin main
# Public repos get free cloud builds (private repos can get cancelled by account limits)
gh repo edit "$USER_NAME/controldeck" --visibility public --accept-visibility-change-consequences >/dev/null 2>&1 || true
echo "Building in the cloud (about 5 minutes)..."
for i in 1 2 3 4; do gh workflow run "Build ControlDeck" --repo "$USER_NAME/controldeck" --ref main && break; sleep 8; done
sleep 20
RUN=$(gh run list --repo "$USER_NAME/controldeck" --workflow "Build ControlDeck" -L1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN" --repo "$USER_NAME/controldeck" --exit-status || {
  gh run view "$RUN" --repo "$USER_NAME/controldeck" --log-failed 2>&1 | tail -40
  echo "Build did not finish. Send me the lines above."; exit 1; }
rm -rf /tmp/cdl && mkdir /tmp/cdl
gh run download "$RUN" --repo "$USER_NAME/controldeck" -n ControlDeck -D /tmp/cdl
hdiutil attach -nobrowse -quiet /tmp/cdl/ControlDeck.dmg -mountpoint /tmp/cdvol
pkill ControlDeck 2>/dev/null || true
rm -rf /Applications/ControlDeck.app
cp -R /tmp/cdvol/ControlDeck.app /Applications/
hdiutil detach -quiet /tmp/cdvol
xattr -cr /Applications/ControlDeck.app
open /Applications/ControlDeck.app
echo "Installed. Last step: right-click the clock > Edit Widgets > ControlDeck."
