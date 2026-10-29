# Docker template — deferred

Docker support is unfinished and optional. Use the native local workflow in
[the README](../README.md) for current testing. The instructions below are
reference material for completing the template, not a verified deployment.

# forge-gamess

Docker packaging targeting **GAMESS (US) 2023 R1** single-host batch calculations. No licensed
GAMESS source or binaries are included. This is a packaging scaffold: a real
GAMESS calculation must pass the acceptance checks below before deployment.
There is no HTTP service or listening port.

## Prepare your installation

Obtain GAMESS (US) 2023 R1 through its official distribution and comply with its license.
Do not commit source, binaries, download credentials, or publish an image unless
your license permits it. Keep deployment images in an appropriately restricted
registry.

Build GAMESS using the instructions delivered with **your release**, in a
Linux amd64 environment compatible with Ubuntu 26.04. Copy the complete
installation, including executable, DDI launcher, auxiliary data and executable
`rungms`, into `vendor/gamess/`. Source-only archives are not sufficient.
This repository deliberately does not guess answers to release-specific
interactive configuration/build prompts.

Configure that installation's `rungms` for the container:

- Installation path (`GMSPATH`): `/opt/gamess`.
- Single-host execution using the DDI/runtime built for your release.
- Scratch (`SCR`): use the incoming environment variable `$SCR`.
- Persistent scratch/punch output (`USERSCR`): use incoming `$USERSCR`.
- Do not overwrite those incoming values with workstation paths. In a csh
  launcher, the relevant assignments can use `$env(SCR)` and `$env(USERSCR)`.
- Remove dependencies on workstation hostnames, SSH, writable installation
  directories, and home directories. All execution must work as an arbitrary UID.

Inspect the actual launcher before editing: variable names and launch modes vary
by release. These are changes to your private installation, not the upstream
GAMESS source supplied by this repository. If it needs MPI, Intel runtimes, or
other libraries, extend the runtime dependency list with matching supported
packages. The supplied image has GNU Fortran, BLAS and LAPACK runtimes; it is not
compatible with every GAMESS build. Do not mix host and container MPI libraries.
Apple Silicon users need an amd64 builder/emulation or an amd64 server; native
ARM compilation is outside this initial packaging target.

## Build and run locally

Prerequisites: Docker Engine/Desktop with BuildKit and Docker Compose v2.

```sh
docker build --platform linux/amd64 --target packaged -t forge-gamess:local .
mkdir -p jobs scratch
cp examples/water.inp jobs/
export LOCAL_UID=$(id -u) LOCAL_GID=$(id -g)
docker compose run --rm gamess water.inp 00 1
```

Replace `00` with the executable version expected by your launcher; `00` is a
launcher executable label, not the GAMESS release number `2023 R1`. Set
`GAMESS_CPUS` and `GAMESS_MEMORY` to the container resource limits you need;
the final job argument is the GAMESS process count and must fit the CPU limit.
GAMESS input memory settings must also fit the memory limit, including per-process
overhead. This is single-host parallelism, not a multi-server cluster.

Every invocation creates a unique directory under `jobs/` containing a copy of
the input, the log and any output that `rungms` writes to USERSCR. Scratch is
retained under `scratch/` for diagnosis; remove it only after the job has stopped.
Input names accept letters, digits, underscores and hyphens. A job is successful
only if the launcher returns zero and the log contains GAMESS's normal-termination
message. Inspect the energy and scientific results too; termination alone does
not establish numerical accuracy.

The Compose configuration uses no network, drops capabilities and makes the root
filesystem read-only. If a particular DDI build requires additional privileges
or writable locations, diagnose and document its precise requirements before
changing this policy. Do not run privileged by default.

## Deploy to a Docker server

Use the same amd64 architecture and test the exact image on the destination.
For an offline transfer:

```sh
docker save forge-gamess:local | gzip > forge-gamess-image.tar.gz
scp forge-gamess-image.tar.gz compose.yaml examples/water.inp user@server:/srv/gamess/
```

On the server (Docker Engine and Compose v2 installed, `/srv/gamess` owned by
the deployment user):

```sh
cd /srv/gamess
gunzip -c forge-gamess-image.tar.gz | docker load
mkdir -p jobs scratch
cp water.inp jobs/
export LOCAL_UID=$(id -u) LOCAL_GID=$(id -g)
export GAMESS_CPUS=2 GAMESS_MEMORY=4g
docker compose run --rm gamess water.inp 00 1
```

Alternatively push an authorized private registry tag, pull it on the server,
and set `GAMESS_IMAGE` to its immutable `registry/repository@sha256:...` digest.
Pin the base image digest through `--build-arg BASE_IMAGE=ubuntu:26.04@sha256:...`
for controlled releases. Record GAMESS version, compiler/runtime versions,
installation checksum and image digest with each release. Rebuild and retest
when the base image or scientific software changes.

Submit one container per calculation through your chosen scheduler or shell.
Do not enable automatic restart of completed scientific jobs. Back up `jobs/`,
monitor disk usage and memory, and retain the prior image digest for rollback.
No public ports, reverse proxy, or daemon service are required.

## Acceptance checks and current limitations

1. Build the packaged target with the actual licensed installation.
2. Run the water input above with one process; verify normal termination and an
   RHF/STO-3G energy near -74.96 hartree, comparing against your release's reference.
3. Run the official verification suite supplied with your GAMESS release, checking
   numerical tolerances and actual executed test counts.
4. If using parallel jobs, repeat with the intended process count and resource
   limits on the destination server. Confirm persistent outputs and concurrent
   jobs do not collide.

Without a licensed installation only the runtime image and wrapper behavior can
be tested. Mock launcher tests do not validate GAMESS or DDI. The source build,
real calculation, official suite and destination-server run remain required.

For a managed cloud environment with a provided combined CA bundle, pass
`--secret id=proxy_ca,src=/etc/ssl/certs/ca-certificates.crt` to builds. The secret
is used only during package installation and is not copied into the image.

To validate only the packaging runtime without licensed software:

```sh
docker build --platform linux/amd64 --target runtime -t forge-gamess:runtime .
sh tests/runtime.sh
docker compose config --quiet
```

These checks cover output persistence, separate job directories, abnormal
termination detection, launcher exit-code propagation and invalid inputs.
