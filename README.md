<p align="center">
  <a href="https://github.com/infybofh/cleanfeed-ng">
    <img src="docs/social-banner.png"
         alt="cleanfeed-ng"
         width="100%">
  </a>

![Release](https://img.shields.io/github/v/release/infybofh/cleanfeed-ng)
![License](https://img.shields.io/github/license/infybofh/cleanfeed-ng)
![Issues](https://img.shields.io/github/issues/infybofh/cleanfeed-ng)
![Perl](https://img.shields.io/badge/Perl-5.38+-blue)
![INN](https://img.shields.io/badge/INN-2.*-green)
</p>

# cleanfeed-ng

`cleanfeed-ng` is a maintained, lightweight continuation of the historical Cleanfeed filter for the Perl filtering interface of INN `innd`. It is designed for server-to-server Usenet transit filtering, with particular attention to predictable behaviour, low overhead, safe configuration changes, and useful diagnostics.

> **Version:** `2026-07-03`  
> **Status:** **Release candidate / beta**  
> **Runtime:** Perl 5.38 or newer; Ubuntu 24.04 LTS is the minimum supported platform baseline.

This release is intended for real-world testing in `audit` mode before wider production use. Please report false positives, regressions, performance issues, and unusual log events.

## Project goals

- Preserve the practical philosophy and proven filtering model of Cleanfeed.
- Correct long-standing defects and modernize the implementation for current INN systems.
- Keep the synchronous `innd` hot path lightweight: no network calls, databases, HTTP services, antivirus engines, or other blocking dependencies.
- Make new heuristics observable before enforcement through `audit` mode.
- Emit granular, stable `CF-*` reason codes so administrators can identify the exact rule that matched.
- Provide exhaustive, heavily commented examples suitable for both experienced newsmasters and new administrators.

## Highlights

- Improved yEnc, MIME, Base64, uuencode, and misplaced-binary detection.
- Correct multipart yEnc metadata validation without comparing a complete-file size to a single article part.
- Peer- and hierarchy-based policies with `off`, `audit`, `quarantine`, and `reject` modes.
- Safe external regex loading with validation and last-known-good retention.
- Trusted-source lists with granular bypass controls.
- Bounded counters, CSV and key/value statistics, structured syslog events, and an HTML statistics page.
- Atomic state/statistics writes and configuration fingerprinting.
- Standalone configuration and article-inspection tooling.
- Comment-only `bad_*` and `trusted_*` examples that are safe to copy before customization.

## Release focus

This release concentrates on hot-path efficiency and operational safety: bounded and cached scans, constant-memory long-line checks, a modern Perl baseline, an expanded HTML statistics page, parameterized SQLite queries in the offline URL tool, IPv6 literal URL recognition, and standalone audit-analysis and benchmark tools.

External body rules preserve historical Cleanfeed semantics: `bad_body`, `bad_url`, and `bad_url_central` inspect a bounded, cached, lowercased text window, and top-level `text/*` Base64 content is decoded before matching.

## Start here

1. Read the complete installation and operational guide: [`README.txt`](README.txt).
2. Review every setting in the canonical configuration reference: [`cleanfeed.local.example`](cleanfeed.local.example).
3. Read the reason-code reference: [`docs/REASON-CODES.md`](docs/REASON-CODES.md).
4. For Perl regex examples, see [`docs/REGEX-COOKBOOK.md`](docs/REGEX-COOKBOOK.md) when present and [`samples/README.txt`](samples/README.txt).
5. Begin new or changed policies in `audit` mode and inspect real traffic before enabling `reject`.

## Quick verification

From the extracted package directory:

```sh
CLEANFEED_CONFIG_DIR='' perl -c cleanfeed
perl -c cleanfeed.local.example
perl -c cleanfeed-admin.pl
prove -v tests
sha256sum -c MANIFEST-SHA256.txt
```

The checksum manifest is intentionally deployment-focused. It covers the runtime filter, administrative/helper programs, canonical configuration, and operator-editable sample/list files. Repository metadata, GitHub templates, prose documentation, licensing text, central-list project scaffolding, and tests are deliberately not included in that manifest.

## Documentation

- [`README.txt`](README.txt) — installation, deployment, rollback, configuration, logging, statistics, and operational guidance.
- [`cleanfeed.local.example`](cleanfeed.local.example) — exhaustive parameter reference with extensive comments and examples.
- [`TECHNICAL-REVIEW.md`](TECHNICAL-REVIEW.md) — implementation review and design notes.
- [`CHANGELOG.md`](CHANGELOG.md) — release history.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — contribution and review expectations.
- [`SECURITY.md`](SECURITY.md) — security reporting and deployment assumptions.

## Safety and performance

The filter runs synchronously inside the INN article path. Expensive work is bounded where possible, shared scan windows are cached per article, disabled checks should avoid body inspection, and periodic reports are not generated for every article. Nevertheless, every site has different traffic. Use `audit` first, monitor CPU and log volume, and validate representative traffic before promoting a rule to `reject`.

No content detector can identify every deliberately encrypted or arbitrarily obfuscated payload without risking false positives. Content checks should be combined with narrow hierarchy/peer policy, conservative limits, and site-specific evidence.

## Project history and credit

`cleanfeed-ng` is derived from the historical Cleanfeed project. Credit and copyright notices from the original code are retained. The goal is not to erase or replace that work, but to keep a proven INN transit filter maintained, testable, understandable, and useful on current systems.

## Contributing

Bug reports, false-positive reports, performance measurements, documentation fixes, tests, and code contributions are welcome. Please include the exact version, relevant `CF-*` code, sanitized log lines, configuration context, and enough article structure to reproduce the issue without publishing private data.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) before submitting changes.

## License

Distributed under the license included in [`LICENSE`](LICENSE), while retaining the notices and terms applicable to the original Cleanfeed code.
