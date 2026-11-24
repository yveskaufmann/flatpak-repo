#!/usr/bin/env bash

#
# Imports the private gpg key and caches the passphrase for later use with Flatpak signing.
#

set -euo pipefail

GPG_KEY_ID=${GPG_KEY_ID:?"GPG_KEY_ID is not set"}
GPG_PASSPHRASE=${GPG_PASSPHRASE:?"GPG_PASSPHRASE is not set"}
GPG_PRIVATE_KEY=${GPG_PRIVATE_KEY:?"GPG_PRIVATE_KEY is not set"}

# Set up a temporary GPG home directory to not deal with the workers default GPG home directory
export GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"
mkdir -p $HOME/.gnupg

# Allow passphrase presetting and loopback pinentry,
# and keep key cached for 1 hour. Allow loopback pinentry and preset passphrase.
cat <<EOF > "$GNUPGHOME/gpg-agent.conf"
allow-loopback-pinentry
allow-preset-passphrase
default-cache-ttl 3600
max-cache-ttl 3600
EOF

# Tell GPG to always use loopback mode when pinentry is needed
cat <<EOF > "$GNUPGHOME/gpg.conf"
pinentry-mode loopback
batch
yes
EOF

# Reload GPG agent to apply new configuration
gpgconf --launch gpg-agent

# Import the secret GPG key
echo "$GPG_PRIVATE_KEY" | gpg --batch --import

# Trigger a small GPG signing operation to cache the passphrase which allows flatpak later to sign with the cached passphrase
echo "$GPG_PASSPHRASE" | gpg --batch --yes --pinentry-mode loopback \
  --passphrase-fd 0 --local-user "$GPG_KEY_ID" --clear-sign --output /dev/null /dev/null

echo "GNUPGHOME=$GNUPGHOME" >> "$GITHUB_ENV"

#
# With the GPG key imported and the passphrase cached, subsequent Flatpak operations can use the cached passphrase for signing
# For example, when importing Flatpak bundles or updating the repository:
#
#   flatpak build-import-bundle --gpg-sign="$GPG_KEY_ID" repo/ "$bundle"
#

echo "✅ GPG key imported and passphrase cached successfully"
