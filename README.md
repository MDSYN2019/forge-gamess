# forge-gamess

Local testing tools for **GAMESS (US) 2023 R1**, with a Docker template to finish
later. Use your existing working Linux installation; Docker is not required.
No GAMESS source or binaries are included.

## Run locally

Prerequisites: Linux, Python 3.9 or newer, and a working GAMESS installation with
an executable `rungms`. Your existing Ubuntu x86_64 installation is the target.
Keep it outside this checkout. You do not need to copy it into `vendor/`.

From this repository directory:

```sh
export GAMESS_HOME="$HOME/software/gamess"
python3 scripts/run-local.py examples/water.inp --cpus 1
```

Or specify the installation explicitly:

```sh
python3 scripts/run-local.py examples/water.inp \
  --install "$HOME/software/gamess" --version 00 --cpus 1
```

`00` selects `gamess.00.x`; it is not the release number. The runner creates a
unique directory under `runs/`, copies the input using a unique job name, and
captures stdout/stderr in its `.log`. Follow a running log from another terminal
with `tail -f runs/<job-directory>/<job-name>.log`. The runner prints the result
path immediately and the log after completion. It returns failure when the
launcher fails or GAMESS's normal-termination message is absent.

The runner passes `SCR` and `USERSCR`, but a stock `rungms` may override them.
In that case auxiliary outputs and scratch remain at the paths configured in
your installation. The runner never edits that working launcher. It requires
`rungms` to find input in the current directory; if your customized launcher
requires a different working directory, inspect its paths before adapting it.
Only one wrapper job per installation and Linux user runs at a time. Direct
`rungms` runs or runs by other users are outside that lock; avoid concurrent
use until your launcher's scratch behavior is verified.

Start with one process. For the sample water input, inspect normal termination
and an RHF/STO-3G energy near -74.96 hartree, comparing against your release's
reference. Then use the official GAMESS verification suite. Repeat with a larger
`--cpus` value only after serial execution works. Normal termination alone does
not establish numerical accuracy. There is no persistent server to start: each
command launches one calculation on your computer.

## Test the runner

```sh
python3 -m unittest discover -s tests -p 'test_local.py' -v
```

These tests use a mock launcher to verify inputs, output capture, unique job
directories and failure handling. They do not validate GAMESS or its scientific
results. A real calculation cannot be run in the cloud workspace until a licensed
installation is available there; the installation on your computer stays local.

## Docker template (later)

`Dockerfile`, `compose.yaml` and `docker/entrypoint.sh` are retained as unfinished
templates. The default base is Ubuntu 26.04 to match your compiled installation.
Do not treat them as deployment-ready. See [Docker notes](docs/docker-template.md)
for installation copying, launcher configuration and server deployment checks.
Local tests do not build or start Docker.

Keep licensed installations, generated results, scratch files and credentials
out of Git. `runs/`, `vendor/`, `jobs/` and `scratch/` are ignored.
