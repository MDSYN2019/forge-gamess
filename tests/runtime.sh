#!/bin/sh
# Contract tests using a mock launcher. These do not test GAMESS calculations.
set -eu
image=${1:-forge-gamess:runtime}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT HUP INT TERM
mkdir -p "$root/gamess" "$root/work" "$root/scratch"
chmod 777 "$root/work" "$root/scratch"
chmod 755 "$root"
cat > "$root/gamess/rungms" <<'LAUNCHER'
#!/bin/sh
set -eu
[ -f "$1.inp" ]
[ -d "$SCR" ]
[ "$USERSCR" = "$PWD" ]
printf 'punch output\n' > "$USERSCR/result.dat"
case "$2" in
  01) echo 'calculation aborted'; exit 0;;
  02) echo 'launcher failed'; exit 7;;
esac
echo 'EXECUTION OF GAMESS TERMINATED NORMALLY'
LAUNCHER
chmod 755 "$root/gamess/rungms"
printf 'test input\n' > "$root/work/water.inp"
run() {
    docker run --rm --network none --read-only --cap-drop ALL \
      --security-opt no-new-privileges --tmpfs /tmp \
      -v "$root/gamess:/opt/gamess:ro" -v "$root/work:/work" \
      -v "$root/scratch:/scratch" "$image" "$@"
}
run --help
run water.inp 00 1
run water.inp 00 1
[ "$(find "$root/work" -name result.dat | wc -l)" -eq 2 ]
expect() {
    expected=$1; shift
    status=0
    run "$@" || status=$?
    [ "$status" -eq "$expected" ] || { echo "Expected $expected, got $status" >&2; exit 1; }
}
expect 1 water.inp 01 1
expect 7 water.inp 02 1
expect 2 water.inp 00 0
expect 2 water.inp 00 invalid
expect 2 missing.inp
printf 'PASS: success, collision isolation, abnormal termination, exit propagation, invalid CPU counts, missing input\n'
