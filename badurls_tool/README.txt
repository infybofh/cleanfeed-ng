BADURLS OFFLINE UTILITY
=======================

PURPOSE
-------
`badurl.py` is an optional offline support utility. It scans Cleanfeed
mbox-style diagnostic logs, counts URL/host matches, stores cumulative data in
SQLite and writes a generated `bad_url_central` file.

It is not imported or executed by Cleanfeed and must never be called from the
synchronous `innd` article-processing path.

REQUIREMENTS
------------
- Python 3
- Python standard-library `sqlite3`
- Local readable Cleanfeed diagnostic logs
- Writable paths for the SQLite database and generated output

CONFIGURATION
-------------
Edit `config.py` before use. Verify at least:

- `dbfile`: SQLite database path;
- `regex`: expression whose first capture group is counted;
- `threshold`: count required for automatic output;
- `minimum_hits`: minimum count retained in the database;
- `expire_hours`: age after which old database data expires;
- `filelist`: path to `logfile_list`;
- `exclude`: path to `exclude_list`;
- `include`: path to `include_list`;
- `textfile`: generated `bad_url_central` path.

The supplied list files contain comments/examples only and activate nothing by
default.

VALIDATION AND EXECUTION
------------------------

  python3 -m py_compile badurl.py config.py
  chmod 0755 badurl.py
  ./badurl.py

Review the generated central list before installing it. Broad expressions,
small thresholds or unrepresentative log samples can create false positives.
