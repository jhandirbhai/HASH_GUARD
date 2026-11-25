# Installation Guide

## What you need
* **DOSBox** (or DOSBox-X / DOSBox-Staging) on Windows, macOS or Linux.
* **Microsoft MASM** for DOS: `MASM.EXE` + `LINK.EXE` (MASM 5.x), or `ML.EXE` + `LINK.EXE` (MASM 6.x).
  These come with your university course material. They are not included here.

## Steps
1. Unzip `HashGuard.zip` (for example to `C:\ASM\HashGuard`).
2. Put the MASM tools in a folder (for example `C:\MASM`).
3. Start DOSBox and type:
   ```
   mount c C:\ASM
   mount d C:\MASM
   c:
   set PATH=%PATH%;D:\
   cd HashGuard\build
   ```
   (Adjust the folders to your computer.)
4. Build:
   ```
   BUILD          (uses MASM.EXE)
   BUILD ML       (uses ML.EXE instead)
   ```
   Success message: `Build OK: build\HASHGUARD.EXE`. A listing file `MAIN.LST` is also produced.
5. Run: `RUN.BAT`.

## How the build works
`MAIN.ASM` uses `INCLUDE` to pull in `UI.ASM`, `FILEIO.ASM`, `MD5.ASM` and `DATABASE.ASM`, so MASM creates a single
`MAIN.OBJ`, and `LINK MAIN.OBJ,HASHGUARD.EXE` creates the program (small model, 1 KB stack). This avoids
cross-module symbol/segment problems that are common when several `.OBJ` files share one `.DATA` segment.

## Troubleshooting
| Problem | Fix |
|---|---|
| `Bad command or file name` for `masm` / `link` | the tools are not on `PATH`; copy them into `build\` or fix `PATH` |
| `Cannot open include file UI.ASM` | `BUILD.BAT` must be run from `build\` (it changes into `src\` itself) |
| `Jump out of range` (MASM 5.x only) | tell your lecturer/author the line; MASM 6.x+ (`BUILD ML`) widens jumps automatically |
| `Unresolved external` / link warning `no stack segment` | should not happen; `.STACK 400h` is declared in `MAIN.ASM` |
| Program prints DOS file errors | check the typed path; it is relative to the `database` folder when started with `RUN.BAT` |

> **Honest note:** this package was produced without MASM or DOSBox available, so the real assemble/link step has not been
> executed by the author. The sources use only documented MASM 5.x/6.x syntax and 8086 instructions, and the program
> logic was executed in a software 8086 interpreter (see `TEST_CASES.md`).
