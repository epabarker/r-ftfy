import sys, itertools
got = open(sys.argv[1], "rb").read()
def ok(b):
    try: b.decode("utf-8"); return 1
    except UnicodeDecodeError: return 0
seqs = [bytes([a]) for a in range(256)]
seqs += [bytes([a, b]) for a in range(128, 256) for b in range(256)]
seqs += [bytes([a, b, c]) for a in range(192, 256) for b in range(256) for c in range(256)]
bs = [0x00, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0, 0xFF]
seqs += [bytes([a, b, c, d]) for a in range(240, 256) for b in range(256) for c in bs for d in bs]
assert len(seqs) == len(got), (len(seqs), len(got))
diff = [(s.hex(), ok(s), g) for s, g in zip(seqs, got) if ok(s) != g]
print("sequences:", len(seqs), "disagreements:", len(diff))
import collections
print("by length:", collections.Counter(len(bytes.fromhex(h)) for h, _, _ in diff))
print("contain 00:", sum("00" in [h[i:i+2] for i in range(0, len(h), 2)] for h, _, _ in diff))
print(diff[:12])
