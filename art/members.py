#!/usr/bin/env python3
"""Haxe class member parser + function reorderer.

  members.py outline <file> [--rank]     list the members of the file's main class
  members.py score [<file>...]           how out-of-order each file is vs the convention
  members.py reorder <file>              rewrite the file in convention order (functions move, fields stay put)

Safety model: a "member" is a field, a function, or a whole top-level #if..#end region, together with the
comments / metadata directly above it. Reordering only permutes members. After rewriting, the tool
re-parses the result and asserts the multiset of member texts is IDENTICAL to the original, so nothing
can be changed, dropped or duplicated; the only thing that differs is order and blank lines.
Fields keep their original relative order (instance initializers run in declaration order).
"""
import os, re, sys
from collections import Counter

LIFECYCLE = ['create', 'update', 'draw', 'stepHit', 'beatHit', 'onFocus', 'onFocusLost', 'destroy', 'close']
HEAD = re.compile(r'^\s*((?:@[\w:.]+(?:\([^)]*\))?\s*)*)((?:(?:public|private|static|override|inline|extern|final|dynamic|macro)\s+)*)(function|var|final)\s+(\w+)')


def read(p):
    with open(p, encoding='utf-8', newline='') as f:
        return f.read()


def write(p, t):
    with open(p, 'w', encoding='utf-8', newline='') as f:
        f.write(t)


def mask(t):
    """same length as t; comment bodies and string contents become spaces (newlines kept)."""
    o = list(t)
    i, n = 0, len(t)
    def blank(a, b):
        for k in range(a, min(b, n)):
            if o[k] != '\n':
                o[k] = ' '
    while i < n:
        c = t[i]
        if t.startswith('//', i):
            j = t.find('\n', i)
            j = n if j < 0 else j
            blank(i, j); i = j
        elif t.startswith('/*', i):
            j = t.find('*/', i + 2)
            j = n if j < 0 else j + 2
            blank(i, j); i = j
        elif c == '"' or c == "'":
            j = i + 1
            while j < n and t[j] != c:
                j += 2 if t[j] == '\\' else 1
            blank(i, j + 1); i = j + 1
        else:
            i += 1
    return ''.join(o)


class Member:
    pass


def parse(text, modname):
    """-> (prefix, members, suffix) with text == prefix + body + suffix, members cover the class body."""
    m = mask(text)
    cm = re.search(r'^[ \t]*(?:@[\w:.]+(?:\([^)]*\))?\s*)*(?:private\s+|final\s+|extern\s+)*class\s+' + re.escape(modname) + r'\b', m, re.M)
    if not cm:
        raise ValueError('no class %s' % modname)
    ob = m.find('{', cm.end())
    d, i = 0, ob
    while True:
        if m[i] == '{': d += 1
        elif m[i] == '}':
            d -= 1
            if d == 0: break
        i += 1
    cb = i
    body_start, body_end = ob + 1, cb
    # line table for the body
    lines = text[body_start:body_end].split('\n')
    mlines = m[body_start:body_end].split('\n')
    # --- find member spans (in line indexes) by scanning masked text
    spans = []
    b = p = k = 0
    li = 0
    cur = None
    L = len(lines)
    def pp(s):
        return s.strip().startswith('#')
    while li < L:
        s = mlines[li]
        st = s.strip()
        if cur is None and b == 0 and p == 0 and k == 0:
            if st == '':
                li += 1; continue
            if re.match(r'#if\b', st):                      # whole conditional region = one atomic member
                depth, lj = 0, li
                while lj < L:
                    sj = mlines[lj].strip()
                    if re.match(r'#if\b', sj): depth += 1
                    elif re.match(r'#end\b', sj):
                        depth -= 1
                        if depth == 0: break
                    lj += 1
                spans.append((li, lj, 'cond'))
                li = lj + 1; continue
            if st.startswith('#'):
                raise ValueError('stray preprocessor line %d: %s' % (li, st))
            cur = li
        # advance through this line
        j = 0
        ended = False
        while j < len(s):
            ch = s[j]
            if ch == '{': b += 1
            elif ch == '}':
                b -= 1
                if b == 0 and p == 0 and k == 0:
                    rest = (s[j + 1:] + ' ').strip()
                    nxt = rest
                    if nxt == '':                            # look at following lines for a ';'
                        q = li + 1
                        while q < L and mlines[q].strip() == '': q += 1
                        nxt = mlines[q].strip() if q < L else ''
                    if not nxt.startswith(';') and not nxt.startswith(',') and not nxt.startswith(')'):
                        ended = True
            elif ch == '(': p += 1
            elif ch == ')': p -= 1
            elif ch == '[': k += 1
            elif ch == ']': k -= 1
            elif ch == ';' and b == 0 and p == 0 and k == 0:
                ended = True
            if ended:
                spans.append((cur, li, None))
                cur = None
                ended = False
                # anything else on this line after the end belongs to nothing (just ';' or '}')
                break
            j += 1
        li += 1
    if cur is not None or b != 0:
        raise ValueError('unbalanced class body (cur=%s b=%d)' % (cur, b))
    # --- attach comments / metadata directly above each member
    def is_attach(raw):
        t = raw.strip()
        return t.startswith('//') or t.startswith('/*') or t.startswith('*') or t.endswith('*/') or t.startswith('@')
    members = []
    prev_end = -1
    for (a, e, kind) in spans:
        a2 = a
        while a2 - 1 > prev_end and lines[a2 - 1].strip() != '' and is_attach(lines[a2 - 1]):
            a2 -= 1
        f = None
        for q in range(prev_end + 1, a2):
            if lines[q].strip() != '':
                f = q
                break
        mem = Member()
        mem.floating = f is not None
        if f is not None:
            a2 = f
        mem.start, mem.end = a2, e
        mem.text = '\n'.join(lines[a2:e + 1])
        mem.gap = a2 - prev_end - 1                          # blank/floating lines before it
        mem.pre = '\n'.join(lines[prev_end + 1:a2])          # whatever sat between (blank lines or floating comments)
        # classify
        head_src = '\n'.join(mlines[a:e + 1])
        if kind == 'cond':
            inner = re.search(r'\b(function|var)\s+(\w+)', head_src)
            mem.kind = 'cond:' + (inner.group(1) if inner else 'other')
            mem.name = inner.group(2) if inner else '#if'
            mem.mods = set()
        else:
            hm = HEAD.match(head_src.split('\n', 1)[0] if False else head_src)
            if not hm:
                mem.kind, mem.name, mem.mods = 'other', head_src.strip().split('\n')[0][:30], set()
            else:
                mem.kind = 'fn' if hm.group(3) == 'function' else 'var'
                mem.name = hm.group(4)
                mem.mods = set(hm.group(2).split())
        members.append(mem)
        prev_end = e
    tail = '\n'.join(lines[prev_end + 1:])
    prefix = text[:body_start]
    suffix = text[body_end:]
    return prefix, members, tail, suffix


def rank(mem):
    if mem.kind in ('var', 'other') or mem.kind == 'cond:var' or mem.kind == 'cond:other':
        return 0
    if mem.name == 'new':
        return 1
    if mem.name in LIFECYCLE and 'static' not in mem.mods:
        return 2 + LIFECYCLE.index(mem.name)
    if 'override' in mem.mods:
        return 20
    if 'private' in mem.mods or 'public' not in mem.mods:
        return 40
    return 30


def is_fieldish(members, i):
    return rank(members[i]) == 0 or accessor_of(members, i) is not None


def label(mem):
    return {0: 'fields', 1: 'constructor', 20: 'other overrides', 30: 'public', 40: 'private'}.get(rank(mem), 'lifecycle')


def accessor_of(members, i):
    """index of the property var that members[i] (get_X / set_X) serves, else None."""
    mem = members[i]
    mm = re.match(r'^(get|set)_(\w+)$', mem.name)
    if mem.kind not in ('fn', 'cond:fn') or not mm:
        return None
    for j, o in enumerate(members):
        if o.name == mm.group(2) and o.kind in ('var', 'cond:var'):
            return j
    return None


def order(members):
    def key(i):
        j = accessor_of(members, i)
        if j is not None:
            return (0, j, 1 + (members[i].name.startswith('set_')))
        return (rank(members[i]), i, 0)
    return sorted(range(len(members)), key=key)


def inversions(members):
    r = [rank(m) for m in members]
    return sum(1 for i in range(len(r)) for j in range(i + 1, len(r)) if r[i] > r[j])


def render(prefix, members, tail, suffix, idx):
    out = []
    prev = None
    prev_f = False
    for n, i in enumerate(idx):
        mem = members[i]
        if n == 0:
            sep = '\n'                                        # right after the opening brace
        elif prev_f and is_fieldish(members, i):
            sep = '\n' + ('\n' if mem.gap > 0 else '')        # keep field spacing as it was
        else:
            sep = '\n\n'
        out.append(sep + mem.text)
        prev_f = is_fieldish(members, i)
        prev = mem
    body = ''.join(out)
    return prefix + body + ('\n' + tail if tail.strip() == '' and tail != '' else '\n' + tail if tail else '\n') + suffix


def modname_of(path):
    return os.path.basename(path)[:-3]


def reorder(path, write_back=True):
    text = read(path)
    if '\r\n' in text:
        raise ValueError('CRLF file, refusing to touch it')
    prefix, members, tail, suffix = parse(text, modname_of(path))
    idx = order(members)
    new = render(prefix, members, tail, suffix, idx)
    # ---- proof: re-parse and compare member multisets
    p2, m2, t2, s2 = parse(new, modname_of(path))
    a = Counter(m.text for m in members)
    b = Counter(m.text for m in m2)
    assert a == b, 'member texts differ after reorder!'
    assert p2 == prefix and s2 == suffix, 'prefix/suffix changed!'
    la = sorted(l.strip() for l in text.split('\n') if l.strip())
    lb = sorted(l.strip() for l in new.split('\n') if l.strip())
    assert la == lb, 'non-blank line multiset differs!'
    moved = sum(1 for n, i in enumerate(idx) if n != i)
    if write_back and new != text:
        write(path, new)
    return len(members), moved, idx, members


def outline(path, show_rank=False):
    text = read(path)
    prefix, members, tail, suffix = parse(text, modname_of(path))
    print('%s: %d members, %d inversions vs convention' % (path, len(members), inversions(members)))
    for i, mem in enumerate(members):
        ln = text[:len(prefix)].count('\n') + 1 + mem.start
        le = text[:len(prefix)].count('\n') + 1 + mem.end
        mods = ' '.join(sorted(mem.mods))
        print('  %4d-%-4d %-4s %-22s %-28s %s' % (ln, le, mem.kind.replace('cond:', '#')[:4], mem.name[:22], mods[:28], ('[' + label(mem) + ']') if show_rank else ''))


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__); return
    if a[0] == 'outline':
        outline(a[1], '--rank' in a)
    elif a[0] == 'score':
        rows = []
        for p in a[1:]:
            try:
                prefix, members, tail, suffix = parse(read(p), modname_of(p))
                rows.append((inversions(members), len(members), len(read(p).split('\n')), p))
            except Exception as e:
                rows.append((-1, 0, 0, p + '   (parse error: %s)' % e))
        for inv, n, lines, p in sorted(rows, key=lambda r: (r[2])):
            print('%4d inversions  %3d members  %5d lines  %s' % (inv, n, lines, p))
    elif a[0] == 'reorder':
        n, moved, idx, members = reorder(a[1])
        print('%s: %d members, %d changed position; proof (member multiset + line multiset identical): OK' % (a[1], n, moved))


if __name__ == '__main__':
    main()