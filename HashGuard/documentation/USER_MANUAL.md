# User Manual

Start with `RUN.BAT`. The menu appears:

```
========================================
              HASHGUARD
       PDF INTEGRITY VERIFICATION

   1. Generate PDF Hash
   2. Register PDF Document
   3. View Registered Documents
   4. Verify PDF Integrity
   5. Delete Registered Document
   6. Exit

========================================
Enter Your Choice:
```
Press one key (1–6). Anything else shows `Invalid selection`. After each action, press any key to return.

File names are typed relative to the folder HashGuard was started from (`database\` with RUN.BAT), e.g.
`..\TEST_FILES\SAMPLE.PDF`. Upper/lower case does not matter. Maximum 45 characters. The characters `* ? < > | "` and
spaces are rejected.

| Option | What it does | Messages |
|---|---|---|
| 1 Generate | Prints the 32-hex-digit MD5 of the file. Nothing is stored. | `MD5 hash : …`, `File not found`, `Path not found` |
| 2 Register | Hashes the file and saves name + hash in `HGDB.DAT`. | `Document registered successfully`, `already registered` |
| 3 View | Lists all registered names with their hashes and the total. | `No documents are registered yet` |
| 4 Verify | Re-hashes the file and compares with the stored hash. | `HASH MATCHED`, `HASH MISMATCHED` (shows both hashes), `NOT REGISTERED` |
| 5 Delete | Removes the registration (not the PDF itself). | `Registration deleted`, `NOT REGISTERED` |
| 6 Exit | Leaves the program. | |

Typical session: register the PDF once (2), later verify (4). Registered data is kept in `HGDB.DAT` and is available
again the next time the program starts. If the database error `Database file is damaged` appears, the file was
edited or truncated; close HashGuard and delete `HGDB.DAT` (registrations are lost).
