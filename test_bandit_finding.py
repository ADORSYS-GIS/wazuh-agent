"""Temporary file to validate the reviewdog fix fails on real findings.

This file intentionally contains a HIGH-severity Bandit finding (B602:
subprocess with shell=True) so the SAST scan reports a real error-level
finding. It is used only to verify that the reviewdog step still fails the
job on genuine findings and will be removed after the pilot test.
"""

import subprocess


def run_command(cmd: str) -> int:
    # B602: subprocess_popen_with_shell_equals_true - intentionally flagged
    result = subprocess.Popen(cmd, shell=True)
    return result.wait()