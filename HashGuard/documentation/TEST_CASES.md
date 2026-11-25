# Test Cases and Results

## Honest status
| Environment | Status |
|---|---|
| Software 8086 interpreter executing the real `src/*.ASM` text (`verify/`) | **Executed, all passed** (logs in `verify/RESULTS_*.txt`) |
| Real MASM/ML assembling and LINK linking | **NOT executed** (tools unavailable to the author) |
| Real DOSBox run | **NOT executed** — repeat the steps below on your machine |

The interpreter supports only the instruction subset used here, rejects non-8086 forms (e.g. `shl ax,4`), and emulates
the DOS INT 21h services (keyboard, screen, create/open/read/write/seek/close, exit) against a scratch folder. It is a
check of the program logic, not a substitute for the real assembler. Re-run it with
`python3 verify/asm86_test.py` and `python3 verify/asm86_full_test.py`.

## A. MD5 test vectors (executed in interpreter)
| # | Input | Expected MD5 | Result |
|---|---|---|---|
| 1 | empty | d41d8cd98f00b204e9800998ecf8427e | PASS |
| 2 | `a` | 0cc175b9c0f1b6a831c399e269772661 | PASS |
| 3 | `abc` | 900150983cd24fb0d6963f7d28e17f72 | PASS |
| 4 | `message digest` | f96b697d7cb7938d525a2f31aaf161d0 | PASS |
| 5 | `abcdefghijklmnopqrstuvwxyz` | c3fcd3d76192e4007dfb496cca67e13b | PASS |
| 6 | `A-Za-z0-9` (62 bytes) | d174ab98d277d9f5a5611c2c9f419d9f | PASS |
| 7 | `1234567890` ×8 (80 bytes, > 1 block) | 57edf4a22be3c955ac49da2e2107b67a | PASS |
| 8–11 | 55 / 56 / 63 / 64 zero bytes (padding edges) | hashlib reference | PASS |
| 12 | 2308 binary bytes (multi-block) | hashlib reference | PASS |

Each input was run twice: fed in 512-byte pieces and in 7-byte pieces.

## B. Application scenarios (executed in interpreter)
| ID | Scenario | Result |
|---|---|---|
| T1 | Generate hash of a multi-block PDF, lower-case file name accepted | PASS |
| T2 | Generate hash of an empty file | PASS |
| T3 | Missing file → `File not found` | PASS |
| T4 | Missing directory → `Path not found` | PASS |
| T5 | Invalid (`*`) and empty file names rejected | PASS |
| T6 | Invalid menu keys rejected | PASS |
| T7 | View on a new database → `No documents are registered yet` | PASS |
| T8 | Verify an unregistered PDF → `NOT REGISTERED` | PASS |
| T9 | Register two PDFs; stored hashes equal the reference | PASS |
| T10 | Registering the same file twice is refused | PASS |
| T11 | **Restart**, then View shows both records (persistence) | PASS |
| T12 | Verify unchanged PDF → `HASH MATCHED` | PASS |
| T13 | Flip one bit → `HASH MISMATCHED`, both hashes shown | PASS |
| T14 | Append one byte → `HASH MISMATCHED` | PASS |
| T15 | Restore original → `HASH MATCHED` | PASS |
| T16 | Registered file removed from disk → `File not found` | PASS |
| T17 | Delete a record; View shows only the remaining one | PASS |
| T18 | Verify/Delete a deleted record → `NOT REGISTERED` | PASS |
| T19 | Free slot re-used; database file is 128 bytes for 2 records | PASS |
| T20 | Database with extra bytes → `Database file is damaged` | PASS |

## C. Manual test procedure for real DOSBox (to be executed by the user)
Expected MD5 values are in `test_files\README.txt`. Start with `RUN.BAT` (current folder `database`).
1. Option 1, `..\TEST_FILES\SAMPLE.PDF` → hash `d50cf08dbf2b633c8889f095e9236831`.
2. Option 2, same file → success. Option 3 → one record.
3. Option 4, same file → **HASH MATCHED**.
4. Exit (6), copy `SAMPLE_MODIFIED.PDF` over `SAMPLE.PDF`, restart `RUN.BAT` (database persistence), Option 4 → **HASH MISMATCHED**;
   current hash `0d0afdf129ef57fb669411ad4050beb7`.
5. Option 4 on `..\TEST_FILES\OTHER.PDF` → **NOT REGISTERED**.
6. Option 5 on `SAMPLE.PDF` → deleted; Option 3 → `No documents are registered yet`.
7. Option 1 with `NOFILE.PDF`, `BAD*.PDF`, and menu key `9` → error messages, no crash.
Record real outcomes here: ______________________________
