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


## Filter correctness is security-relevant

A transit-filter false positive can discard legitimate articles, while a false
negative can propagate abusive traffic. Treat identity aggregation bugs,
unbounded rate-limit keys, unsafe header trust assumptions, and discrepancies
between audit and reject semantics as security-sensitive correctness issues.

Structured event fields intentionally avoid logging raw PHN posting-account or
posting-host identities; only the source type and a correlation hash are emitted.
Operational status files can disclose configuration and traffic counters, so do
not expose them publicly without an explicit access-control decision.
