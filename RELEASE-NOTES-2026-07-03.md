# cleanfeed-ng 2026-07-03 release notes

This release focuses on predictable latency and safer operation on busy INN
transit servers.  It requires Perl 5.38 or newer.

## Hot-path changes

- Long-line checks no longer split or copy an entire article body.
- Binary head/tail data is cached once for all detectors in an article.
- External body and URL regexes scan a bounded prefix controlled by
  `external_regex_body_bytes`.
- Disabled checks perform no body scan.
- Empty articles cannot trigger division by zero in byte-profile analysis.

## Statistics

Prometheus output was removed.  The supported outputs are the cumulative CSV,
the atomic key/value status file, syslog summaries, and the expanded built-in
HTML status page.  The HTML page now shows decisions, rates, history table
sizes, rule totals, peer/hierarchy counters, supersedes counters and the active
configuration fingerprint.

## Standalone tools

- `tools/cleanfeed-audit-analyzer.py` summarizes `cleanfeed_event` and legacy
  `rejecting[perl]` log lines without interacting with INN.
- `tools/cleanfeed-benchmark.pl` measures selected low-level scanning routines
  against synthetic text and binary bodies.  It is a development aid, not a
  substitute for production profiling.

## Upgrade notes

Review `external_regex_body_bytes` before deployment.  A value of 65536 is the
recommended default.  Value 0 restores complete-body scans and may be expensive
on binary feeds.

## Corrected build: external body normalization

The final archive for this same `2026-07-03` release preserves historical
Cleanfeed matching semantics while retaining the new bounded scan and cache.
Administrator `bad_body`, `bad_url`, and `bad_url_central` rules receive a
lowercase textual representation.  Top-level `text/*` articles transferred as
Base64 are decoded before those rules run.  This prevents silent false
negatives for mixed-case spam text and URLs hidden in Base64 text articles.
