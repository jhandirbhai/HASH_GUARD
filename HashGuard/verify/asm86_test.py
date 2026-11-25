#!/usr/bin/env python3
"""
asm86_test.py - verification aid for HashGuard (NOT part of the application).

A tiny 8086 interpreter that loads src/MD5.ASM *as written* (the same file
MASM assembles), executes MD5_Init / MD5_Update / MD5_Final, and compares
the digest with Python's hashlib.  It supports only the instruction subset
used in MD5.ASM and strictly rejects non-8086 forms (e.g. shift by an
immediate other than 1).

Usage:  python3 asm86_test.py [path-to-MD5.ASM]
"""
import re, sys, hashlib, os

REG16 = ['ax','cx','dx','bx','sp','bp','si','di']
REG8  = ['al','cl','dl','bl','ah','ch','dh','bh']

class CPU:
    def __init__(self, src):
        self.mem = bytearray(65536)
        self.r = {n:0 for n in REG16}; self.r['ds']=0; self.r['es']=0; self.last_int=None
        self.cf = self.zf = self.sf = self.of = 0
        self.r['sp'] = 0xFFF0
        self.sym = {}      # data symbol -> (addr, elem_size)
        self.labels = {}   # code label -> instruction index
        self.code = []
        self.steps = 0
        self.load(src)

    # ---------- loader ----------
    @staticmethod
    def split_items(rest):
        out, cur, q, depth = [], '', False, 0
        for ch in rest:
            if ch == "'": q = not q
            if not q:
                if ch == '(': depth += 1
                if ch == ')': depth -= 1
                if ch == ',' and depth == 0: out.append(cur); cur = ''; continue
            cur += ch
        out.append(cur); return out

    def num(self, s):
        s = s.strip()
        if s.upper().startswith('OFFSET'):
            return self.sym[s.split()[1].lower()][0]
        if len(s) == 3 and s[0] == "'" and s[2] == "'": return ord(s[1])
        if re.fullmatch(r'[0-9][0-9A-Fa-f]*[hH]', s): return int(s[:-1], 16)
        if re.fullmatch(r'-?\d+', s): return int(s)
        raise ValueError('bad number: ' + s)

    def load(self, src):
        ptr = 0x100
        in_code = False
        for raw in src.splitlines():
            line = raw.split(';')[0].strip()
            if not line: continue
            up = line.upper()
            if up == '.DATA': in_code = False; continue
            if up == '.CODE': in_code = True; continue
            if not in_code:
                m = re.match(r'(\w+)\s+label\s+(\w+)', line, re.I)
                if m:
                    sz = {'word':2,'byte':1,'dword':4}[m.group(2).lower()]
                    self.sym[m.group(1).lower()] = (ptr, sz); continue
                m = re.match(r'(?:(\w+)\s+)?(db|dw|dd)\s+(.*)', line, re.I)
                if m:
                    name, kind, rest = m.groups()
                    sz = {'db':1,'dw':2,'dd':4}[kind.lower()]
                    start = ptr
                    for item in self.split_items(rest):
                        item = item.strip()
                        d = re.fullmatch(r'(\d+)\s+dup\s*\((.*)\)', item, re.I)
                        if d:
                            cnt, val = int(d.group(1)), self.num(d.group(2)) if d.group(2).strip() != '?' else 0
                            for _ in range(cnt):
                                self.mem[ptr:ptr+sz] = (val & ((1<<(8*sz))-1)).to_bytes(sz,'little'); ptr += sz
                        elif item.startswith("'") and len(item) != 3:
                            for ch in item[1:-1]:
                                self.mem[ptr] = ord(ch); ptr += 1
                        else:
                            val = self.num(item)
                            self.mem[ptr:ptr+sz] = (val & ((1<<(8*sz))-1)).to_bytes(sz,'little'); ptr += sz
                    if name: self.sym[name.lower()] = (start, sz)
                continue
            # code
            if re.match(r'\w+\s+(PROC|ENDP)', line, re.I):
                m = re.match(r'(\w+)\s+PROC', line, re.I)
                if m: self.labels[m.group(1).lower()] = len(self.code)
                continue
            m = re.match(r'(\w+):\s*(.*)', line)
            if m:
                self.labels[m.group(1).lower()] = len(self.code)
                line = m.group(2).strip()
                if not line: continue
            self.code.append(line)

    # ---------- operands ----------
    def parse(self, op):
        op = op.strip()
        o = op.lower()
        if o in REG16 or o in ('ds','es'): return ('r16', o)
        if o == '@data': return ('imm', 0)
        if o in REG8:  return ('r8', o)
        size = None
        m = re.match(r'(word|byte)\s+ptr\s+(.*)', o)
        if m: size = 2 if m.group(1) == 'word' else 1; o = m.group(2)
        m = re.fullmatch(r'\[(\w+)\]', o)
        if m: return ('mem', self.r_ea(m.group(1), 0, None), size)
        if o.startswith('offset') or re.match(r"^('.'|\d|-)", o):
            return ('imm', self.num(op))
        m = re.fullmatch(r'(\w+)(?:\+(\d+))?(?:\[(\w+)(?:\+(\d+))?\])?', o)
        if m and m.group(1) in self.sym:
            base, off1, idx, off2 = m.groups()
            addr, esz = self.sym[base]
            if size is None: size = esz if esz <= 2 else None
            disp = addr + int(off1 or 0) + int(off2 or 0)
            return ('mem', ('sym', disp, idx), size)
        if o in self.sym: return ('imm', self.sym[o][0])
        raise ValueError('bad operand: ' + op)

    def r_ea(self, reg, d, _):
        return ('sym', d, reg)

    def ea(self, spec):
        _, disp, idx = spec
        a = disp + (self.r[idx] if idx else 0)
        return a & 0xFFFF

    def get(self, p, width):
        k = p[0]
        if k == 'r16': return self.r[p[1]]
        if k == 'r8':
            i = REG8.index(p[1]); r = REG16[i & 3]
            return (self.r[r] >> (8 if i >= 4 else 0)) & 0xFF
        if k == 'imm': return p[1] & ((1 << (8*width)) - 1)
        a = self.ea(p[1]); sz = p[2] or width
        return int.from_bytes(self.mem[a:a+sz], 'little')

    def put(self, p, v, width):
        k = p[0]
        if k == 'r16': self.r[p[1]] = v & 0xFFFF; return
        if k == 'r8':
            i = REG8.index(p[1]); r = REG16[i & 3]
            if i >= 4: self.r[r] = (self.r[r] & 0x00FF) | ((v & 0xFF) << 8)
            else:      self.r[r] = (self.r[r] & 0xFF00) | (v & 0xFF)
            return
        a = self.ea(p[1]); sz = p[2] or width
        self.mem[a:a+sz] = (v & ((1 << (8*sz)) - 1)).to_bytes(sz, 'little')

    def width(self, a, b):
        for p in (a, b):
            if p and p[0] == 'r16': return 2
            if p and p[0] == 'r8': return 1
        for p in (a, b):
            if p and p[0] == 'mem' and p[2]: return p[2]
        raise ValueError('cannot infer operand size')

    def flags_logic(self, v, w):
        m = (1 << (8*w)) - 1; v &= m
        self.cf = self.of = 0; self.zf = int(v == 0); self.sf = (v >> (8*w-1)) & 1

    def push(self, v):
        self.r['sp'] = (self.r['sp'] - 2) & 0xFFFF
        self.mem[self.r['sp']:self.r['sp']+2] = (v & 0xFFFF).to_bytes(2, 'little')
    def pop(self):
        v = int.from_bytes(self.mem[self.r['sp']:self.r['sp']+2], 'little')
        self.r['sp'] = (self.r['sp'] + 2) & 0xFFFF; return v

    def addsub(self, a, b, w, sub, carry):
        m = (1 << (8*w)) - 1
        c = self.cf if carry else 0
        if sub:
            r = a - b - c
            self.cf = int(r < 0)
            self.of = int(((a ^ b) & (a ^ r) & (1 << (8*w-1))) != 0)
        else:
            r = a + b + c
            self.cf = int(r > m)
            self.of = int((~(a ^ b) & (a ^ r) & (1 << (8*w-1))) != 0)
        r &= m; self.zf = int(r == 0); self.sf = (r >> (8*w-1)) & 1
        return r

    # ---------- execution ----------
    def call(self, label, max_steps=80_000_000):
        self.push(0xDEAD)               # sentinel return address
        pc = self.labels[label.lower()]
        while True:
            self.steps += 1
            if self.steps > max_steps: raise RuntimeError('step limit')
            line = self.code[pc]; pc += 1
            parts = line.split(None, 1)
            mn = parts[0].lower(); args = parts[1] if len(parts) > 1 else ''
            ops = [x for x in re.split(r',(?![^\[]*\])', args)] if args else []
            if mn in ('rep','repe','repz'):
                sub = args.lower()
                while self.r['cx']:
                    self.string(sub); self.r['cx'] = (self.r['cx'] - 1) & 0xFFFF
                    if mn != 'rep' and not self.zf: break
                continue
            if mn in ('lodsb','stosb','cmpsb'): self.string(mn); continue
            if mn == 'pushf': self.push(self.cf | (self.zf << 6) | (self.sf << 7) | (self.of << 11)); continue
            if mn == 'popf':
                f = self.pop(); self.cf = f & 1; self.zf = (f >> 6) & 1; self.sf = (f >> 7) & 1; self.of = (f >> 11) & 1; continue
            if mn == 'int': self.on_int(self.num(args)); continue
            if mn == 'div':
                a = self.parse(ops[0]); w = self.width(a, None)
                if w != 2: raise ValueError('only 16-bit div supported')
                n = (self.r['dx'] << 16) | self.r['ax']; d = self.get(a, 2)
                if d == 0 or n // d > 0xFFFF: raise ZeroDivisionError('divide error')
                self.r['ax'], self.r['dx'] = n // d, n % d; continue
            if mn in ('movsb','movsw'): self.string(mn); continue
            if mn == 'cld': continue
            if mn == 'clc': self.cf = 0; continue
            if mn == 'stc': self.cf = 1; continue
            if mn == 'ret':
                v = self.pop()
                if v == 0xDEAD: return
                pc = v; continue
            if mn == 'call': self.push(pc); pc = self.labels[ops[0].strip().lower()]; continue
            if mn in ('jmp','je','jz','jne','jnz','jb','jc','jnb','jae','jnc','jbe','ja','jcxz','loop'):
                t = ops[0].strip().lower()
                if mn == 'jcxz': take = self.r['cx'] == 0
                elif mn == 'loop':
                    self.r['cx'] = (self.r['cx'] - 1) & 0xFFFF; take = self.r['cx'] != 0
                else:
                    take = {'jmp':True,'je':self.zf,'jz':self.zf,'jne':not self.zf,'jnz':not self.zf,
                            'jb':self.cf,'jc':self.cf,'jnb':not self.cf,'jae':not self.cf,'jnc':not self.cf,
                            'jbe':self.cf or self.zf,'ja':not (self.cf or self.zf)}[mn]
                if take: pc = self.labels[t]
                continue
            if mn == 'push': self.push(self.get(self.parse(ops[0]), 2)); continue
            if mn == 'pop': self.put(self.parse(ops[0]), self.pop(), 2); continue
            a = self.parse(ops[0]); b = self.parse(ops[1]) if len(ops) > 1 else None
            if mn in ('shl','shr','rcl','rcr','sal'):
                w = self.width(a, None); cnt = b
                if cnt[0] == 'imm':
                    if cnt[1] != 1: raise ValueError('8086 allows only shift count 1 or CL: ' + line)
                    n = 1
                elif cnt[0] == 'r8' and cnt[1] == 'cl': n = self.r['cx'] & 0xFF
                else: raise ValueError('bad shift count: ' + line)
                v = self.get(a, w); bits = 8*w; m = (1 << bits) - 1
                for _ in range(n):
                    if mn in ('shl','sal'):
                        self.cf = (v >> (bits-1)) & 1; v = (v << 1) & m
                    elif mn == 'shr':
                        self.cf = v & 1; v >>= 1
                    elif mn == 'rcl':
                        c = self.cf; self.cf = (v >> (bits-1)) & 1; v = ((v << 1) | c) & m
                self.zf = int(v == 0); self.sf = (v >> (bits-1)) & 1
                self.put(a, v, w); continue
            if mn in ('inc','dec'):
                w = self.width(a, None); v = self.get(a, w); keep = self.cf
                r = self.addsub(v, 1, w, mn == 'dec', False); self.cf = keep; self.put(a, r, w); continue
            if mn == 'not':
                w = self.width(a, None); self.put(a, ~self.get(a, w), w); continue
            w = self.width(a, b)
            x = self.get(a, w); y = self.get(b, w)
            if mn == 'mov': self.put(a, y, w)
            elif mn == 'add': self.put(a, self.addsub(x, y, w, False, False), w)
            elif mn == 'adc': self.put(a, self.addsub(x, y, w, False, True), w)
            elif mn == 'sub': self.put(a, self.addsub(x, y, w, True, False), w)
            elif mn == 'cmp': self.addsub(x, y, w, True, False)
            elif mn == 'and': r = x & y; self.flags_logic(r, w); self.put(a, r, w)
            elif mn == 'or':  r = x | y; self.flags_logic(r, w); self.put(a, r, w)
            elif mn == 'xor': r = x ^ y; self.flags_logic(r, w); self.put(a, r, w)
            else: raise ValueError('unsupported instruction: ' + line)

    def string(self, kind):
        sz = 2 if kind.endswith('w') else 1
        s, d = self.r['si'], self.r['di']
        if kind.startswith('movs'):
            self.mem[d:d+sz] = self.mem[s:s+sz]
            self.r['si'] = (s + sz) & 0xFFFF; self.r['di'] = (d + sz) & 0xFFFF
        elif kind == 'lodsb':
            self.r['ax'] = (self.r['ax'] & 0xFF00) | self.mem[s]; self.r['si'] = (s + 1) & 0xFFFF
        elif kind == 'stosb':
            self.mem[d] = self.r['ax'] & 0xFF; self.r['di'] = (d + 1) & 0xFFFF
        elif kind == 'cmpsb':
            self.addsub(self.mem[s], self.mem[d], 1, True, False)
            self.r['si'] = (s + 1) & 0xFFFF; self.r['di'] = (d + 1) & 0xFFFF
        else: raise ValueError(kind)

    def on_int(self, n): raise NotImplementedError('INT %02Xh' % n)

def md5_asm(path, data):
    cpu = CPU(open(path).read())
    return cpu, cpu.run_md5(data) if hasattr(cpu,'run_md5') else None

def run_vector(src, data, chunk):
    cpu = CPU(src)
    buf = 0x8000
    cpu.call('MD5_Init')
    for i in range(0, len(data), chunk) if data else []:
        piece = data[i:i+chunk]
        cpu.mem[buf:buf+len(piece)] = piece
        cpu.r['si'] = buf; cpu.r['cx'] = len(piece)
        cpu.call('MD5_Update')
    cpu.call('MD5_Final')
    a = cpu.sym['md5digest'][0]
    return bytes(cpu.mem[a:a+16]).hex()

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'src', 'MD5.ASM')
    src = open(path).read()
    vectors = [
        (b'', 'Empty input'),
        (b'a', '"a"'),
        (b'abc', '"abc"'),
        (b'message digest', '"message digest"'),
        (b'abcdefghijklmnopqrstuvwxyz', 'alphabet a-z'),
        (b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', 'A-Za-z0-9 (62 bytes)'),
        (b'1234567890' * 8, '80 bytes of digits (> one block)'),
        (bytes(55), '55 zero bytes (padding edge)'),
        (bytes(56), '56 zero bytes (padding edge)'),
        (bytes(63), '63 zero bytes'),
        (bytes(64), '64 zero bytes (exact block)'),
        (bytes(range(256)) * 9 + b'tail', '2308 bytes binary (multi-block)'),
    ]
    ok = True
    for data, name in vectors:
        want = hashlib.md5(data).hexdigest()
        for chunk in (512, 7):
            got = run_vector(src, data, chunk)
            good = got == want
            ok &= good
            print('%-4s %-36s chunk=%-3d %s' % ('PASS' if good else 'FAIL', name, chunk, got))
    print('\nALL PASSED' if ok else '\nFAILURES')
    sys.exit(0 if ok else 1)
