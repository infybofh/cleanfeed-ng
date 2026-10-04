# Contributing to cleanfeed-ng

Contributions are welcome from news administrators, INN maintainers and Perl developers.

## Before submitting code
1. Run `CLEANFEED_CONFIG_DIR='' perl -c cleanfeed`.
2. Run `perl -c cleanfeed.local.example`.
3. Run `prove -v tests`.
4. Add regression tests for every behaviour change.
5. Keep synchronous article-path work bounded and free of network access.

## Compatibility and design rules
- Preserve INN Perl-filter compatibility.
- New heuristic checks must default to `audit` unless they are deterministic.
- Every independent anomaly must have its own stable rule name and `CF-*` code.
- Avoid mandatory non-core dependencies.
- Do not add antivirus, DNSBL, HTTP, SQL, archive extraction, machine learning, GeoIP, embedded web services or Cancel-Lock/Cancel-Key handling.

## Central lists
List contributions must document scope, inclusion criteria, removal criteria, evidence source, maintainer and expected false-positive policy. Broad or unexplained entries will not be accepted.


## Finding the implementation behind a log event

`docs/REASON-CODES.md` is the developer index as well as the operator reference.
Start from the structured `rule=` value or `CF-*` code, then follow the listed
function/source area. `reject_code()` contains the canonical public code
mapping. Do not key tests or automation to human-readable reason text.

When changing group-count logic, state explicitly which set is being counted:
`Newsgroups`, effective `Followup-To`, or their unique union. Never subtract a
counter derived from one set from a total derived from another. Add a regression
case where `Followup-To` differs from `Newsgroups`.

## Release checklist

1. Update `VERSION` and `$cleanfeed_ng_version` using CalVer `YYYY.MM.N`.
2. Update CHANGELOG and add current release notes; do not rewrite historical notes.
3. Run syntax checks, the full test suite, and manifest verification.
4. Test an upgrade by overlaying the incremental archive on the previous release.
5. Verify the runtime banner and generated status files report the new version.
6. Rebuild `MANIFEST-SHA256.txt` only after all content is final.
