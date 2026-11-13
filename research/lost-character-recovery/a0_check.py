"""Of a0 rows fix_text leaves unrepaired, how many actually contain an A0 byte?"""
import ast, sys
tot = with_a0 = 0
ex = []
for line in open(sys.argv[1]):
    if not line.startswith("((") or "'a0 left'" not in line:
        continue
    key, _, s, c, o = ast.literal_eval(line)
    tot += 1
    if 0xA0 in s.encode("utf-8"):
        with_a0 += 1
        ex.append((s, c, o))
print(f"a0 rows left unrepaired by fix_text: {tot}; of these, with an A0 byte: {with_a0}")
for e in sorted(set(ex))[:15]:
    print(repr(e))
