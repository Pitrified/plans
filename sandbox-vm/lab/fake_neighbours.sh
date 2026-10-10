#!/usr/bin/env bash
# Lab only: stand-ins for the things the sandbox must not reach.
#   netns lan      192.168.50.2  behind veth "lan0"     (a LAN device)
#   netns tailnet  100.64.0.2    behind veth "ts0"      (a tailnet peer)
#   the host itself, listening on every address, port 8022
# Each runs an HTTP listener so "reachable" is a real TCP connect.
set -euo pipefail
mk() { # name hostif hostaddr peeraddr
  ip netns del "$1" 2>/dev/null || true; ip link del "$2" 2>/dev/null || true
  ip netns add "$1"; ip link add "$2" type veth peer name p0 netns "$1"
  ip addr add "$3" dev "$2"; ip link set "$2" up
  ip -n "$1" addr add "$4" dev p0; ip -n "$1" link set p0 up; ip -n "$1" link set lo up
  (setsid ip netns exec "$1" python3 -m http.server 8000 --bind 0.0.0.0 >/dev/null 2>&1 &)
}
mk lan     lan0 192.168.50.1/24 192.168.50.2/24
mk tailnet ts0  100.64.0.1/10   100.64.0.2/10
pkill -f 'http.server 8022' 2>/dev/null || true
(setsid python3 -m http.server 8022 --bind 0.0.0.0 >/dev/null 2>&1 &)
sleep 1; ip -br a | grep -E 'lan0|ts0'
