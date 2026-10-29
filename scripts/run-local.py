#!/usr/bin/env python3
"""Run an existing GAMESS (US) installation without changing it."""
import argparse
import fcntl
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--install', default=os.environ.get('GAMESS_HOME'))
    parser.add_argument('--version', default='00', help='Executable label, not release number')
    parser.add_argument('--cpus', type=int, default=1)
    parser.add_argument('--output', type=Path, default=Path('runs'))
    args = parser.parse_args()
    if not args.install:
        parser.error('Set GAMESS_HOME or pass --install /path/to/gamess')
    install = Path(args.install).expanduser().resolve()
    launcher = install / 'rungms'
    if not launcher.is_file() or not os.access(launcher, os.X_OK):
        parser.error(f'Missing executable launcher: {launcher}')
    if not args.version.isdigit() or args.cpus < 1:
        parser.error('Version must be numeric and CPUs must be positive')
    source = args.input.expanduser().resolve()
    if not source.is_file():
        parser.error(f'Missing input: {source}')
    args.output.mkdir(parents=True, exist_ok=True)
    # Serialize this user's wrapper runs for one installation: stock rungms may
    # ignore SCR/USERSCR and use fixed scratch directories. Never rewrite it.
    lockroot = Path.home() / '.cache' / 'forge-gamess'
    lockroot.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256(str(install).encode()).hexdigest()
    with (lockroot / (key + '.lock')).open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('Another local wrapper job is using this installation.', file=sys.stderr)
            return 2
        job = Path(tempfile.mkdtemp(prefix='gms_', dir=args.output.resolve()))
        name = job.name
        (job / (name + '.inp')).write_bytes(source.read_bytes())
        scratch = job / 'scratch'
        scratch.mkdir()
        env = dict(os.environ, SCR=str(scratch), USERSCR=str(job))
        log = job / (name + '.log')
        print(f'Results: {job}', flush=True)
        try:
            with log.open('w') as stream:
                result = subprocess.run([str(launcher), name, args.version, str(args.cpus)],
                                        cwd=job, env=env, stdout=stream,
                                        stderr=subprocess.STDOUT, check=False)
        except OSError as exc:
            print(f'Could not start rungms: {exc}. See {log}', file=sys.stderr)
            return 2
        text = log.read_text(errors='replace')
        print(text, end='')
        if result.returncode:
            return result.returncode if result.returncode > 0 else 128 - result.returncode
        if 'EXECUTION OF GAMESS TERMINATED NORMALLY' not in text:
            print(f'Normal termination missing; inspect {log}', file=sys.stderr)
            return 1
        return 0


if __name__ == '__main__':
    sys.exit(main())
