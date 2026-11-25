DATABASE FOLDER
===============
HashGuard creates and updates the file HGDB.DAT in the folder it is started from.
RUN.BAT starts the program from this folder, so HGDB.DAT appears here after the first
registration. (If you start HASHGUARD.EXE from another folder, a new HGDB.DAT is made there.)

File format: a sequence of fixed 64-byte records, record n at offset n*64.
  byte  0      status: 1 = active, 0 = deleted (slot is re-used by the next registration)
  bytes 1-47   file name, upper case, zero padded
  bytes 48-63  MD5 digest, 16 raw bytes
There is no header. A file whose size is not a multiple of 64 is reported as damaged.
To reset the system, close HashGuard and delete HGDB.DAT.
