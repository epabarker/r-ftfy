# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Regenerate every generated file and snapshot from the reference version.

Run with the reference interpreter (ftfy 6.3.1 on Python 3.13):

    python data-raw/regenerate.py

It runs every script in data-raw/generators/ whose name does not start with
an underscore, in name order, under the interpreter that runs this file. To
add a generated file, add a script there; nothing here lists them.
"""

import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    scripts = sorted(
        path
        for path in glob.glob(os.path.join(HERE, "generators", "*.py"))
        if not os.path.basename(path).startswith("_")
    )
    if not scripts:
        sys.exit("no generator scripts found")
    # A fixed hash seed, so that no output can depend on set order, and no
    # bytecode files, so that a run leaves nothing behind but its outputs.
    env = dict(os.environ, PYTHONHASHSEED="0", PYTHONDONTWRITEBYTECODE="1")
    for script in scripts:
        print("==", os.path.relpath(script, os.path.dirname(HERE)), flush=True)
        done = subprocess.run([sys.executable, script], env=env)
        if done.returncode != 0:
            sys.exit("generator failed: %s" % os.path.basename(script))


if __name__ == "__main__":
    main()
