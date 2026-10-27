#!/bin/bash
# acl-add-observed.sh - CoreScope plan, Part 3 step 1.
#
# Adds "topic write meshcore/observed/<site>" to each Pi's stanza in the
# Mosquitto ACL file, so each bridge may publish its per-site copy.
#
#   sudo ./acl-add-observed.sh                 # default Pis: meshcore-tx1/co1/mt1
#   sudo ./acl-add-observed.sh --dry-run       # show the change, write nothing
#   sudo ./acl-add-observed.sh CN:site ...     # if your certificate CNs differ,
#                                              # e.g. meshcore-tx1:tx1 meshcore-co1:co1
#
# Safe to run more than once: a stanza that already has its line is left alone.
# Before replacing the file it checks that Mosquitto accepts the new ACL, keeps
# a timestamped backup, restarts mosquitto, and puts the backup back if the
# broker does not come up.
set -euo pipefail

ACL=${ACL:-/etc/mosquitto/aclfile}
SERVICE=${SERVICE:-mosquitto}
TEST_PORT=${TEST_PORT:-18899}
DRY_RUN=0

maps=()
for a in "$@"; do
    case "$a" in
        --dry-run) DRY_RUN=1 ;;
        *:*) maps+=("$a") ;;
        *) echo "usage: $0 [--dry-run] [CN:site ...]" >&2; exit 2 ;;
    esac
done
[ ${#maps[@]} -gt 0 ] || maps=(meshcore-tx1:tx1 meshcore-co1:co1 meshcore-mt1:mt1)

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
[ -f "$ACL" ] || { echo "not found: $ACL" >&2; exit 1; }

# Every Pi must already have exactly one "user <CN>" stanza.
for m in "${maps[@]}"; do
    cn=${m%%:*} site=${m#*:}
    [[ "$site" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "bad site id: $site" >&2; exit 1; }
    n=$(grep -cE "^[[:space:]]*user[[:space:]]+${cn}[[:space:]]*$" "$ACL" || true)
    [ "$n" -eq 1 ] || { echo "expected one 'user $cn' line in $ACL, found $n" >&2; exit 1; }
done

NEW=$(mktemp "$(dirname "$ACL")/.aclfile.new.XXXXXX")
TESTCONF=$(mktemp "$(dirname "$ACL")/.acltest.conf.XXXXXX")
trap 'rm -f "$NEW" "$TESTCONF"' EXIT

# Rewrite the file. A stanza runs from its "user" line to the next "user"
# line or the end of the file. The new line goes after the stanza's last
# non-blank line, so it sits with that user's other topic lines.
awk -v maps="${maps[*]}" '
BEGIN {
    n = split(maps, m, " ")
    for (i = 1; i <= n; i++) { split(m[i], p, ":"); site[p[1]] = p[2] }
}
function flush(   i, last, want, have) {
    want = ""
    if (cur in site) want = "topic write meshcore/observed/" site[cur]
    have = 0; last = 0
    for (i = 1; i <= cnt; i++) {
        if (buf[i] ~ /[^[:space:]]/) last = i
        line = buf[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); gsub(/[[:space:]]+/, " ", line)
        if (want != "" && line == want) have = 1
    }
    for (i = 1; i <= cnt; i++) {
        print buf[i]
        if (i == last && want != "" && !have) print want
    }
    cnt = 0
}
/^[[:space:]]*user[[:space:]]+/ {
    flush()
    cur = $2
}
{ buf[++cnt] = $0 }
END { flush() }
' "$ACL" > "$NEW"
added=$(( $(grep -c '' "$NEW") - $(grep -c '' "$ACL") ))

if [ "$added" -eq 0 ]; then
    echo "No change: every stanza already has its meshcore/observed line."
    exit 0
fi

echo "Lines to add: $added"
diff -u "$ACL" "$NEW" || true

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: $ACL not changed."
    exit 0
fi

# Same owner, mode and SELinux label as the original.
chown --reference="$ACL" "$NEW"
chmod --reference="$ACL" "$NEW"
chmod g+r "$TESTCONF"; chgrp mosquitto "$TESTCONF" 2>/dev/null || true
command -v restorecon >/dev/null && restorecon "$NEW" "$TESTCONF" 2>/dev/null || true

# Parse check: start a throwaway broker on a loopback port with the new ACL.
# Still running after 3 s = Mosquitto accepted the file.
printf 'listener %s 127.0.0.1\nallow_anonymous false\nacl_file %s\n' "$TEST_PORT" "$NEW" > "$TESTCONF"
set +e
out=$(timeout 3 mosquitto -c "$TESTCONF" 2>&1); rc=$?
set -e
if [ "$rc" -ne 124 ]; then
    echo "Mosquitto rejected the new ACL (exit $rc); $ACL not changed:" >&2
    echo "$out" >&2
    exit 1
fi
echo "Parse check passed."

BACKUP="$ACL.bak-$(date +%Y%m%d-%H%M%S)"
cp -a "$ACL" "$BACKUP"
mv "$NEW" "$ACL"
command -v restorecon >/dev/null && restorecon "$ACL" || true
echo "Backup: $BACKUP"

systemctl restart "$SERVICE"
sleep 2
if systemctl is-active --quiet "$SERVICE"; then
    echo "$SERVICE restarted with the new ACL. Bridges reconnect within seconds."
else
    echo "$SERVICE did not start; restoring $BACKUP" >&2
    cp -a "$BACKUP" "$ACL"
    systemctl restart "$SERVICE"
    journalctl -u "$SERVICE" -n 20 --no-pager >&2 || true
    exit 1
fi
