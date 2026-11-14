# Derived from python-ftfy v6.3.1, tests/test_examples_in_json.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the snapshot of the reference version's texts and plans for the
upstream JSON cases to tests/testthat/reference/json_cases.tsv.

The cases are read from the committed copy, tests/testthat/upstream/
test_cases.json, and are identified by their index in its array, from 0.
Nothing is keyed by label or text: one record occurs twice and both rows
are written.

Columns, tab separated; text columns are escaped (see _reference.escape)
and plans are in their text form ("encode latin-1 > decode utf-8", or
"none" for no steps):

  index                  position in the JSON array, from 0
  expect                 "pass" or "fail", as the JSON says
  original               the input
  fix_text               fix_text(original)
  fix_and_explain_text   fix_and_explain(original).text
  fix_and_explain_plan   fix_and_explain(original).explanation
  fix_encoding_text      fix_encoding_and_explain(original).text
  fix_encoding_plan      fix_encoding_and_explain(original).explanation
  extra_layer            original, encoded as UTF-8 and decoded as Latin-1
  extra_layer_fix_text   fix_text(extra_layer)

Nothing here is random, so a rerun gives the same file byte for byte.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import REPO, escape, plan_text, require_reference, storable, write_ascii

require_reference()

import ftfy

CASES = os.path.join(REPO, "tests", "testthat", "upstream", "test_cases.json")
COLUMNS = [
    "index",
    "expect",
    "original",
    "fix_text",
    "fix_and_explain_text",
    "fix_and_explain_plan",
    "fix_encoding_text",
    "fix_encoding_plan",
    "extra_layer",
    "extra_layer_fix_text",
]


def main():
    with open(CASES, encoding="utf-8") as handle:
        cases = json.load(handle)
    lines = ["\t".join(COLUMNS) + "\n"]
    for index, case in enumerate(cases):
        original = case["original"]
        assert case["expect"] in ("pass", "fail")
        explained = ftfy.fix_and_explain(original)
        encoding = ftfy.fix_encoding_and_explain(original)
        extra_layer = original.encode("utf-8").decode("latin-1")
        texts = [
            original,
            ftfy.fix_text(original),
            explained.text,
            encoding.text,
            extra_layer,
            ftfy.fix_text(extra_layer),
        ]
        # An R string cannot hold U+0000 or a surrogate. No case has one.
        assert all(storable(text) for text in texts), index
        row = [
            str(index),
            case["expect"],
            escape(texts[0]),
            escape(texts[1]),
            escape(texts[2]),
            plan_text(explained.explanation),
            escape(texts[3]),
            plan_text(encoding.explanation),
            escape(texts[4]),
            escape(texts[5]),
        ]
        lines.append("\t".join(row) + "\n")
    write_ascii("tests/testthat/reference/json_cases.tsv", "".join(lines))


main()
