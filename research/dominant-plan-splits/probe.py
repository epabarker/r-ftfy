"""How many distinct ftfy plans does one corruption source split into?

Run: uv run --python 3.13 --with ftfy==6.3.1 python probe.py > output.txt
"""
import sys
import json
import unicodedata
from collections import Counter, defaultdict

import ftfy
from ftfy import fix_and_explain, fix_encoding_and_explain, apply_plan

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from words import LANGS, build_values  # noqa: E402

FIXERS = ftfy.FIXERS

MIXUPS = ["windows-1252", "sloppy-windows-1252(ftfy codec, supplementary)", "latin-1", "windows-1250", "windows-1251", "windows-1253",
          "windows-1254", "cp437", "mac_roman", "double-windows-1252",
          "double-sloppy-windows-1252(ftfy codec, supplementary)"]


def corrupt(s, mix):
    """Return (corrupted, lossy?)"""
    lossy = False
    if mix.startswith("double-sloppy"):
        t, _ = corrupt(s, "sloppy-windows-1252")
        return corrupt(t, "sloppy-windows-1252")
    if mix == "double-windows-1252":
        t, l1 = corrupt(s, "windows-1252")
        t2, l2 = corrupt(t, "windows-1252")
        return t2, l1 or l2
    b = s.encode("utf-8")
    if mix.startswith("sloppy-windows-1252"):
        import ftfy.bad_codecs  # noqa
        return b.decode("sloppy-windows-1252"), False
    try:
        return b.decode(mix), False
    except UnicodeDecodeError:
        return b.decode(mix, errors="replace"), True


def ptxt(plan):
    if not plan:
        return "none"
    return " > ".join(f"{a} {p}" for a, p in plan)


def noop_steps(text, plan):
    """Names of transcode/apply steps that do not change their input, and
    encode/decode pairs that round-trip to the same string."""
    out = []
    obj = text
    for i, (op, arg) in enumerate(plan):
        before = obj
        if op == "encode":
            obj = obj.encode(arg)
        elif op == "decode":
            obj = obj.decode(arg)
        else:
            obj = FIXERS[arg](obj)
            if obj == before:
                out.append(f"{op} {arg}")
        if op == "decode" and i > 0 and plan[i - 1][0] == "encode" and obj == prev_str:
            out.append(f"{plan[i-1][0]} {plan[i-1][1]} > decode {arg} (round-trip)")
        if op == "encode":
            prev_str = before
    return out


def try_apply(text, plan):
    try:
        return apply_plan(text, plan), None
    except Exception as e:  # noqa
        return None, type(e).__name__


def interesting_chars(values):
    """Characters in corrupted text that are not in latin-1/windows-1252 sets."""
    c = Counter()
    for v in values:
        for ch in v:
            if ord(ch) > 0x7F:
                c[ch] += 1
    return c


def char_flags(v):
    flags = []
    for ch in set(v):
        o = ord(ch)
        if 0x80 <= o <= 0x9F:
            flags.append(f"C1 U+{o:04X}")
        elif ch == "�":
            flags.append("U+FFFD")
        elif ch == " ":
            flags.append("NBSP")
    return flags


def main():
    print(f"ftfy {ftfy.__version__}; python {sys.version.split()[0]}")
    summary = []
    for lang, (group, words) in LANGS.items():
        clean = build_values(words)
        for mix in MIXUPS:
            pairs = [corrupt(s, mix) for s in clean]
            corr = [p[0] for p in pairs]
            nlossy = sum(p[1] for p in pairs)
            nchanged = sum(c != s for c, s in zip(corr, clean))
            print(f"\n=== {lang} ({group}) / {mix}: n={len(clean)}, corrupted!=clean: {nchanged}, lossy: {nlossy}")
            col = {"lang": lang, "mix": mix, "n": len(clean), "lossy": nlossy, "changed": nchanged}
            for fname, fn in (("fix_and_explain", fix_and_explain),
                              ("fix_encoding_and_explain", fix_encoding_and_explain)):
                plans = Counter()
                by_plan = defaultdict(list)
                eq_clean = Counter()
                noops = Counter()
                replay_ok = 0
                for s, c in zip(clean, corr):
                    out, plan = fn(c)
                    plan = [tuple(x) for x in plan]
                    k = ptxt(plan)
                    plans[k] += 1
                    by_plan[k].append((s, c, out, plan))
                    eq_clean[(k, out == s)] += 1
                    for n_ in noop_steps(c, plan):
                        noops[n_] += 1
                    r, _ = try_apply(c, plan)
                    replay_ok += (r == out)
                missed = sum(1 for s, c in zip(clean, corr) if c != s and ptxt([tuple(x) for x in fn(c)[1]]) == "none")
                noenc = altered = 0
                for s_, c_ in zip(clean, corr):
                    if c_ == s_:
                        continue
                    o_, pl_ = fn(c_)
                    if not any(op == "encode" or arg == "decode_inconsistent_utf8" for op, arg in pl_):
                        noenc += 1
                        altered += (o_ != c_)
                print(f"  -- {fname}: {len(plans)} distinct plan(s); self-replay ok {replay_ok}/{len(clean)}; corrupted-but-plan-none {missed}; corrupted-but-no-encoding-step {noenc}/{nchanged} (of which output altered anyway: {altered})")
                for k, n in plans.most_common():
                    ok = eq_clean[(k, True)]
                    print(f"     {n:4d}  [out==clean {ok:3d}]  {k}")
                if noops:
                    print(f"     no-op steps: {dict(noops)}")
                # Characters behind the split: for each non-dominant plan, show
                # distinguishing chars and examples.
                nonnone = [k for k, _ in plans.most_common() if k != "none"]
                if len(nonnone) > 1:
                    dom = nonnone[0]
                    domplan = by_plan[dom][0][3]
                    for other in nonnone[1:]:
                        oplan = by_plan[other][0][3]
                        fl = Counter()
                        denc = domplan[0][1] if domplan[0][0] == "encode" else None
                        for s, c, out, plan in by_plan[other]:
                            for f in char_flags(c):
                                fl[f] += 1
                            if denc:
                                for ch in set(c):
                                    try:
                                        ch.encode(denc)
                                    except UnicodeEncodeError:
                                        fl[f"not-in-{denc}:{ch}(U+{ord(ch):04X})"] += 1
                        ex = by_plan[other][:3]
                        print(f"     split: '{other}' flags={dict(fl)}")
                        for s, c, out, plan in ex:
                            print(f"        e.g. clean={s!r} corr={c!r} out={out!r}")
                        # replay dominant on other
                        a_ok = a_same = 0; errs = Counter()
                        for s, c, out, plan in by_plan[other]:
                            r, e = try_apply(c, domplan)
                            if e: errs[e] += 1
                            else:
                                a_ok += 1; a_same += (r == out)
                        print(f"        replay DOMINANT on these {len(by_plan[other])}: ran {a_ok}, same-as-own-fix {a_same}, errors {dict(errs)}")
                        b_ok = b_same = 0; errs = Counter()
                        for s, c, out, plan in by_plan[dom]:
                            r, e = try_apply(c, oplan)
                            if e: errs[e] += 1
                            else:
                                b_ok += 1; b_same += (r == out)
                        print(f"        replay THIS on dominant's {len(by_plan[dom])}: ran {b_ok}, same-as-own-fix {b_same}, errors {dict(errs)}")
                # replay dominant plan on missed (corrupted, plan none) values
                if missed and nonnone:
                    domplan = by_plan[nonnone[0]][0][3]
                    ran = fixed = 0; errs = Counter()
                    for s, c, out, plan in by_plan["none"]:
                        if c == s:
                            continue
                        r, e = try_apply(c, domplan)
                        if e: errs[e] += 1
                        else:
                            ran += 1; fixed += (r == s)
                    print(f"     replay DOMINANT on {missed} missed: ran {ran}, ==clean {fixed}, errors {dict(errs)}")
                # misses: examples
                if missed:
                    ex = [(s, c, out) for s, c, out, plan in by_plan["none"] if c != s][:3]
                    for s, c, out in ex:
                        print(f"     missed e.g. clean={s!r} corr={c!r} out={out!r}")
                col[fname] = {"plans": dict(plans), "missed": missed, "noenc": noenc, "altered": altered, "noops": dict(noops),
                              "out_eq_clean": sum(v for (k, t), v in eq_clean.items() if t)}
            summary.append(col)
    # Aggregate per mix-up over languages (fix_encoding_and_explain encoding plans)
    for fname in ("fix_encoding_and_explain", "fix_and_explain"):
        print(f"\n##### AGGREGATE {fname}: plans per mix-up, summed over 10 languages")
        for mix in MIXUPS:
            agg = Counter(); miss = 0; ne = 0; alt = 0; chg = 0; eq = 0; ncols = 0; ndist = []
            for col in summary:
                if col["mix"] != mix: continue
                agg.update(col[fname]["plans"]); miss += col[fname]["missed"]; ne += col[fname]["noenc"]; alt += col[fname]["altered"]; chg += col["changed"]; eq += col[fname]["out_eq_clean"]
                ndist.append(len(col[fname]["plans"]))
            print(f"  {mix}: distinct plans per column {ndist}; plan-none&corrupted {miss}; no-encoding-step {ne}/{chg} corrupted (altered anyway {alt}); out==clean {eq}/2000")
            for k, n in agg.most_common():
                print(f"     {n:5d}  {k}")
    with open(__file__.rsplit("/", 1)[0] + "/summary.json", "w") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
