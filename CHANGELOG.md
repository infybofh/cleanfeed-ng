# Changelog

## 2026.07.3-rc2 - Development/testing tree

- Fixed statistics generation during filter reload before the next article.
  Report functions now use a local report timestamp instead of the article-path
  global `$now`, preventing empty `generated_epoch` values and negative uptime.
- Enabled periodic `filter: status:` reporting through INN syslog by default
  (`inn_syslog_status => 1`).
- Added practical default paths for the legacy text/HTML reports, key=value and
  CSV metrics, and rotated debug batches.
- Added one-time output-path preparation at the first article after load/reload.
  Missing directories/files are created when permissions permit; otherwise a
  clear news-log diagnostic tells the newsmaster to fix permissions or disable
  that output.
- Added a safe non-atomic fallback for pre-created writable files under a
  root-owned `/var/www`, avoiding any recommendation to make the whole web root
  writable by the INN user.
- Expanded built-in comments and operator documentation for status, metrics,
  debug outputs, default paths, permissions, and the disclosure risk of serving
  the legacy text statistics file publicly.
- Fixed first-use debug rotation checking an absent batch file and added error
  reporting when a batch rotation rename fails.

- Added an early Perl-version bootstrap guard. If the interpreter embedded in
  `innd` is older than Perl 5.38, cleanfeed-ng now emits an explicit fatal
  diagnostic (using INN syslog when available, with a direct `news.err`
  fallback) and refuses to initialize instead of leaving stale filter code with
  undefined runtime state.
- Added an initialization-complete guard for reload safety. A previously loaded
  `filter_art()` surviving a failed reload now fails open, logs the bootstrap
  error once, and does not touch configuration, counters or history objects.
- Added the effective embedded Perl version and `initialization=ok` to the
  one-time runtime banner, making accidental `update-alternatives` or libperl
  changes visible directly in `news.notice`.

- Fixed a fatal reload/runtime failure where an undefined Message-ID history
  queue could make `filter_art()` die and cause INN to disable Perl filtering.
  Queue initialization is now centralized, missing state is re-created
  defensively, and trim/statistics paths tolerate an unavailable queue.
- Added a one-time runtime banner after each load or reload, emitted on the
  first article when the INN syslog callback is available. It reports the
  effective version, configuration directory, local-config state and principal
  policy/binary settings.
- Deferred the `study_max_lines` deprecation notice to the same first-article
  runtime point so it is not lost during initial embedded-Perl startup.
- Restored the historical `allexclude` ordering before the new lightweight
  guards and policy engine. Articles whose complete Newsgroups/Followup-To
  distribution matches `allexclude` (including the default `linux.*` and
  `mailing.*` hierarchies) bypass filtering, while crossposts to any
  non-excluded group remain fully checked.
- Fixed policy-mode rejects being logged twice (`rule=policy.binary` followed
  by `rule=other`). Reject mode now emits and counts one definitive event with
  the explicit stable rule and corresponding `CF-POLICY-*` code.
- Added regression coverage for MID-history recovery, runtime-banner behaviour,
  historical `allexclude` semantics, crosspost handling, and single-event
  policy rejection logging.
- Documented the complete `CLEANFEED_CONFIG_DIR` setup, including its
  set/unset/empty semantics, a Debian/Ubuntu systemd override, runtime
  verification, and the requirement for one full INN restart after changing
  the service environment.
- Removed the obsolete Perl `study()` call from the synchronous article path.
- Kept `study_max_lines` temporarily accepted and ignored, with one runtime
  deprecation notice when explicitly configured and a checker warning from
  `cleanfeed-admin.pl`.
- Added a lightweight bounded cache for deterministic per-newsgroup regex
  classification, using one integer bitmask per cached group and a simple full
  clear at the configured limit; group names over 255 bytes are never retained.
- Kept moderation state, `Restricted_Groups`, article decisions, reason codes,
  audit events and body/header findings outside the group cache.
- Added cache configuration validation and regression coverage for hits,
  disabling, bounds and full-clear behaviour.
- Expanded historical attribution to include original author Jeremy Nixon,
  subsequent maintainer Marco d'Itri and later maintainer Steve Crook.
- Adopted the `YYYY.MM.VV` version format with optional `-alN`, `-beN` and
  `-rcN` suffixes. The earlier `2026-07-03 RC1` package is now referred to as
  `2026.07.3-rc1` without changing the already-published archive.
- Clarified that `2026.07.3-rc1` remains the stable packaged release, while RC2
  is available only from Git for testing at the administrator's own risk.

Versions use `YYYY.MM.VV`, where `VV` is the sequential project version within
that month. Optional suffixes identify alpha (`-alN`), beta (`-beN`) and release
candidate (`-rcN`) builds.

## 2026.07.3-rc1 - Performance, modern Perl baseline and operational tooling

Published originally as `2026-07-03 RC1`.

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

All notable changes to cleanfeed-ng are documented here.

## 2026.07.2-al2 - Safe policy scope and full rejection taxonomy

Published originally as `2026-07-02` (Alpha 2).

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

## 2026.07.1-al1 - Initial cleanfeed-ng release

Published originally as `2026-07-01` (Alpha 1).

### Changed
- Renamed the maintained project to **cleanfeed-ng**.
- Introduced the first date-oriented release numbering, later refined to `YYYY.MM.VV`.
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
