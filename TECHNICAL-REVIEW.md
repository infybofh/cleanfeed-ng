# cleanfeed-ng technical review

## Scope

This distribution is maintained as a Perl filter for INN2 `innd` transit
traffic. It is not a reader-side filter, antivirus engine, archive inspector or
copyright classifier. The review covered the runtime filter, its complete local
configuration example, external `bad_*` files, policy/metrics code, regression
tests and the optional offline URL-analysis utility.

## Confirmed corrections

- Improved yEnc detection for short, multipart, CRLF, attribute-order and common
  malformed variants.
- Extended bounded binary scanning beyond the historical 4 KiB preview, with a
  configurable head window and tail window.
- Added detection of short MIME binary entities and attachments independently
  of the old Base64 line threshold.
- Preserved normal Base64 `text/plain` messages unless other binary evidence is
  present.
- Added safe extension checks and retained uuencode detection.
- Corrected the historical `fslexclude`/`fsl_exclude` mismatch.
- Added configuration validation for booleans, non-negative values, policy
  modes, regex compilation and cutoff/ceiling relationships.
- Added safe compilation/reload behavior for external regex lists.
- Added peer and hierarchy policies with `off`, `audit`, `quarantine` and
  `reject` modes, byte limits and binary permissions.
- Added configurable excessive-`Supersedes` policy. Cancel-Lock and Cancel-Key
  remain the responsibility of INN2.
- Added bounded counters plus atomic key=value status, CSV history, optional
- Updated the optional `badurls_tool` to Python 3 and the standard `sqlite3`
  module. It remains offline tooling and is not called from the article hot
  path.

## Configuration and samples

`cleanfeed.local.example` is the canonical exhaustive configuration reference.
It contains every built-in runtime parameter plus the `nobase64` compatibility
override, with inline descriptions and safe defaults.

The `samples/` directory contains comment-only examples for every external
`bad_*` file currently loaded by this distribution. Copy only the files needed
by the site and activate narrowly scoped patterns after testing.

## Automated verification

Run from the package root:

```sh
CLEANFEED_CONFIG_DIR='' perl -c cleanfeed
perl -c cleanfeed.local.example
prove -v tests
python3 -m py_compile badurls_tool/badurl.py badurls_tool/config.py
sha256sum -c MANIFEST-SHA256.txt
```

The Perl suite covers binary detection, runtime/default key integrity,
configuration validation, peer/hierarchy policy selection, rejection
categorisation and atomic metrics output. It does not claim full protocol
fuzzing or exhaustive coverage of every historical Cleanfeed heuristic.

## Deployment notes

1. Back up the active `filter_innd.pl`, local configuration and external lists.
2. Install `cleanfeed` at the path configured as INN's Perl filter.
3. Install and edit `cleanfeed.local.example` as `cleanfeed.local`.
4. Compile-check the installed filter using the same Perl environment used by
   INN.
5. Start new peer/hierarchy policies in `audit` mode.
6. Reload with `ctlinnd reload filter.perl` and immediately inspect INN logs.
7. Test with disposable groups and controlled articles before enabling reject
   mode on production hierarchies.

A fatal Perl compile/runtime error can disable INN Perl filtering. Monitoring
for filter-load failures and maintaining a known-good rollback copy are
mandatory operational safeguards.

## Limitations

Transport encodings and declared MIME structures can be classified reliably
only within practical limits. Deliberately encrypted, fragmented or disguised
payloads cannot always be distinguished from legitimate text without false
positives. Expensive network reputation checks, archive extraction, malware
scanning and semantic classification must not run synchronously inside `innd`.

## Lightweight operational update

The maintained release now also includes:

- timestamp-based reload of external lists, with the historical article-count
  trigger retained as an option;
- defensive external-regex limits, rejection of executable regex constructs,
  last-known-good fallback, and basic pathological-pattern screening;
- stable `CF-*` reason codes on every rejection;
- configurable header/body line-length checks;
- lightweight malformed MIME, Base64, and yEnc consistency checks;
- a bounded raw-byte profile detector for opaque binary payloads;
- granular trusted Path/host/From/Message-ID lists;
- a SHA-256 configuration fingerprint for comparing transit nodes;
- bounded top-offender summaries and rate-anomaly auditing;
- supplemental Path sanity checks;
- optional IDN normalization when `Net::IDN::Encode` is locally available;
- `cleanfeed-admin.pl` for standalone configuration checking, rule inventory,
  fingerprints, and lightweight raw-article testing.

The new checks default to `audit` where a site may need to observe local traffic
before rejecting. They use bounded hashes and bounded body windows, perform no
network access, and add no mandatory non-core Perl dependency. Cancel-Lock and
Cancel-Key remain intentionally delegated to INN2.

## Explicit non-goals

No antivirus, DNSBL, HTTP, SQL, archive extraction, machine learning, GeoIP,
network blacklist updater, embedded metrics service, physical spool quarantine,
or complex traffic shaper has been added. These would be inappropriate in the
synchronous `innd` filter path or duplicate existing INN facilities.


## Granular anomaly taxonomy and real-feed correction

Audit logs from a production binary transit showed that the previous generic `malformed.encoding` event incorrectly compared multipart `=ybegin size` (the complete file) with multipart `=yend size` (one part). cleanfeed-ng 2026-07-01 and later remove that invalid comparison.

Checks now emit independent rules for MIME boundary absence, missing Base64 payload, missing yEnc begin/end markers, orphan/missing yEnc part lines, invalid part ranges, invalid part numbers, single-part size mismatch and multipart part/range mismatch. Path and rate checks are similarly split. The byte-profile signal remains a separate heuristic and defaults to audit.


## 2026-07-03 full-code review

A second production-log review showed that a correct binary signal can still be
an incorrect policy decision. The raw-byte profile correctly identified yEnc
payloads as binary, but applying that signal globally would reject legitimate
`alt.binaries.*` traffic when configured in reject mode.

The detector is now guarded by `binary_byte_profile_scope`. The default
`policy` value evaluates the fully merged peer/hierarchy policy and runs the
heuristic only when that policy forbids binary data. This separates detection
("these bytes look binary") from policy ("binary data is forbidden here").

The audit also found that historical rejection calls often used broad short
reasons such as `EMP`, `Bot signature`, `HTML`, `Rogue cancel`, or `U2
violation`. The reject still occurred, but structured logging could classify it
as `other`. Maintained families now receive stable rules and CF codes. Explicit
rules are passed by the EMP paths, while a compatibility classifier remains for
old local hooks and untouched third-party extensions.

Code-quality checks now detect duplicate named subroutines within one Perl
package, ambiguous generic EMP rejection calls, omission of the safe byte
profile default, and disappearance of required stable rule mappings.

The documentation and configuration examples were deliberately expanded rather
than shortened. Every external sample remains inactive by default, but contains
multiple bounded examples and explains why anchors, escaped dots, Path-token
boundaries, and narrow campaign identifiers reduce false positives.

## 2026-07-03 corrected build: normalized bounded external scans

A post-release independent review found that the first 2026-07-03 archive
bounded external body regex input by switching from the historical normalized
`$body` representation to raw article bytes.  That unintentionally made
`bad_body` case-sensitive in practice and prevented `bad_body`/`bad_url` from
seeing text contained in top-level Base64 `text/*` articles.

The corrected archive keeps the same release number and restores the original
security semantics: the bounded window is decoded when appropriate, converted
to lowercase, cached per article, and `Bad_Body_RE` is explicitly compiled with
`/i`.  Regression tests cover mixed-case spam terms and Base64-encoded text
URLs so this behavior cannot silently regress again.


## 2026.07.3-rc2: bounded newsgroup classification cache

RC2 removes the obsolete `study()` call from the article hot path. The legacy
`study_max_lines` key remains temporarily accepted and ignored so existing site
configurations can be cleaned up without affecting service; both the runtime
loader and the standalone checker report its deprecation when explicitly used.

The historical group-classification loops repeatedly evaluate the same site
regexes for popular newsgroups. RC2 adds a bounded cache containing one integer
bitmask per recently seen group. The cache deliberately excludes moderation
state, `Restricted_Groups`, article decisions, reason codes, audit events and
all body/header findings. It performs no per-hit logging or LRU/timestamp
maintenance. At the configured entry limit it clears the cache and repopulates
naturally from subsequent traffic. Group names longer than 255 bytes are always
classified normally but are never retained.

When the cache is disabled, the two historical classification phases remain
separate, so opting out does not double the number of regex evaluations. Tests
cover cache hits, disablement, entry bounds, overflow clearing, oversized keys
and representative classification equivalence.
