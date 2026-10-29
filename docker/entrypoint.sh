#!/bin/sh
set -eu
if [ "${1:-}" = '--help' ] || [ "$#" -eq 0 ]; then
    echo 'Usage: gamess-job INPUT.inp [VERSION=00] [CPUS=1]'
    echo 'Input and results: /work; scratch: /scratch; installation: /opt/gamess'
    exit 0
fi
[ "$#" -le 3 ] || { echo 'Too many arguments' >&2; exit 2; }
input=$1
version=${2:-00}
cpus=${3:-1}
case "$version" in ''|*[!0-9]*) echo 'VERSION must be numeric' >&2; exit 2;; esac
case "$cpus" in ''|*[!0-9]*) echo 'CPUS must be a positive integer' >&2; exit 2;; esac
[ "$cpus" -gt 0 ] || { echo 'CPUS must be positive' >&2; exit 2; }
case "$input" in /*) ;; *) input=/work/$input;; esac
[ -f "$input" ] || { echo "Missing input: $input" >&2; exit 2; }
name=$(basename "$input" .inp)
case "$name" in ''|*[!A-Za-z0-9_-]*) echo 'Use a simple alphanumeric job name' >&2; exit 2;; esac
[ -x /opt/gamess/rungms ] || { echo 'Missing licensed installation at /opt/gamess' >&2; exit 2; }
# Unique workspaces prevent scratch and punch-file collisions across runs.
job=$(mktemp -d "/work/${name}.XXXXXX")
cp "$input" "$job/$name.inp"
mkdir -p "/scratch/$(basename "$job")"
cd "$job"
echo "Results: $job"
# rungms must be configured to use the exported scratch locations (see README).
export SCR="/scratch/$(basename "$job")" USERSCR="$job"
status=0
/opt/gamess/rungms "$name" "$version" "$cpus" > "$name.log" 2>&1 || status=$?
cat "$name.log"
[ "$status" -eq 0 ] || exit "$status"
# Some GAMESS launchers return success even when a calculation aborts.
grep -q 'EXECUTION OF GAMESS TERMINATED NORMALLY' "$name.log" || {
    echo "GAMESS did not terminate normally; inspect $job/$name.log" >&2
    exit 1
}
