# HashGuard — PDF File Integrity Verification System (MD5, 8086 Assembly)

HashGuard is a DOS program written entirely in **8086 assembly language (MASM)**. It computes the **MD5** hash of
a PDF (or any file), registers the original hash in a binary database (`HGDB.DAT`), and later re-computes the
hash to report **HASH MATCHED** or **HASH MISMATCHED**.

## Quick start (DOSBox + MASM)
1. Put `MASM.EXE` (or `ML.EXE`) and `LINK.EXE` somewhere on the DOS `PATH`, or copy them into `build\`.
2. Mount the project in DOSBox, e.g. `mount c C:\path\to\HashGuard` then `c:`.
3. `cd build` → `BUILD.BAT` (use `BUILD ML` if you only have ML.EXE).
4. `RUN.BAT` starts the program. Type PDF names relative to the `database` folder, e.g. `..\TEST_FILES\SAMPLE.PDF`.

Full steps: `documentation/INSTALLATION_GUIDE.md`. Usage: `documentation/USER_MANUAL.md`.

## Folder layout
| Path | Content |
|---|---|
| `src/MAIN.ASM` | shared data, menu loop, the six actions; `INCLUDE`s the other modules (one object file) |
| `src/MD5.ASM` | complete MD5 (64 steps, padding, 64-bit length, streaming Init/Update/Final) |
| `src/FILEIO.ASM` | file-name input/validation, chunked file reading (INT 21h) |
| `src/DATABASE.ASM` | 64-byte fixed-record binary database `HGDB.DAT` |
| `src/UI.ASM` | screen output, hex/decimal printing, error messages |
| `build/BUILD.BAT`, `RUN.BAT` | build and start scripts |
| `database/` | where `HGDB.DAT` is created at run time |
| `test_files/` | sample PDFs (`SAMPLE.PDF`, `SAMPLE_MODIFIED.PDF`, `OTHER.PDF`) |
| `documentation/` | project report, algorithm explanation, installation guide, user manual, test cases |
| `verify/` | Python **verification aids** (not part of the application): an 8086 interpreter that executes the real `.ASM` sources |

## Testing status — please read
* **Executed:** `MD5.ASM` and the complete program (`MAIN.ASM` + modules) were run through an 8086 interpreter
  (`verify/`) with emulated DOS INT 21h services: 12 MD5 test inputs × 2 chunkings and 21 application scenarios — all passed
  (logs: `verify/RESULTS_*.txt`).
* **NOT executed:** assembling with real MASM/ML, linking with LINK, and running inside real DOSBox. Those tools were not
  available when this project was produced. No build or DOSBox result is claimed. If MASM reports an error on your
  version, send the exact message and line number.

## Limits
Files up to 4 GB (32-bit length counter; MD5's 64-bit length field is written in full); file names up to 45 characters
including path; MD5 is not collision-resistant, so it detects accidental or casual modification but is not suitable
against a determined attacker. See `documentation/PROJECT_REPORT.md`.
