#!/usr/bin/env bash
# Downloads a read-only snapshot of the Render billing database for a local SQLite client.
# Usage: RENDER_SSH=srv-…@ssh.<region>.render.com Scripts/pull-billing-db.sh [output.sqlite]
set -euo pipefail

target="${RENDER_SSH:?Set RENDER_SSH to the address from Render → Connect → SSH}"
key="${RENDER_SSH_KEY:-$HOME/.ssh/id_ed25519_render}"
out="${1:-.tmp/billing-snapshot.sqlite}"
remote=/tmp/billing-snapshot.sqlite
ssh_opts=(-i "$key" -o IdentitiesOnly=yes)

# The server keeps the database under an exclusive lock, so the snapshot is taken from a file copy.
ssh "${ssh_opts[@]}" "$target" sh -s <<EOF
set -e
src="\${DATA_DIR:?}/billing.sqlite"
rm -f /tmp/billing-copy.sqlite /tmp/billing-copy.sqlite-wal $remote
cp "\$src" /tmp/billing-copy.sqlite
[ ! -f "\$src-wal" ] || cp "\$src-wal" /tmp/billing-copy.sqlite-wal
node -e '
const { DatabaseSync } = require("node:sqlite");
new DatabaseSync("/tmp/billing-copy.sqlite").exec("VACUUM INTO \x27$remote\x27");
const db = new DatabaseSync("$remote");
for (const { name } of db.prepare("SELECT name FROM sqlite_master WHERE type = ?").all("table"))
  if (name.endsWith("wallets")) db.exec("UPDATE " + name + " SET token = \x27masked-\x27 || id");
db.close();
'
rm -f /tmp/billing-copy.sqlite /tmp/billing-copy.sqlite-wal
EOF

mkdir -p "$(dirname "$out")"
scp -s "${ssh_opts[@]}" "$target:$remote" "$out"
ssh "${ssh_opts[@]}" "$target" "rm -f $remote"
echo "Snapshot saved to $out"
