"""Replaying a column's dominant plan on values it was not detected on.

Run: uv run --python 3.13 --with ftfy==6.3.1 python probe.py > output.txt
"""
import sys
import json
from collections import Counter, defaultdict

import ftfy
import ftfy.bad_codecs  # noqa
from ftfy import fix_encoding_and_explain, apply_plan
from ftfy.badness import badness, is_bad

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from words import LANGS, build_values  # noqa: E402

MIXUPS = ["windows-1252", "sloppy-windows-1252", "latin-1", "windows-1250",
          "windows-1251", "windows-1253", "windows-1254", "cp437", "mac_roman",
          "double-windows-1252", "double-sloppy-windows-1252"]

CONTROLS = ["東京都", "北京市", "서울특별시", "大阪", "こんにちは", "李小龍", "مرحبا", "القاهرة",
            "שלום", "ירושלים", "😀", "👍🏽 ok", "🇬🇧", "Ελλάδα", "Москва", "İstanbul",
            "naïve—café", "“quoted”", "50 €", "½ price", "° C", "©2024", "Æsir",
            "Œuvre", "Þór", "ß", "µg", "±5", "¿Qué?", "×", "÷", "§3", "¶",
            # text that is itself valid mojibake, legitimately written
            "Ã©", "Ã¨ is mojibake for è", "â€™", "Ãœber"]


def corrupt(s, mix):
    if mix.startswith("double-"):
        inner = mix[len("double-"):]
        t, l1 = corrupt(s, inner)
        t2, l2 = corrupt(t, inner)
        return t2, l1 or l2
    b = s.encode("utf-8")
    try:
        return b.decode(mix), False
    except UnicodeDecodeError:
        return b.decode(mix, errors="replace"), True


def ptxt(plan):
    return "none" if not plan else " > ".join(f"{a} {p}" for a, p in plan)


def replay(text, plan):
    try:
        return apply_plan(text, plan)
    except Exception:  # noqa
        return None


def dominant(flagged):
    """flagged: dict value -> (fixed, plan). Rules of the Dominant plan ticket."""
    cands = {}
    for v, (out, plan) in flagged.items():
        cands.setdefault(ptxt(plan), plan)
    n = len(flagged)
    order = ["latin-1", "sloppy-windows-1252", "sloppy-windows-1251", "sloppy-windows-1250",
             "sloppy-windows-1253", "sloppy-windows-1254", "sloppy-windows-1257",
             "iso-8859-2", "macroman", "cp437"]
    best = None
    for k, plan in cands.items():
        sup = sum(1 for v, (out, _) in flagged.items() if replay(v, plan) == out)
        if sup >= 3 and sup * 2 > n:
            first = next((p for a, p in plan if a == "encode"), "zz")
            rank = order.index(first) if first in order else 99
            key = (-sup, rank)
            if best is None or key < best[0]:
                best = (key, k, plan, sup)
    return best


def gates(inp, out):
    """Which candidate acceptance checks a changed replay passes."""
    bi, bo = badness(inp), badness(out)
    return {
        "G0_changed": True,
        "G1_badness_not_worse": bo <= bi,
        "G2_badness_drops": bo < bi,
        "G3_input_is_bad": is_bad(inp),
        "G4_out_stable": ftfy.fix_encoding(out) == out,
        "G5_drop_and_stable": bo < bi and ftfy.fix_encoding(out) == out,
    }


def main():
    print(f"ftfy {ftfy.__version__}; python {sys.version.split()[0]}")
    clean_pool = []
    for lang, (_, words) in LANGS.items():
        clean_pool += [(lang, v) for v in dict.fromkeys(build_values(words)) if not v.isascii()]
    clean_pool += [("control", v) for v in CONTROLS]
    print(f"clean pool: {len(clean_pool)} non-ASCII clean values")

    tot_miss = Counter()
    tot_clean = Counter()
    clean_examples = []
    nonsup_tot = Counter()
    summary = []
    for lang, (group, words) in LANGS.items():
        clean = list(dict.fromkeys(build_values(words)))
        for mix in MIXUPS:
            rows = [(s,) + corrupt(s, mix) for s in clean]
            flagged, missed = {}, []
            for s, c, lossy in rows:
                out, plan = fix_encoding_and_explain(c)
                plan = [tuple(x) for x in plan]
                if plan:
                    flagged[c] = (out, plan, s)
                elif c != s:
                    missed.append((s, c))
            d = dominant({k: (v[0], v[1]) for k, v in flagged.items()})
            rec = {"lang": lang, "mix": mix, "flagged": len(flagged), "missed": len(missed)}
            if d is None:
                rec["dominant"] = None
                summary.append(rec)
                print(f"{lang:10s} {mix:28s} flagged {len(flagged):3d} missed {len(missed):3d}  NO DOMINANT PLAN")
                continue
            _, dk, dplan, sup = d
            rec.update(dominant=dk, support=sup)

            # A. missed corrupted values
            m = Counter()
            for s, c in missed:
                r = replay(c, dplan)
                if r is None:
                    m["fail"] += 1
                    continue
                if r == c:
                    m["unchanged"] += 1
                    continue
                m["exact" if r == s else "other"] += 1
                for g, ok in gates(c, r).items():
                    if ok:
                        m[(g, r == s)] += 1
            rec["missed_outcomes"] = {str(k): v for k, v in m.items()}
            tot_miss.update(m)

            # B. flagged values that do not support the dominant plan
            nb = Counter()
            for c, (out, plan, s) in flagged.items():
                r = replay(c, dplan)
                if r == out:
                    continue
                own_ok = out == s
                if r is None:
                    nb["replay fails"] += 1
                elif r == s:
                    nb["replay exact, own fix not" if not own_ok else "both exact?"] += 1
                else:
                    nb["replay other, own exact" if own_ok else "both wrong"] += 1
                    if r == c:
                        nb["  (replay is a no-op)"] += 1
                if r is not None and r != out:
                    for g, ok in gates(out, r).items():
                        if ok:
                            nb[(g, r == s)] += 1
            rec["nonsupport"] = {str(k): v for k, v in nb.items()}
            nonsup_tot.update(nb)

            # C. clean values from every language plus controls
            cc = Counter()
            for cl, v in clean_pool:
                r = replay(v, dplan)
                if r is None:
                    cc["fail"] += 1
                elif r == v:
                    cc["unchanged"] += 1
                else:
                    cc["CHANGED"] += 1
                    gs = gates(v, r)
                    for g, ok in gs.items():
                        if ok:
                            cc[g] += 1
                    clean_examples.append((lang, mix, dk, cl, v, r, gs))
            rec["clean_outcomes"] = dict(cc)
            tot_clean.update(cc)
            summary.append(rec)
            print(f"{lang:10s} {mix:28s} flagged {len(flagged):3d} missed {len(missed):3d}  "
                  f"dom[{sup}] {dk}\n    missed: {dict((k, v) for k, v in m.items() if isinstance(k, str))}"
                  f"\n    non-supporting: {dict((k, v) for k, v in nb.items() if isinstance(k, str))}"
                  f"\n    clean pool: {dict((k, v) for k, v in cc.items() if k in ('fail', 'unchanged', 'CHANGED'))}")

    print("\n=== TOTALS: missed corrupted values, replay of dominant plan")
    for k, v in sorted(tot_miss.items(), key=str):
        print(f"  {k}: {v}")
    print("\n=== TOTALS: non-supporting flagged values")
    for k, v in sorted(nonsup_tot.items(), key=str):
        print(f"  {k}: {v}")
    print("\n=== TOTALS: clean pool replays (per column x clean value)")
    for k, v in sorted(tot_clean.items(), key=str):
        print(f"  {k}: {v}")
    print("\n=== clean values changed by a replay (distinct value, plan)")
    seen = set()
    for lang, mix, dk, cl, v, r, gs in clean_examples:
        if (v, dk) in seen:
            continue
        seen.add((v, dk))
        passed = [g for g, ok in gs.items() if ok]
        print(f"  [{cl}] {v!r} -> {r!r} under {dk}; passes {passed}")
    json.dump(summary, open(__file__.rsplit("/", 1)[0] + "/summary.json", "w"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
