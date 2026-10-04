# cleanfeed-ng 2026.10.1 release notes

`2026.10.1` is the first stable October 2026 Calendar Versioning release. It
promotes the production-tested RC3 PHN work and incorporates the subsequent
review findings from Julien ÉLIE, Jesse Rehmer, and live historical-backfill
traffic.

## Versioning

cleanfeed-ng now documents its release scheme explicitly as CalVer:

```text
YYYY.MM.N[-alN|-beN|-rcN]
```

`N` is the sequential release number within the calendar month. Historical
July 2026 tags and release notes are retained unchanged.

## Followup-To crosspost arithmetic

Cleanfeed historically defines `fupcnt` as the number of effective followup
targets: the explicit `Followup-To` list when present, otherwise `Newsgroups`.
That behaviour is intentional and remains unchanged.

The inherited meow/topic checks, however, subtracted counters built from the
unique `Newsgroups` + `Followup-To` union from `fupcnt`. When the two headers
differed, the operands represented different sets and the result could be
incorrect or even negative.

`2026.10.1` adds followup-only meow/topic counts and uses those values whenever
subtracting from `fupcnt`. Union counters remain unchanged for policy/presence
checks that intentionally consider both headers.

## Immediate reports after load/reload

On the first successful article after filter load/reload, cleanfeed-ng now
forces a current snapshot of:

- the HTML status page;
- the legacy text statistics file;
- the key/value metrics status file;
- the CSV statistics file (one explicit boundary row).

This prevents an old `cleanfeed_version=` value or stale warnings from remaining
visible until the next `stats_interval`/CSV interval.

Runtime warnings now come from one internal source and are reused by syslog,
HTML, legacy text, and key/value status. The status file adds:

```text
runtime_warning_count=N
runtime_warning_<key>=1
```

The currently defined keys include `cleanfeed_local`, `dontrejectfiltered`, and
`phn_aggressive`.

Julien ÉLIE also proposed that INN `innreport` recognize generic
`/^filter: WARNING /` lines; that parser change belongs to INN rather than this
repository.

## RFC Path diag-match

RFC 5536/5537 permits `!!` in a Path as `diag-match` syntax. The previous
supplemental Path sanity check split on every `!` and therefore reported a
synthetic empty token. `2026.10.1` recognizes a single `!!` between non-empty
components as valid syntax and excludes the diagnostic separator from the
supplemental hop count.

Malformed leading/trailing separators and longer runs such as `!!!` remain
reportable. `cleanfeed-admin.pl --test-article` uses the same semantics.

## PHN behaviour carried forward from RC3

PHN still prefers the first available per-poster identity:

1. `Injection-Info` `posting-account`;
2. `Injection-Info` `posting-host`;
3. `NNTP-Posting-Host`;
4. Path `.POSTED.<source>`;
5. shared injector fallback.

The shared fallback remains audit-only by default:

```perl
phn_aggressive => 0,
phn_weak_identity_mode => 1,
```

Setting `phn_aggressive => 1` deliberately restores the legacy shared-injector
reject and emits a runtime warning.

## Documentation and code navigation

`docs/REASON-CODES.md` is now both the operator code reference and the developer
navigation index. It explains where each rule family is generated and how to
trace a `cleanfeed_event` rule or `CF-*` code back to the relevant source
function. README, configuration examples, regex guidance, contribution rules,
security notes, sample-list documentation, and the offline bad-URL utility
documentation were reviewed and expanded.

## Upgrade notes

No configuration rename is required from RC3. Review only deliberate local
overrides, especially:

```perl
phn_aggressive => 1,
```

After installation, reload the Perl filter (or restart INN when changing the
embedded Perl/runtime environment). On the first article processed after the
reload, confirm the runtime banner and report files show `2026.10.1`.

Run before deployment:

```sh
CLEANFEED_CONFIG_DIR='' perl -c cleanfeed
perl -c cleanfeed.local.example
prove -v tests
sha256sum -c MANIFEST-SHA256.txt
```
