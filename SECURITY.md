# Security policy

Report vulnerabilities privately to the project maintainer before publishing details. Include the affected version, reproduction steps, operational impact and a proposed fix when available.

cleanfeed-ng runs inside the INN article path. Treat denial-of-service through pathological regexes, unbounded memory growth, unsafe configuration evaluation and filter bypasses as security issues.

## Trusted administrative paths

`CLEANFEED_CONFIG_DIR` is trusted service configuration. Anyone able to alter
the environment of `innd` is already in an administrative security boundary.
Use an absolute path owned by root or the INN account and do not use a directory
writable by untrusted users. The same ownership rule applies to status, CSV and
HTML report directories because cleanfeed-ng creates atomic temporary files
there before rename.
