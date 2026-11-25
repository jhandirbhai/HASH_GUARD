TEST FILES
==========
SAMPLE.PDF           original document to register
SAMPLE_MODIFIED.PDF  same layout, one character changed (2026 -> 2027) - use to test mismatches
OTHER.PDF            a second document that is never registered (tests "NOT REGISTERED")

Expected MD5 (computed independently with Python hashlib):
  SAMPLE.PDF           d50cf08dbf2b633c8889f095e9236831   (446 bytes)
  SAMPLE_MODIFIED.PDF  0d0afdf129ef57fb669411ad4050beb7   (446 bytes)
  OTHER.PDF            18791484918a31fe0fad72d972058456   (451 bytes)

To simulate tampering without a PDF editor: copy SAMPLE_MODIFIED.PDF over SAMPLE.PDF
(DOS: COPY SAMPLE_MODIFIED.PDF SAMPLE.PDF), then run "Verify PDF Integrity".
Keep a backup of the original SAMPLE.PDF first.
Any other file can also be hashed; HashGuard does not parse PDF structure.
