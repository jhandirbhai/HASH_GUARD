# HashGuard — PDF File Integrity Verification System Using MD5 in 8086 Assembly Language
*University project report*

## 1. Introduction
Documents such as PDF contracts or certificates can be altered after they were issued. A cryptographic hash is a short
fingerprint of a file: if the file changes, the fingerprint changes. HashGuard is a DOS application, written completely
in 8086 assembly language, that fingerprints PDF files with the MD5 algorithm, remembers the original fingerprints in a
binary database, and checks later whether a file still matches.

## 2. Problem statement
A user needs a simple, offline way to prove that a PDF is unchanged since it was registered, without depending on the
operating system's hash utilities, and the work must be done on the 8086 processor, which has only 16-bit registers and
no multiply-by-shift-immediate or 32-bit instructions.

## 3. Objectives
1. Implement the full MD5 algorithm (4 rounds, 64 steps, padding, bit-length, little-endian) in 8086 assembly.
2. Hash files of any size through DOS INT 21h file services, including files larger than one 64-byte block.
3. Store file name and digest of many documents in a persistent binary file.
4. Provide registration, listing, verification and deletion through a menu.
5. Handle errors (missing file, invalid name, database problems, wrong menu key) without crashing.

## 4. Proposed solution
A menu-driven program with five modules combined into one executable. The hash engine is a streaming design
(`Init/Update/Final`) so a file is read in 512-byte chunks and never needs to fit in memory. Records are fixed-size
(64 bytes), which makes seeking by record number trivial using DOS function 42h.

## 5. System architecture
```
                +-----------+
   keyboard --> |  MAIN.ASM | --> screen
                | menu loop |
                +-----+-----+
          +-----------+-----------+-------------+
          v           v           v             v
     FILEIO.ASM    MD5.ASM   DATABASE.ASM     UI.ASM
   name input,    Init/Update   HGDB.DAT       printing,
   read file in   /Final/       Find/Add/      hex, decimal,
   chunks         Transform     Delete/List    error text
          \___________|___________|_____________/
                       DOS INT 21h
```
`MAIN.ASM` includes the other four files so MASM produces one object module. Shared variables (`errCode`, `nameBuf`,
`fileBuf` …) live in `MAIN.ASM`; each module declares its own private data.

## 6. MD5 algorithm
See `ALGORITHM_EXPLANATION.md` for the full description. In short: pad the message to a multiple of 64 bytes, start from the
state `67452301h, EFCDAB89h, 98BADCFEh, 10325476h`, and for each block run 64 steps of
`t = f + A + K[i] + M[g]; A=D; D=C; C=B; B = B + rotl(t, s[i])` with a different `f` and message order in each of the four
rounds, then add the result to the saved state.

## 7. 8086 assembly implementation
* **32-bit values in 16-bit registers:** a word is `DX:AX`; addition is `add`/`adc`; rotation is repeated
  `shl ax,1 / rcl dx,1 / adc ax,0` driven by a count in `CL` (8086 cannot shift by an immediate larger than 1).
* **Table-driven loop:** `MD5_Transform` loops `i = 0…63`, selects the round by comparing `i` with 16/32/48, computes `f` and the
  index `g`, reads `K[i]` from table `md5K` and the rotation count from `md5S`, and rotates the variables A–D in memory.
* **Streaming:** `MD5_Update` copies bytes into the 64-byte buffer and calls `MD5_Transform` each time it fills.
  `MD5_Final` pads, writes the 64-bit bit-length (`len*8` computed through `DX:AX:BX`), and copies the state to `md5Digest`.
* **Style rules:** only 8086 instructions (no `pusha`, `shl reg,imm>1`, 32-bit registers); conditional jumps are short, long
  distances use `jcc` over `jmp`; every procedure saves the registers it changes.

## 8. File handling
| Purpose | DOS call |
|---|---|
| keyboard menu key | INT 21h AH=01h |
| file-name line | AH=0Ah (buffered input) → validated, upper-cased, stored zero-padded in `nameBuf` |
| open PDF read-only | AH=3Dh, AL=00 |
| read 512-byte chunks | AH=3Fh until 0 bytes returned |
| create/open database | AH=3Dh AL=02, create with AH=3Ch when error 2 |
| seek to record | AH=42h, offset = index × 64 (32-bit shift in `CX:DX`) |
| write record | AH=40h, 64 bytes |
| close | AH=3Eh |
Error codes returned in `AX` with `CF=1` are saved in `errCode` and shown as *File not found* (2), *Path not found* (3),
*Access denied* (5), *Too many open files* (4) or a generic message. Code 1000 means a damaged database, 1001 a short write.

## 9. Database design
`HGDB.DAT`: fixed 64-byte records, no header.

| Offset | Size | Field |
|---|---|---|
| 0 | 1 | status (1 active, 0 deleted) |
| 1 | 47 | file name, upper case, zero padded |
| 48 | 16 | raw MD5 digest |

*Find* reads records sequentially, compares names with `repe cmpsb`, and remembers the first free slot. *Add* writes into the
free slot or appends. *Delete* sets the status to 0 (logical delete, so no file rewrite is needed). The database is only
as large as needed and survives program restarts because every operation writes through to disk before closing.

## 10. Program flowchart
```
START -> init DS/ES -> clear screen, show menu -> read key
   key 1 -> ask name -> valid? -> hash file -> show MD5
   key 2 -> ask name -> hash -> open DB -> find -> exists? --yes--> "already registered"
                                                      \--no---> add record -> "registered"
   key 3 -> open DB -> list active records -> show count
   key 4 -> ask name -> open DB -> find -> registered? --no--> "NOT REGISTERED"
                                              \--yes--> hash file -> compare 16 bytes
                                                    equal -> HASH MATCHED / else HASH MISMATCHED
   key 5 -> ask name -> open DB -> find -> found? -> set status 0 -> "deleted" / else "NOT REGISTERED"
   key 6 -> exit to DOS (AH=4Ch)
   other -> "Invalid selection"
every action -> "Press any key" -> back to menu
```

## 11. Testing and results
Summarised here; full tables in `TEST_CASES.md`. Using a software 8086 interpreter that executes the actual `.ASM` source,
12 MD5 inputs (empty, `a`, `abc`, `message digest`, alphabet, a 62-character string, 80 bytes, padding boundaries 55/56/63/64 bytes,
a 2308-byte binary) in two chunkings, and 20 application scenarios (register, verify match, one-bit and appended-byte
modification, unregistered file, delete, restart persistence, missing file/path, invalid names, invalid menu key, damaged
database) **all passed**. Assembling with real MASM and running in DOSBox have **not** been executed by the author; the manual
procedure for that is in `TEST_CASES.md` section C.

## 12. Limitations
* MD5 is cryptographically broken for collision resistance; an attacker can craft two different files with one digest.
  HashGuard is therefore suitable for detecting accidental or casual changes, not for defending against a skilled adversary.
* File names ≤ 45 characters including path; no wildcards, no directory browsing.
* The database has no checksum or password; anyone with file access can edit it. A modified HGDB.DAT can change the stored
  hash.
* Hashing is sequential 512-byte reads; very large files are slow in DOSBox.
* Verification compares against the file name typed, so renamed or moved files are "not registered".
* Real-assembler build and DOSBox run were not executed by the author (see §11).

## 13. Future improvements
Use SHA-256 (see the 32-bit rotate/add routines, which can be reused), protect the database with a keyed hash or signature,
add *update hash* for a registered file, support wildcards and batch verification, add a larger read buffer, display the
file size and timestamp, and separate modules with `PUBLIC/EXTRN` for linking.

## 14. Conclusion
HashGuard shows that a complete modern hash algorithm can be implemented on a 16-bit processor by treating each 32-bit word as
a register pair and using carry-propagating instructions. The streaming MD5 engine, the fixed-record binary database and the
menu give an end-to-end integrity tool whose behaviour on the specified test vectors and integrity scenarios was verified by
executing the real assembly source in an interpreter. Remaining work for the author is to run the real MASM/DOSBox build.
