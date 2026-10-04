# cleanfeed-ng documentation index

- **REASON-CODES.md** — stable `rule=` / `CF-*` taxonomy **and source-code map**.
  Start here when a log event must be traced back to the code that generated it.
- **REGEX-COOKBOOK.md** — safe Perl-regex patterns for external lists and
  `%config_append` examples.
- **../README.md** — project overview, current release and operator quick start.
- **../README.txt** — detailed installation/configuration/operations guide.
- **../cleanfeed.local.example** — canonical configuration reference.
- **../TECHNICAL-REVIEW.md** — implementation history and design rationale.
- **../CONTRIBUTING.md** — test, code-review and release rules.
- **../SECURITY.md** — security boundary and reporting guidance.

For a runtime event such as:

```text
cleanfeed_event action=reject rule=emp.phn ...
```

look up `emp.phn` in `REASON-CODES.md`, then follow the named functions in
`cleanfeed`. Do not use the human-readable `reason=` text as a stable API.
