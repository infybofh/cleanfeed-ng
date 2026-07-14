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
