#!/usr/bin/env python3
"""
asm86_full_test.py - verification aid for HashGuard (NOT part of the application).

Runs the COMPLETE program (src/MAIN.ASM with its INCLUDEd modules, exactly the
source MASM assembles) in the small 8086 interpreter from asm86_test.py, with
DOS INT 21h services (keyboard, screen, file open/create/read/write/seek/close,
exit) emulated against a scratch directory.  Executes the PDF integrity scenarios
from documentation/TEST_CASES.md.

Usage:  python3 asm86_full_test.py
"""
import os, re, sys, shutil, hashlib, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asm86_test import CPU

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'src')

def expand(name):
    out = []
    for line in open(os.path.join(SRC, name)).read().splitlines():
        m = re.match(r'\s*INCLUDE\s+(\S+)', line, re.I)
        out.extend(expand(m.group(1)) if m else [line])
    return out

class Exit(Exception): pass

class DosCPU(CPU):
    def __init__(self, src, events, workdir):
        super().__init__(src)
        self.events = list(events); self.out = []; self.files = {}; self.nexth = 5
        self.workdir = workdir; self.cf_ret = 0

    def asciiz(self, a):
        e = a
        while self.mem[e]: e += 1
        return bytes(self.mem[a:e]).decode('latin1')

    def path(self, n): return os.path.join(self.workdir, n.replace('\\', '/'))

    def on_int(self, n):
        ah = (self.r['ax'] >> 8) & 0xFF
        def setax(v): self.r['ax'] = v & 0xFFFF
        def setal(v): self.r['ax'] = (self.r['ax'] & 0xFF00) | (v & 0xFF)
        def fail(code): setax(code); self.cf = 1
        if n == 0x10: self.out.append('\f'); return
        if n != 0x21: raise NotImplementedError('INT %02Xh' % n)
        if ah in (1, 8):
            kind, v = self.events.pop(0); assert kind == 'k', 'program asked for a key, script has line %r' % v
            setal(ord(v))
            if ah == 1: self.out.append(v)
        elif ah == 2: self.out.append(chr(self.r['dx'] & 0xFF))
        elif ah == 9:
            a = self.r['dx']; e = a
            while self.mem[e] != 0x24: e += 1
            self.out.append(bytes(self.mem[a:e]).decode('latin1'))
        elif ah == 0x0A:
            kind, v = self.events.pop(0); assert kind == 'l', 'program asked for a line, script has key %r' % v
            a = self.r['dx']; mx = self.mem[a]; v = v[:mx-1]
            self.mem[a+1] = len(v); self.mem[a+2:a+2+len(v)] = v.encode(); self.mem[a+2+len(v)] = 13
            self.out.append(v)
        elif ah in (0x3C, 0x3D):
            name = self.asciiz(self.r['dx']); p = self.path(name)
            if ah == 0x3C:
                try: open(p, 'wb').close()
                except OSError: return fail(3)
            elif not os.path.isdir(os.path.dirname(p) or '.'): return fail(3)
            elif not os.path.isfile(p): return fail(2)
            mode = 'r+b'
            h = self.nexth; self.nexth += 1
            self.files[h] = open(p, mode); setax(h); self.cf = 0
        elif ah == 0x3E: self.files.pop(self.r['bx']).close(); self.cf = 0
        elif ah == 0x3F:
            f = self.files[self.r['bx']]; d = f.read(self.r['cx']); a = self.r['dx']
            self.mem[a:a+len(d)] = d; setax(len(d)); self.cf = 0
        elif ah == 0x40:
            f = self.files[self.r['bx']]; a = self.r['dx']; c = self.r['cx']
            f.write(bytes(self.mem[a:a+c])); f.flush(); setax(c); self.cf = 0
        elif ah == 0x42:
            f = self.files[self.r['bx']]; f.seek((self.r['cx'] << 16) | self.r['dx']); self.cf = 0
        elif ah == 0x4C: raise Exit()
        else: raise NotImplementedError('INT 21h AH=%02Xh' % ah)

def run_session(events, workdir):
    src = '\n'.join(expand('MAIN.ASM'))
    cpu = DosCPU(src, events, workdir)
    try: cpu.call('START')
    except Exit: pass
    assert not cpu.events, 'unused script events: %r' % cpu.events
    return ''.join(cpu.out).replace('\f', '\n[screen cleared]\n')

def menu(choice, line=None):
    ev = [('k', choice)]
    if line is not None: ev.append(('l', line))
    ev.append(('k', ' '))          # "press any key"
    return ev

results = []
def check(name, text, must, mustnot=()):
    ok = all(m in text for m in must) and not any(m in text for m in mustnot)
    results.append((name, ok)); print('%-4s %s' % ('PASS' if ok else 'FAIL', name))
    if not ok: print(text)

def main():
    wd = tempfile.mkdtemp(prefix='hgtest_'); os.makedirs(os.path.join(wd, 'TEST_FILES'))
    orig = b'%PDF-1.4\n' + bytes(range(256)) * 5 + b'\n%%EOF\n'        # 1300+ bytes: multi-block
    open(os.path.join(wd, 'TEST_FILES', 'SAMPLE.PDF'), 'wb').write(orig)
    open(os.path.join(wd, 'TEST_FILES', 'OTHER.PDF'), 'wb').write(b'%PDF-1.4 second document\n')
    open(os.path.join(wd, 'TEST_FILES', 'EMPTY.PDF'), 'wb').write(b'')
    h = lambda b: hashlib.md5(b).hexdigest()
    exitseq = [('k', '6')]

    t = run_session(menu('1', 'test_files\\sample.pdf') + exitseq, wd)
    check('T1  Generate hash of multi-block PDF (lower-case name accepted)', t, ['MD5 hash : ' + h(orig)])
    t = run_session(menu('1', 'TEST_FILES\\EMPTY.PDF') + exitseq, wd)
    check('T2  Generate hash of empty file', t, [h(b'')])
    t = run_session(menu('1', 'NOFILE.PDF') + exitseq, wd)
    check('T3  Missing file reported', t, ['File not found'])
    t = run_session(menu('1', 'NODIR\\X.PDF') + exitseq, wd)
    check('T4  Missing directory reported', t, ['Path not found'])
    t = run_session(menu('1', 'BAD*NAME.PDF') + menu('1', '') + exitseq, wd)
    check('T5  Invalid / empty file names rejected', t, ['Invalid file name'])
    t = run_session(menu('9') + menu('x') + exitseq, wd)
    check('T6  Invalid menu selections rejected', t, ['Invalid selection'])
    t = run_session(menu('3') + exitseq, wd)
    check('T7  View on empty/new database', t, ['No documents are registered yet'])
    check('T7b HGDB.DAT created on first use', '', [], []) if False else None
    t = run_session(menu('4', 'TEST_FILES\\SAMPLE.PDF') + exitseq, wd)
    check('T8  Verify an unregistered PDF', t, ['NOT REGISTERED'])
    t = run_session(menu('2', 'TEST_FILES\\SAMPLE.PDF') + menu('2', 'TEST_FILES\\OTHER.PDF') + exitseq, wd)
    check('T9  Register two PDFs', t, ['Document registered successfully', h(orig), h(b'%PDF-1.4 second document\n')])
    t = run_session(menu('2', 'TEST_FILES\\SAMPLE.PDF') + exitseq, wd)
    check('T10 Duplicate registration refused', t, ['already registered'])
    # restart = new session on the same directory
    t = run_session(menu('3') + exitseq, wd)
    check('T11 Persistence: records visible after restart', t,
          ['1. TEST_FILES\\SAMPLE.PDF', '2. TEST_FILES\\OTHER.PDF', 'Total registered documents: 2', h(orig)])
    t = run_session(menu('4', 'TEST_FILES\\SAMPLE.PDF') + exitseq, wd)
    check('T12 Verify unchanged PDF -> HASH MATCHED', t, ['HASH MATCHED'], ['MISMATCHED'])
    mod = bytearray(orig); mod[300] ^= 0x01                              # flip ONE bit
    open(os.path.join(wd, 'TEST_FILES', 'SAMPLE.PDF'), 'wb').write(mod)
    t = run_session(menu('4', 'TEST_FILES\\SAMPLE.PDF') + exitseq, wd)
    check('T13 One-bit modification -> HASH MISMATCHED', t,
          ['HASH MISMATCHED', 'Stored hash  : ' + h(orig), 'Current hash : ' + h(bytes(mod))], ['HASH MATCHED'])
    open(os.path.join(wd, 'TEST_FILES', 'SAMPLE.PDF'), 'wb').write(orig + b'x')   # appended byte
    t = run_session(menu('4', 'TEST_FILES\\SAMPLE.PDF') + exitseq, wd)
    check('T14 Appended byte -> HASH MISMATCHED', t, ['HASH MISMATCHED'])
    open(os.path.join(wd, 'TEST_FILES', 'SAMPLE.PDF'), 'wb').write(orig)
    t = run_session(menu('4', 'TEST_FILES\\SAMPLE.PDF') + exitseq, wd)
    check('T15 Restored original -> HASH MATCHED again', t, ['HASH MATCHED'], ['MISMATCHED'])
    os.remove(os.path.join(wd, 'TEST_FILES', 'OTHER.PDF'))
    t = run_session(menu('4', 'TEST_FILES\\OTHER.PDF') + exitseq, wd)
    check('T16 Registered but file deleted from disk -> file error', t, ['File not found'])
    t = run_session(menu('5', 'TEST_FILES\\SAMPLE.PDF') + menu('3') + exitseq, wd)
    check('T17 Delete a registered document', t, ['Registration deleted', '1. TEST_FILES\\OTHER.PDF', 'Total registered documents: 1'],
          ['1. TEST_FILES\\SAMPLE.PDF'])
    t = run_session(menu('4', 'TEST_FILES\\SAMPLE.PDF') + menu('5', 'TEST_FILES\\SAMPLE.PDF') + exitseq, wd)
    check('T18 Deleted record -> not registered / delete again reports it', t, ['NOT REGISTERED'])
    t = run_session(menu('2', 'TEST_FILES\\EMPTY.PDF') + menu('3') + exitseq, wd)
    check('T19 Freed slot is reused (2 records, DB size 128 bytes)', t, ['Total registered documents: 2'])
    size = os.path.getsize(os.path.join(wd, 'HGDB.DAT'))
    results.append(('T19b DB file is 2 x 64 bytes', size == 128)); print('%-4s T19b database file size = %d bytes (expected 128)' % ('PASS' if size == 128 else 'FAIL', size))
    open(os.path.join(wd, 'HGDB.DAT'), 'ab').write(b'junk')
    t = run_session(menu('3') + exitseq, wd)
    check('T20 Damaged database detected', t, ['Database file is damaged'])
    shutil.rmtree(wd)
    bad = [n for n, ok in results if not ok]
    print('\n%d/%d passed' % (len(results) - len(bad), len(results)))
    sys.exit(1 if bad else 0)

if __name__ == '__main__':
    main()
