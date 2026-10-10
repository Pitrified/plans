#!/usr/bin/env bash
# Prove the sandbox can reach the internet and nothing else.
# usage: isolation_test.sh <instance> <must-fail host:port>...
# env:   SBX_INTERNET_URL  a URL that must answer (default https://example.com)
#        SBX_DNS_NAME      a name that must resolve (default example.com)
set -uo pipefail
inst=$1; shift
url=${SBX_INTERNET_URL:-https://example.com}
name=${SBX_DNS_NAME:-example.com}
fail=0
say() { printf '%-4s %s\n' "$1" "$2"; [ "$1" = ok ] || fail=1; }
in_guest() { incus exec "$inst" -- bash -c "$1" >/dev/null 2>&1; }

incus exec "$inst" -- true >/dev/null 2>&1 || { echo "FAIL cannot exec in $inst: every 'blocked' below would be a false pass"; exit 2; }

if nft list table inet sbx_host_guard >/dev/null 2>&1 || sudo -n nft list table inet sbx_host_guard >/dev/null 2>&1
then say ok "host guard table loaded"; else say FAIL "host guard table loaded (nft table inet sbx_host_guard)"; fi

in_guest "getent hosts $name" && say ok "dns resolves $name" || say FAIL "dns resolves $name"
in_guest "curl -fsS -m 15 -o /dev/null $url" && say ok "internet reachable ($url)" || say FAIL "internet reachable ($url)"
for target in "$@"; do
  h=${target%:*}; p=${target##*:}
  if in_guest "timeout 4 bash -c '</dev/tcp/$h/$p'"; then say FAIL "$target is REACHABLE, must be blocked"
  else say ok "$target blocked"; fi
done
exit $fail
