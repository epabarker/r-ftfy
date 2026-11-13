import json, sys, collections
import ftfy, ftfy.bad_codecs
print("ftfy", ftfy.__version__, "python", sys.version.split()[0])
d = json.load(open(sys.argv[1]))
names = collections.Counter()
for c in d:
    for k in ("fix_and_explain_plan", "fix_encoding_plan"):
        for a, p in (c.get(k) or []):
            if a in ("encode", "decode"):
                names[(a, p)] += 1
print("codec names in captured plans:")
for k, v in sorted(names.items()): print("  ", k, v)

def dec(b):
    try: return repr(b.decode("utf-8-variants"))
    except Exception as e: return "RAISES " + type(e).__name__
for b in [b"abc\xc0\n", b"\xed\xa0\xbd\xed\xb8\x0a", b"x\xed\xa0\xbd\xed\xb8\n", b"\xed\xa0\xbd\xed\xb8\x8a", b"\xed\xa0\xbd\xed\xb8\x0ax", b"\xed\xa0\xbd\xed\xb8", b"\xed\xa0\xbd\n", b"\xc0\x80"]:
    print(b, "->", dec(b))

# parity exposure: do any cases route through utf-8-variants with C0 80, C0 0A-final, or a pair ending in newline?
import ftfy.bad_codecs.utf8_variants as u
orig = u.IncrementalDecoder.decode
hits = []
def spy(self, input, final=False):
    b = bytes(input)
    flags = []
    if b"\xc0\x80" in b: flags.append("C0 80")
    if b.endswith(b"\xc0\n"): flags.append("C0 0A final")
    if b.endswith(b"\n") and len(b) >= 6 and b[-6] == 0xED and b[-3] == 0xED: flags.append("pair+newline final")
    rec = [cur[0], flags, b"\xed" in b, b"\xc0" in b, False]
    hits.append(rec)  # recorded before decoding, so calls that raise are counted too
    out = orig(self, input, final)
    rec[4] = True
    if "\x00" in out: flags.append("NUL out")
    return out
u.IncrementalDecoder.decode = spy
cur = [None]
for c in d:
    cur[0] = (c["index"], c["expect"])
    for f in (ftfy.fix_text, ftfy.fix_encoding, lambda t: ftfy.fix_and_explain(t)):
        try: f(c["original"])
        except Exception as e: print("err", c["index"], e)
print("variant-decoder calls:", len(hits), "succeeded:", sum(h[4] for h in hits), "cases calling it:", len({h[0] for h in hits}), "cases with a successful call:", len({h[0] for h in hits if h[4]}))
print("calls with quirk flags:", [(h[0], h[1]) for h in hits if h[1]])
succ = collections.Counter()
print("cases whose bytes had C0:", sorted({h[0] for h in hits if h[3]})[:40])
