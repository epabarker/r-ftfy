# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Regenerate every generated file and snapshot from the reference version.

Run with the reference interpreter (ftfy 6.3.1 on Python 3.13):

    python data-raw/regenerate.py

It runs every script in data-raw/generators/ whose name does not start with
an underscore, in name order, under the interpreter that runs this file. To
add a generated file, add a script there; nothing here lists them.

A script that reads a file another script writes says so in a comment line
of its own,

    # Runs after: table_html_numeric.py

(several names are separated by commas), and is then run after the scripts
it names, so that one run always suffices. The other scripts keep their
name order.
"""

import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


RUNS_AFTER = "# Runs after:"


def runs_after(path):
    """The scripts a script says it must run after, as file names."""
    names = []
    with open(path, encoding="ascii") as handle:
        for line in handle:
            if line.startswith(RUNS_AFTER):
                names += [name.strip() for name in line[len(RUNS_AFTER):].split(",")]
    return [name for name in names if name]


def in_run_order(scripts):
    """The scripts in name order, but each after the scripts it names."""
    by_name = {os.path.basename(path): path for path in scripts}
    after = {name: runs_after(path) for name, path in by_name.items()}
    for name, needed in after.items():
        for other in needed:
            if other not in by_name:
                sys.exit("%s runs after %s, which is not a generator script" % (name, other))
    ordered = []
    waiting = sorted(by_name)
    while waiting:
        ready = [name for name in waiting if all(other in ordered for other in after[name])]
        if not ready:
            sys.exit("generator scripts that run after each other: %s" % ", ".join(waiting))
        ordered.append(ready[0])
        waiting.remove(ready[0])
    return [by_name[name] for name in ordered]


def main():
    scripts = sorted(
        path
        for path in glob.glob(os.path.join(HERE, "generators", "*.py"))
        if not os.path.basename(path).startswith("_")
    )
    if not scripts:
        sys.exit("no generator scripts found")
    scripts = in_run_order(scripts)
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
