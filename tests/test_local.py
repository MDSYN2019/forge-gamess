import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

RUNNER = Path(__file__).resolve().parents[1] / 'scripts' / 'run-local.py'


class LocalRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.install = self.root / 'installation with spaces'
        self.install.mkdir()
        self.input = self.root / 'water.inp'
        self.input.write_text('sample input')
        self.env = dict(os.environ, HOME=str(self.root))

    def launch(self, body, *extra):
        launcher = self.install / 'rungms'
        launcher.write_text('#!/bin/sh\nset -eu\n' + body)
        launcher.chmod(0o755)
        return subprocess.run([sys.executable, str(RUNNER), str(self.input),
                               '--install', str(self.install), '--output', str(self.root / 'runs'),
                               *extra], env=self.env, capture_output=True, text=True)

    def test_success_and_unique_output(self):
        body = ('test "$(cat "$1.inp")" = "sample input"\n'
                'test "$2" = 00\ntest "$3" = 1\n'
                'test -d "$SCR"\ntest "$USERSCR" = "$PWD"\n'
                'echo punch > "$USERSCR/result.dat"\n'
                'echo "EXECUTION OF GAMESS TERMINATED NORMALLY"\n')
        for _ in range(2):
            result = self.launch(body)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(len(list((self.root / 'runs').glob('*/result.dat'))), 2)
        self.assertEqual(len(list((self.root / 'runs').glob('*/*.log'))), 2)

    def test_abnormal_termination(self):
        self.assertEqual(self.launch('echo aborted\n').returncode, 1)

    def test_launcher_failure(self):
        self.assertEqual(self.launch('exit 7\n').returncode, 7)

    def test_invalid_cpu(self):
        self.assertEqual(self.launch('exit 0\n', '--cpus', '0').returncode, 2)

    def test_missing_input(self):
        self.input.unlink()
        self.assertEqual(self.launch('exit 0\n').returncode, 2)


if __name__ == '__main__':
    unittest.main()
