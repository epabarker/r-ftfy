import json, sys, re, unicodedata, collections
cases = json.load(open(sys.argv[1]))
age = {}
for line in open(sys.argv[2], encoding="utf-8"):
    line = line.split("#")[0].strip()
    if not line: continue
    rng, v = [x.strip() for x in line.split(";")]
    a, _, b = rng.partition("..")
    for cp in range(int(a, 16), int(b or a, 16) + 1): age[cp] = v
fields = ["original", "fix_text", "fix_and_explain_text", "fix_encoding"]
seen = collections.Counter(); late = collections.defaultdict(set)
strings = []
for c in cases:
    for f in fields:
        s = c[f]; strings.append(s)
        for ch in s:
            v = age.get(ord(ch), "unassigned")
            seen[v] += 1
            if v == "unassigned" or float(v) > 10.0: late[v].add((c["index"], f"U+{ord(ch):04X}"))
print("code points by Unicode age:", dict(sorted(seen.items(), key=lambda kv: (kv[0]=="unassigned", float(kv[0]) if kv[0]!="unassigned" else 0))))
for v, s in sorted(late.items()): print("  newer than 10.0:", v, sorted(s)[:10])
json.dump([{"s": s, "nfc": unicodedata.normalize("NFC", s)} for s in strings], open(sys.argv[3], "w"), ensure_ascii=False)
print("python", sys.version.split()[0], "unidata", unicodedata.unidata_version, "strings:", len(strings), "changed by NFC:", sum(unicodedata.normalize("NFC", s) != s for s in strings))
