#!/bin/bash

if [ ! -x /SRB2/bin/lsdl2srb2 ]; then
    echo "ERROR: /SRB2/bin/lsdl2srb2 not found or not executable"
    exit 1
fi

shopt -s nullglob
ADDONS=(/addons/*)
shopt -u nullglob

# Filter to recognized addon file types only
FILTERED_ADDONS=()
for f in "${ADDONS[@]}"; do
    case "$f" in
        *.wad|*.pk3|*.soc|*.lua|*.kart|*.cfg)
            FILTERED_ADDONS+=("$f") ;;
    esac
done

EXTRA=()
[ ${#FILTERED_ADDONS[@]} -gt 0 ] && EXTRA=(-file "${FILTERED_ADDONS[@]}")

# Startup logging
echo "=== SRB2 Dedicated Server ==="
echo "Binary: /SRB2/bin/lsdl2srb2"
if [ ${#FILTERED_ADDONS[@]} -gt 0 ]; then
    echo "Addons (${#FILTERED_ADDONS[@]}):"
    for a in "${FILTERED_ADDONS[@]}"; do
        echo "  - $(basename "$a")"
    done
else
    echo "Addons: none"
fi
echo "Extra args: $*"
echo "=============================="

child_pid=""
child_exit=0

forward_signal() {
    if [ -n "$child_pid" ]; then
        kill -"$1" "$child_pid" 2>/dev/null
        wait "$child_pid"
        child_exit=$?
    fi
    exit "$child_exit"
}

trap 'forward_signal TERM' SIGTERM
trap 'forward_signal INT' SIGINT

/SRB2/bin/lsdl2srb2 -dedicated -config adedserv.cfg -home /data "${EXTRA[@]}" "$@" &
child_pid=$!
wait "$child_pid"
child_exit=$?

exit "$child_exit"
