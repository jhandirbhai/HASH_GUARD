@echo off
rem ============================================================
rem  HashGuard build script  (run it from the HashGuard\build folder)
rem
rem    BUILD          assemble with MASM.EXE  (MASM 5.x or 6.x) + LINK.EXE
rem    BUILD ML       assemble with ML.EXE    (MASM 6.x / 8.0) + LINK.EXE
rem
rem  MAIN.ASM INCLUDEs UI.ASM, FILEIO.ASM, MD5.ASM and DATABASE.ASM,
rem  so a single object file (MAIN.OBJ) is produced and linked.
rem  MASM, ML and LINK must be reachable through PATH (or be copied
rem  into this folder).
rem ============================================================
if not exist ..\src\MAIN.ASM goto nosrc
if exist HASHGUARD.EXE del HASHGUARD.EXE
if exist MAIN.OBJ del MAIN.OBJ
cd ..\src
if "%1"=="ML" goto useml
masm MAIN.ASM,..\build\MAIN.OBJ,..\build\MAIN.LST;
if errorlevel 1 goto failasm
goto dolink
:useml
ml /c /Fo..\build\MAIN.OBJ /Fl..\build\MAIN.LST MAIN.ASM
if errorlevel 1 goto failasm
:dolink
cd ..\build
link MAIN.OBJ,HASHGUARD.EXE,NUL,,;
if errorlevel 1 goto faillink
if not exist HASHGUARD.EXE goto faillink
echo.
echo Build OK: build\HASHGUARD.EXE
echo Start it with RUN.BAT
goto end
:nosrc
echo ERROR: run BUILD.BAT from the HashGuard\build folder.
goto end
:failasm
cd ..\build
echo.
echo ERROR: assembly failed - read the messages above.
goto end
:faillink
echo.
echo ERROR: linking failed - read the messages above.
:end
