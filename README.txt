cleanfeed-ng
============

Stable packaged release: 2026.07.3-rc1 (available from GitHub Releases)
Current Git development tree: 2026.07.3-rc2 (testing only; no release ZIP)
Minimum Perl: 5.38 (Ubuntu 24.04 LTS baseline)

cleanfeed-ng is a maintained continuation of Cleanfeed for INN transit filtering.
The main branch currently contains RC2 development code and must be used at the
administrator's own risk. Operators who want the stable packaged baseline should
use the 2026.07.3-rc1 ZIP from the GitHub Releases page.

Versions use YYYY.MM.VV, where VV is the sequential project version within the
month. Optional suffixes are -alN for alpha, -beN for beta and -rcN for release
candidates. The package originally announced as 2026-07-03 RC1 is canonically
named 2026.07.3-rc1 under the new scheme.


RC2 HOT-PATH CHANGES
--------------------
The 2026.07.3-rc2 development tree removes the obsolete Perl study() call. The
legacy study_max_lines setting is temporarily accepted and ignored; when it is
present, cleanfeed-ng emits one deprecation notice at configuration load, and
cleanfeed-admin.pl reports it during --check-config.

RC2 also introduces a lightweight bounded cache for deterministic per-newsgroup
regex classification. The cache stores one integer bitmask per recently seen
group. It does not cache moderation state, article decisions, reason codes,
audit events or body/header findings. It performs no per-hit logging and uses a
simple full clear when the configured entry limit is reached, avoiding LRU or
timestamp bookkeeping in the synchronous INN article path. Group names longer
than 255 bytes are classified normally but are not retained.

Default settings:

  group_class_cache_enabled => 1
  group_class_cache_entries => 8192

Set either value to 0 to disable the cache. The maximum accepted entry limit is
65536. The cache is reset whenever configuration is loaded.

PROJECT HISTORY AND CREDIT
--------------------------
Cleanfeed was originally developed by Jeremy Nixon, with further development by
Marco d'Itri and later updates and maintenance by Steve Crook. cleanfeed-ng
retains the historical copyright notices and continues that work for current
INN systems.

GITHUB REPOSITORY LAYOUT
------------------------
The source tree includes GitHub issue templates, a pull-request template, continuous-integration tests, contribution and security policies, a changelog, a VERSION file, and a central-lists area. See CONTRIBUTING.md before submitting changes.

GRANULAR AUDIT AND REJECT EVENTS
--------------------------------
Every independent structural or heuristic check has its own stable rule and CF-* code. Examples include CF-YENC-MISSING-END, CF-YENC-PART-SIZE, CF-MIME-BOUNDARY-MISSING, CF-PATH-HOP-COUNT and CF-PEER-RATE-ANOMALY. This allows administrators to identify exactly which condition generated an event.

For multipart yEnc, `=ybegin size` is the complete file size and is intentionally not compared with the current article part. The filter validates the part range against multipart `=yend size` instead. Single-part size fields remain comparable.

CLEANFEED-NG FOR INN TRANSIT SERVERS
=====================================

PURPOSE
-------
This package provides a maintained cleanfeed-ng distribution for the Perl filter
interface of INN2/innd. It is intended for server-to-server article transit,
not for reader/client filtering.

The package contains:

  cleanfeed                    Runtime filter loaded by INN2.
  cleanfeed.local.example      Exhaustive, heavily commented site config.
  samples/                     Safe, comment-only external bad_* examples.
  tests/                       Syntax, regression, policy and metrics tests.
  badurls_tool/                Optional offline URL-frequency analysis tool.
  TECHNICAL-REVIEW.md          Technical review and maintained-change summary.
  CHANGELOG.md                 Release history.
  CONTRIBUTING.md              Contribution and design rules.
  central-lists/               Shared-list layout and maintenance criteria.
  .github/                     CI and contribution templates.
  README.txt                   This installation/configuration guide.
  MANIFEST-SHA256.txt          Deployment-focused hashes for runtime, helper and sample files.

Historical HTML manuals, intermediate patches, duplicated source trees, reader
filters, packaging utilities and active blacklists are not included. The
optional Python URL tool is offline support software and is never executed in
the innd article-processing path.

REQUIREMENTS
------------
- INN2 with Perl filtering support enabled.
- Perl 5.38 or newer. Ubuntu 24.04 LTS is the minimum supported platform baseline.
  This requirement applies to the Perl interpreter embedded in innd, which may
  differ from the /usr/bin/perl selected in an interactive shell.
- Digest::MD5 is strongly recommended.
- MIME::Base64 is recommended. If unavailable, decoded text/plain Base64
  preview processing is disabled, while independent binary signatures remain.
- The INN runtime user (normally news) must be able to read the configuration
  and write any enabled state, statistics or log files.

DIRECTORY LAYOUT AND CLEANFEED_CONFIG_DIR
-----------------------------------------
Cleanfeed historically defaults to:

  /usr/local/news/cleanfeed/etc

The directory can and normally should be selected without editing the filter by
setting CLEANFEED_CONFIG_DIR in the environment inherited by the innd process.
The three possible states are:

  CLEANFEED_CONFIG_DIR=/some/path
      Read cleanfeed.local and external bad_*/trusted_* files from /some/path.

  CLEANFEED_CONFIG_DIR=''
      Disable all external configuration files. This is intended mainly for
      syntax checks, regression tests and controlled diagnostics.

  CLEANFEED_CONFIG_DIR not set
      Use the compiled fallback /usr/local/news/cleanfeed/etc.

The examples below use /etc/news/cleanfeed. Use one location consistently.

SYSTEMD SETUP (DEBIAN/UBUNTU)
-----------------------------
On Debian and Ubuntu package installations, INN normally runs as the inn2
systemd service. Create a service override:

  systemctl edit inn2

Insert:

  [Service]
  Environment="CLEANFEED_CONFIG_DIR=/etc/news/cleanfeed"

Then apply the new process environment with:

  systemctl daemon-reload
  systemctl restart inn2

Verify the environment inherited by the running innd process:

  sh -c 'tr "\\0" "\\n" < /proc/$(pidof innd)/environ | \\
    grep "^CLEANFEED_CONFIG_DIR="'

IMPORTANT: ctlinnd reload filter.perl re-evaluates the Perl filter and reloads
its files, but it cannot alter environment variables already inherited by the
running innd process. A full INN restart is therefore required after adding or
changing CLEANFEED_CONFIG_DIR in systemd. Later edits to cleanfeed.local or the
external lists only need the normal filter reload.

On systems not using systemd, export CLEANFEED_CONFIG_DIR in the service
manager or startup script that launches innd. Editing the fallback $config_dir
inside cleanfeed also works, but is discouraged because a repository update can
overwrite that local modification.

PERL VERSION AND FAILED-LOAD DIAGNOSTICS
----------------------------------------
cleanfeed-ng checks the Perl version during the earliest bootstrap phase. If
innd is using Perl older than 5.38, the filter refuses to initialize and writes
an explicit fatal diagnostic through INN syslog when available, or directly to
the news.err facility as an early-startup fallback. Example:

  filter: cleanfeed-ng fatal: Perl 5.38.0 or newer is required; \
  the running interpreter is v5.34.0; filter not loaded

A successful load reports the actual embedded interpreter in the one-time
runtime banner:

  filter: cleanfeed-ng runtime version=2026.07.3-rc2 perl=v5.38.2 \
  initialization=ok ...

Check /var/log/news/news.err, the journal and the system log after any failed
filter reload. The output of "perl -V" only describes the interpreter selected
for a new shell command; it does not replace libperl already embedded in a
running innd process. After update-alternatives, Perl package, or libperl
changes, restart INN completely. A ctlinnd reload alone cannot replace the
embedded interpreter.

If a failed reload leaves an older filter_art() definition in the embedded
interpreter, the initialization guard makes that stale function fail open,
logs the bootstrap error once, and prevents access to undefined configuration
or history objects.

INSTALLATION
------------
1. Locate the currently loaded INN Perl filter. Common paths include:

     /etc/news/filter/filter_innd.pl
     /usr/local/news/lib/filter/filter_innd.pl

   Check your inn.conf, startup scripts and current installation before
   replacing anything.

2. Back up the current filter:

     cp -a /etc/news/filter/filter_innd.pl \
       /etc/news/filter/filter_innd.pl.backup-$(date +%Y%m%d-%H%M%S)

3. Create the configuration/state directories:

     install -d -o news -g news -m 0750 /etc/news/cleanfeed
     install -d -o news -g news -m 0750 /var/lib/news/cleanfeed

4. Install the runtime filter:

     install -o news -g news -m 0644 cleanfeed \
       /etc/news/filter/filter_innd.pl

5. Install the exhaustive configuration example as the active local config:

     install -o news -g news -m 0640 cleanfeed.local.example \
       /etc/news/cleanfeed/cleanfeed.local

6. Edit cleanfeed.local. Initially keep peer/hierarchy policies in audit mode
   and keep accepted-article logging disabled.

7. Copy only the external rule files you actually need. Example:

     install -o news -g news -m 0640 samples/bad_subject \
       /etc/news/cleanfeed/bad_subject

   Every supplied rule is commented out, so copying a sample does not activate
   a blacklist accidentally.

8. Compile-check the exact installed filter and config:

     CLEANFEED_CONFIG_DIR=/etc/news/cleanfeed \
       perl -c /etc/news/filter/filter_innd.pl

9. Run the regression suite from the unpacked package:

     prove -v tests

10. Reload the Perl filter:

      ctlinnd reload filter.perl 'cleanfeed-ng configuration reload'

11. Inspect the INN log immediately after reload:

      journalctl -u inn2 -n 200 --no-pager

    or the site-specific news.notice path.

ROLLBACK
--------
Restore the saved filter, compile-check it, and reload filter.perl. Keep the
last known-good cleanfeed.local under version control.

CONFIGURATION MODEL
-------------------
All site changes belong in cleanfeed.local. The file is Perl code and must end
with a true value, normally:

  1;

The supplied cleanfeed.local.example contains every runtime option, the shipped
value, expected type, operational meaning and, where useful, recommended bounds.
It is the canonical parameter reference. Do not maintain a second partial
configuration unless you deliberately accept that new options will be absent.

The local_config subroutine may define:

  %config_local       Replaces built-in values by key.
  %config_append      Appends regex alternatives to supported built-in regexes.
  %Peer_Policies      Rules selected by inferred incoming peer.
  %Hierarchy_Policies Rules selected by destination newsgroup hierarchy.
  %Restricted_Groups  Optional restricted crosspost boundaries.

VALUE RULES
-----------
- Boolean values: 0 or 1.
- Numeric values: non-negative decimal integers unless documented otherwise.
- Intervals: seconds unless explicitly stated otherwise.
- Regex values: Perl regex fragments without surrounding /.../ delimiters.
- File paths: use absolute paths on local storage.
- A value of 0 often disables a threshold or means unlimited; read the inline
  comment for the specific option.

Configuration validation checks booleans, non-negative numbers, policy modes,
rate cutoff/ceiling relationships and regex compilation. Validation should
remain enabled in production.

BINARY FILTERING
----------------
The cleanfeed-ng detector covers:

- yEnc single-part and multipart articles;
- short yEnc payloads and common malformed variants;
- yEnc markers beyond the old 4 KiB preview limit;
- uuencode headers and recognizable headerless multipart blocks;
- MIME application, image, audio, video, model and font entities;
- binary/base64 MIME attachments, including short payloads;
- long runs of raw Base64 lines;
- filename extensions used by binary-policy exceptions.

Important options include:

  block_binaries
      Reject detected binaries unless the complete distribution is permitted.

  block_all_binaries
      Reject detected binaries even in normally binary-allowed groups.

  binaries_in_mod_groups
      Permit binaries when every target group is moderated.

  binary_scan_bytes
      Number of bytes scanned from the start of the body.

  binary_scan_tail_bytes
      Additional bytes scanned from the end, useful for yEnc terminators.

  detect_mime_binaries
      Enable MIME entity/attachment classification.

  detect_malformed_yenc
      Enable conservative recognition of common non-compliant yEnc forms.

No content detector can identify every arbitrarily encrypted or deliberately
obfuscated payload without false positives. Combine content detection with
hierarchy policy, size limits and narrow site signatures.

PEER AND HIERARCHY POLICIES
---------------------------
Policies can operate in four modes:

  off         Do not evaluate/enforce the matched policy.
  audit       Accept, count and log the violation.
  quarantine  Accept and log/count it as logical quarantine. Routing to a
              separate feed/spool must be implemented in INN configuration.
  reject      Reject the article.

Start broad rules in audit mode. Promote to reject only after reviewing real
traffic and confirming peer identity/group matching.

Policy precedence is:

1. global defaults;
2. matching peer expressions, general before specific;
3. matching hierarchy expressions for every target group, general before
   specific.

Use anchored expressions. Peer identity is inferred from Injection-Info,
X-Trace and Path; verify the value recorded in logs before relying on it.

SUPERSEDES
----------
The excessive-Supersedes detector supports off, audit and reject modes with
configurable windows and thresholds for FAQ, moderated, unmoderated and unknown
active-file states.

Cancel-Lock and Cancel-Key are intentionally not implemented here. Their
cryptographic validation remains the responsibility of INN2.

REASON CODES AND AUDIT TAXONOMY
-------------------------------
Each independent anomaly emits a stable rule name and a stable `CF-*` code.
See `docs/REASON-CODES.md` for the complete list. Do not parse the human-readable
reason text in automation; use the rule name or `CF-*` code.

Generic containers such as `malformed.encoding`, `structure.path` and
`anomaly.rate` are no longer emitted by the new checks.

METRICS AND LOGGING
-------------------
The default metrics implementation is deliberately simple and synchronous-path
safe:

- atomic key=value status snapshot;
- append-only cumulative CSV history;
- optional compact syslog line;
- bounded counters by rule, peer and hierarchy;

No HTTP listener or exporter process is embedded in cleanfeed-ng.

Recommended initial values:

  metrics_enabled          => 1
  metrics_status_file      => /var/lib/news/cleanfeed/cleanfeed.status
  metrics_csv_interval     => 300
  metrics_syslog           => 0
  policy_log_accepts       => 0

The news user must be able to create/rename the status file and append to the
CSV. Keep these files on local storage, not an NFS/network filesystem.

EXTERNAL bad_* FILES
--------------------
The samples directory contains every supported external rule file:

  bad_paths
  bad_cancel_paths
  bad_adult_paths
  bad_hosts
  bad_hosts_central
  bad_from
  bad_subject
  bad_body
  bad_url
  bad_url_central

All rules are disabled with #. Read samples/README.txt and the comments inside
each file. Active non-empty lines are Perl regex fragments without /.../.

bad_body, bad_subject and similar direct-reject signatures must be extremely
specific. Broad terms such as product names, currencies, common URL fragments
or encoding markers will reject legitimate discussions and abuse reports.

The *_central files use the same syntax as their local equivalents and are
intended for generated/shared lists. Do not fetch or regenerate them from the
article-processing path.

OPTIONAL BADURLS TOOL
---------------------
The badurls_tool directory contains an offline Python 3 utility that scans
Cleanfeed mbox-style diagnostic logs, accumulates repeated URL/host matches in
SQLite and can generate bad_url_central. It is optional and does not run inside
INN or Cleanfeed.

Before use:

  cd badurls_tool
  edit config.py
  python3 -m py_compile badurl.py config.py
  ./badurl.py

Review every path and threshold in config.py. The supplied exclude_list,
include_list and logfile_list files contain comments/examples only. Generated
central lists should be reviewed before deployment, especially when a broad
regular expression or low threshold is used.

PERFORMANCE AND SAFETY
----------------------
cleanfeed-ng runs synchronously inside innd article acceptance. Therefore:

- never perform DNS, HTTP, SQL or other network requests per article;
- avoid catastrophic-backtracking regular expressions;
- keep accepted-event logging disabled on transit servers;
- use bounded peer/hierarchy counters;
- keep debug article capture disabled during normal operation;
- use atomic local-file writes and reasonable intervals;
- test configuration changes before reload;
- inspect logs after every reload;
- deploy new rejection policy in audit mode first.

TESTS
-----
Run:

  prove -v tests

The suite checks binary detection, configuration-key integrity, validation,
peer/hierarchy policy, metrics output and Supersedes-related configuration.

PACKAGE INTEGRITY
-----------------
Verify the runtime, helper, configuration and sample files covered by the deployment-focused manifest with:

  sha256sum -c MANIFEST-SHA256.txt

Repository metadata, prose documentation, licensing text, central-list project scaffolding and tests are intentionally outside this focused manifest.

2026 LIGHTWEIGHT OPERATIONAL FEATURES
-------------------------------------
This release adds the following low-overhead facilities. All potentially
site-sensitive detectors default to audit mode and can be disabled separately.

External list reload:
- bad_reload_mode selects mtime, articles, or both.
- bad_reload_interval controls inexpensive stat() checks.
- only changed files cause a reload when mtime mode is used.

External regular-expression safety:
- syntax errors preserve the previous last-known-good compiled expression;
- executable Perl regex constructs are rejected;
- configurable length/count limits and simple nested-quantifier checks reduce
  the risk of catastrophic backtracking.

Stable rejection codes:
Every rejection is prefixed with a stable CF-* identifier, for example
CF-BINARY-YENC, CF-POLICY-SIZE, CF-BAD-SUBJECT, or CF-EMP-MD5. The human-readable
reason remains present after the code.

Article structure checks:
- configurable maximum header/body physical line lengths;
- lightweight MIME boundary and Base64 consistency checks;
- yEnc begin/end and declared-size consistency checks;
- raw-byte profile detection for opaque binary bodies without standard markers;
- Path hop, token-length, empty-token, and repeated-token checks.

Trusted lists:
The optional trusted_paths, trusted_hosts, trusted_from, and
trusted_message_ids files provide granular allowlisting. They never create an
unconditional bypass. Separate cleanfeed.local booleans control scoring,
content, binary, crosspost, and size bypass classes. Safe defaults bypass only
scoring/EMP checks.

Diagnostics and fleet consistency:
- the status snapshot includes a SHA-256 configuration fingerprint;
- bounded top reject counters identify peers, posting hosts, and groups;
- bounded rate anomaly counters detect unusual per-peer or per-host bursts;
- optional IDN normalization activates only when Net::IDN::Encode is installed.

Standalone administration tool:
  ./cleanfeed-admin.pl --config-dir /etc/news/cleanfeed --check-config
  ./cleanfeed-admin.pl --config-dir /etc/news/cleanfeed --dump-rules
  ./cleanfeed-admin.pl --config-dir /etc/news/cleanfeed --test-article article.txt

The checker validates Perl syntax and all external regex files. The dump prints
rule counts and SHA-256 hashes, useful for comparing several transit servers.
The article tester checks the lightweight structural signatures without
connecting to INN or modifying the spool. The authoritative result remains the
filter result inside innd because EMP history, peer policy, active-file state,
and local hooks are runtime-specific.

DELIBERATELY NOT IMPLEMENTED
----------------------------
This package does not add antivirus scanning, DNSBL lookups, synchronous DNS or
HTTP, SQL databases, archive decompression, machine learning, GeoIP, a built-in
HTTP metrics server, automatic Internet blacklist updates, physical spool
quarantine, complex traffic shaping, or Cancel-Lock/Cancel-Key validation.
Those facilities would add latency, dependencies, or duplicate native INN2
functionality.


BYTE-PROFILE SCOPE AND SAFE REJECT MODE
---------------------------------------
The byte-profile detector is an intentionally lightweight heuristic. It counts
ASCII control bytes in a bounded body sample and can detect opaque binary data
that lacks conventional yEnc, MIME, Base64 or uuencode markers.

A binary article is not automatically unwanted. Binary payloads are expected in
binary-enabled groups and from peers/hierarchies whose effective policy permits
binary data. For that reason the shipped default is:

  binary_byte_profile_scope => 'policy'
  binary_byte_profile_mode  => 'audit'

With scope "policy", the detector runs only when the fully merged global,
peer, and hierarchy policy has allow_binary => 0. Setting mode to reject then
rejects only a finding that occurs where binary data is prohibited.

The "all" scope is intended only for diagnostics and performance measurement.
Using "all" together with "reject" on a binary transit feed would reject
legitimate binary articles and is therefore strongly discouraged.

MIXED CROSSPOSTS
----------------
An article posted both to a binary-enabled group and a text-only group must be
evaluated according to the effective policy for every destination. Do not use a
configuration that treats the presence of one alt.binaries group as permission
to inject the same payload into unrelated text hierarchies.

STABLE RULES AND CF-* CODES
---------------------------
Every maintained rule family now maps to a stable internal rule and CF-* code.
This includes the historical EMP family, bot signatures, HTML checks, cancel
policy, control-message validation, distribution rules, crosspost limits,
repost checks, header deny lists, and the newer structural heuristics.

The free-form reason text may improve between releases. Monitoring and log
analysis should therefore key on rule=... or the CF-* code, not exact English
sentences.

EXTERNAL REGEX EXAMPLES
-----------------------
All sample files contain disabled examples and explanations. A longer tutorial
is provided in docs/REGEX-COOKBOOK.md. In particular:

  * escape dots in hostnames and newsgroups;
  * anchor exact values with ^ and $;
  * use (?:^|!) and (?:!|$) for complete Path tokens;
  * avoid broad .*, .+, common words, and public provider domains;
  * never use executable Perl regex constructs;
  * test intended matches and legitimate non-matches;
  * keep behavioural changes in audit until real traffic proves them safe.

PERFORMANCE AND REPORTING
-------------------------
The filter runs synchronously inside INN. Body scans are bounded and cached,
and disabled checks are designed to add no body-scan cost. The HTML report is
written only at the normal statistics interval and now includes detailed rule,
peer, hierarchy and history information. Prometheus output is intentionally not
part of cleanfeed-ng; use CSV, key=value status, syslog or HTML.

Optional offline tools are in tools/: cleanfeed-audit-analyzer.py summarizes
audit/reject logs, while cleanfeed-benchmark.pl compares selected scanning
primitives. Neither tool is loaded by INN.

EXTERNAL BODY RULE COMPATIBILITY
--------------------------------

bad_body, bad_url and bad_url_central inspect a bounded, cached and normalized
text window.  The window is lowercased and top-level text/* Base64 is decoded
before matching.  This preserves historical Cleanfeed rule semantics while
preventing unbounded scans of large articles.
