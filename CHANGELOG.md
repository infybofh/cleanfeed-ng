# Changelog

## 2026-07-03 - Performance, modern Perl baseline and operational tooling

- Set the supported runtime baseline to Perl 5.38 or newer, matching Ubuntu
  24.04 LTS, and removed ancient Perl compatibility branches.
- Connected `external_regex_body_bytes` to `bad_body`, `bad_url` and
  `bad_url_central`, bounding administrator regex scans on large articles.
- Reworked long-line detection to use constant-memory `index()` scanning and
  immediate short-circuiting instead of splitting complete article bodies.
- Cached the bounded binary head/tail scan once per article.
- Added an explicit empty-body guard to the byte-profile detector.
- Hardened atomic status/HTML writes with exclusive temporary-file creation.
- Removed Prometheus output; CSV, key/value status and the expanded HTML report
  remain the supported low-overhead statistics interfaces.
- Expanded the HTML status report with audit/reject counters, rule totals, peer
  and hierarchy tables, history sizes and the configuration fingerprint.
- Added optional standalone audit-log analysis and benchmarking tools.
- Added IPv6-literal URL recognition and converted SQLite operations in the
  offline bad-URL helper to parameterized queries.
- Removed unused compatibility wrappers and strengthened tests for hot-path
  behaviour, documented parameters and trusted bypass rules.

All notable changes to cleanfeed-ng are documented here. Versions use `YYYY-MM-VV`, where `VV` is the sequential release number within that month.

## 2026-07-02 - Safe policy scope and full rejection taxonomy

### Fixed
- Prevented `binary.byte_profile` from auditing or rejecting legitimate binary
  traffic when the effective policy permits binary payloads.
- Added `binary_byte_profile_scope` with `policy`, `text-only`, `all`, and `off`
  values; the safe shipped default is `policy`.
- Corrected the historical EMP MD5/PHL/PHN/PHR/FSL paths so they emit exact
  stable rules instead of `rule=other`.
- Reordered reason classification so precise MIME/yEnc structural failures are
  evaluated before broad binary/MIME categories.
- Removed duplicate/ambiguous maintenance code found during the full audit and
  added a regression test against duplicate named subroutines per package.

### Changed
- Expanded stable rule families for bot signatures, HTML, cancel policy,
  control messages, distribution policy, reposts, forged approvals, bad
  hosts/Paths, topic filters, test crossposts and Terms-of-Service rules.
- Reworked and expanded comments in the runtime filter and canonical example.
- Greatly expanded every external-list sample with disabled copyable regexes,
  warnings, boundaries and beginner-oriented explanations.

### Added
- `docs/REGEX-COOKBOOK.md`.
- Byte-profile policy-scope regression tests based on production transit logs.
- Code-quality tests for duplicate subroutines, ambiguous EMP rejects and
  required stable rule mappings.

## 2026-07-01 - Initial cleanfeed-ng release

### Changed
- Renamed the maintained project to **cleanfeed-ng**.
- Adopted the `YYYY-MM-VV` release scheme.
- Split combined audit checks into stable, granular rules and `CF-*` codes.
- Corrected yEnc multipart validation: total file size is no longer compared with the size of a single posted part.
- Added valid comparisons between `=ypart begin/end` and multipart `=yend size`.
- Kept single-part `=ybegin size` / `=yend size` validation with configurable tolerance.

### Added
- GitHub-ready repository metadata, contribution guidance, issue templates, pull-request template and CI workflow.
- Central-list directory layout with documented maintenance criteria.
- Regression tests based on multipart yEnc patterns observed on real transit feeds.

### 2026-07-03 build correction

- Restored the historical normalization used by external `bad_body`, `bad_url`
  and `bad_url_central` rules after introducing bounded body scans.
- `text/*` bodies using top-level Base64 transfer encoding are again decoded
  before administrator regexes are evaluated.
- External body matching remains lowercase/case-insensitive, so existing
  lowercase rule files continue matching uppercase and mixed-case variants.
- Added regression tests for mixed-case body text and Base64-encoded text URLs.
