@echo off
rem Starts HashGuard from the DATABASE folder so that HGDB.DAT is created there.
rem PDF names are typed relative to that folder, e.g.  ..\TEST_FILES\SAMPLE.PDF
if not exist HASHGUARD.EXE goto nobuild
cd ..\database
..\build\HASHGUARD.EXE
cd ..\build
goto end
:nobuild
echo HASHGUARD.EXE not found. Run BUILD.BAT first.
:end
