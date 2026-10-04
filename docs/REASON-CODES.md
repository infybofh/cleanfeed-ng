# Stable rule and rejection codes

Automation should use the rule name or `CF-*` code, not the explanatory text. Heuristic checks default to audit; deterministic checks can be configured for rejection.

## Where these codes are used in the source

This file is also the code-navigation index requested by reviewers.  The
authoritative rule-to-code mapping lives in `cleanfeed` inside
`reject_code()`.  When tracing a specific event, search the stable `rule=` name
first; human-readable text is intentionally allowed to improve without becoming
an API.

| Rule family | Primary source area | How it reaches a decision/log |
|---|---|---|
| `mime.*`, `yenc.*` | `encoding_findings()` | `apply_lightweight_guards()` -> `apply_finding_set()` -> `mode_result()` |
| `binary.byte_profile` | `byte_profile_findings()` | same lightweight finding path |
| `path.*` | `path_sanity_components()`, `path_sanity_findings()` | same lightweight finding path |
| `anomaly.*` | `rate_anomaly_findings()` | same lightweight finding path |
| `policy.binary`, `policy.size` | `policy_for_article()`, `apply_policy_engine()` | `mode_result()` |
| `emp.phn` | `populate_posting_identity_state()`, `phn_identity_for_article()`, `apply_phn_filter()` | direct reject or structured weak audit |
| `emp.md5`, `emp.phl`, `emp.phr`, `emp.fsl` | main `filter_art()` EMP section and `Cleanfeed::RateLimit` | legacy `reject()` path |
| `crosspost`, `crosspost.*`, `distribution.*`, `group.poison` | group-classification/crosspost section in `filter_art()` | legacy `reject()` path; Followup-specific arithmetic uses `followup_policy_counts()` |
| `header.*`, `site.*`, `bot.signature`, `html.*`, `cancel.*`, `control.*`, `repost.*`, `approval.*`, `tos.violation` | corresponding deterministic sections in `filter_art()` | legacy `reject()` path |
| `scoring` | scoring section in `filter_art()` | legacy `reject()` path |

Useful searches from the repository root:

```sh
grep -n "sub reject_code" cleanfeed
grep -n "rule-name-here" cleanfeed
grep -n "reject(" cleanfeed
grep -n "mode_result\|apply_finding_set" cleanfeed
```

`reject()` converts legacy human reasons to stable rules through
`policy_reason_key()` when a caller does not pass a rule explicitly; new code
should prefer an explicit stable rule whenever practical.  Structured events are
emitted by `policy_log_event()`.

| Rule | Code | Meaning |
|---|---|---|
| `binary.yenc` | `CF-BINARY-YENC` | yEnc payload detected where binary content is not permitted. |
| `binary.uuencode` | `CF-BINARY-UUENCODE` | uuencoded payload detected where binary content is not permitted. |
| `binary.base64` | `CF-BINARY-BASE64` | Base64 binary payload detected where binary content is not permitted. |
| `binary.mime` | `CF-BINARY-MIME` | MIME binary payload detected where binary content is not permitted. |
| `policy.binary` | `CF-POLICY-BINARY` | Effective peer/hierarchy policy forbids binary payload. |
| `policy.size` | `CF-POLICY-SIZE` | Effective peer/hierarchy policy size limit was exceeded. |
| `crosspost` | `CF-CROSSPOST` | Historical/general crosspost limit matched. |
| `mime.multipart.boundary_missing` | `CF-MIME-BOUNDARY-MISSING` | Multipart Content-Type has no boundary parameter. |
| `mime.multipart.boundary_not_found` | `CF-MIME-BOUNDARY-NOT-FOUND` | Declared boundary was not found in the bounded scan window. |
| `mime.base64.payload_missing` | `CF-BASE64-PAYLOAD-MISSING` | Base64 was declared but no plausible payload was found. |
| `yenc.structure.missing_end` | `CF-YENC-MISSING-END` | `=ybegin` without `=yend`. |
| `yenc.structure.missing_begin` | `CF-YENC-MISSING-BEGIN` | `=yend` without `=ybegin`. |
| `yenc.structure.orphan_part` | `CF-YENC-ORPHAN-PART` | `=ypart` without `=ybegin`. |
| `yenc.structure.part_missing` | `CF-YENC-PART-MISSING` | Multipart `=ybegin part=` without `=ypart`. |
| `yenc.structure.invalid_range` | `CF-YENC-INVALID-RANGE` | Invalid or missing `=ypart begin/end`. |
| `yenc.structure.invalid_part_number` | `CF-YENC-INVALID-PART-NUMBER` | Invalid `part` or `part > total`. |
| `yenc.metadata.single_size` | `CF-YENC-SINGLE-SIZE` | Comparable single-part begin/end sizes differ beyond tolerance. |
| `yenc.metadata.part_size` | `CF-YENC-PART-SIZE` | Multipart `=yend size` differs from the `=ypart` range beyond tolerance. |
| `binary.image` | `CF-BINARY-IMAGE` | Image payload is misplaced outside an allowed binary/image distribution. |
| `binary.byte_profile` | `CF-BINARY-BYTE-PROFILE` | Bounded sample has an unusually high non-printable-byte ratio. |
| `structure.header_line` | `CF-HEADER-LINE-LONG` | Header line exceeds the configured limit. |
| `structure.body_line` | `CF-BODY-LINE-LONG` | Body line exceeds the configured limit. |
| `path.hop_count` | `CF-PATH-HOP-COUNT` | Too many Path hops. |
| `path.empty_token` | `CF-PATH-EMPTY-TOKEN` | Malformed empty Path component; RFC 5536/5537 `!!` diag-match syntax is valid and is not reported. |
| `path.token_length` | `CF-PATH-TOKEN-LENGTH` | Path component is too long. |
| `path.repeated_token` | `CF-PATH-REPEATED-TOKEN` | One Path component repeats too often. |
| `anomaly.peer_rate` | `CF-PEER-RATE-ANOMALY` | Peer exceeds the audit rate threshold. |
| `anomaly.host_rate` | `CF-HOST-RATE-ANOMALY` | Posting host exceeds the audit rate threshold. |
| `header.subject` | `CF-BAD-SUBJECT` | Subject matched configured/historical rejection logic. |
| `header.from` | `CF-BAD-FROM` | From matched configured/historical rejection logic. |
| `body.pattern` | `CF-BAD-BODY` | Body matched a configured bad-body expression. |
| `body.url` | `CF-BAD-URL` | URL/domain scoring or rejection logic identified a bad URL. |
| `supersedes` | `CF-SUPERSEDES` | Excessive Supersedes rate/threshold logic matched. |
| `control` | `CF-CONTROL` | Generic historical control-message rejection. |
| `scoring` | `CF-SCORING` | Historical scoring threshold rejected the article. |
| `message_id` | `CF-MESSAGE-ID` | Message-ID history/check logic rejected the article. |
| `header.invalid` | `CF-HEADER-INVALID` | Malformed or invalid mandatory header. |
| `site.path` | `CF-BAD-PATH` | Path matched a configured bad-site/path rule. |
| `site.host` | `CF-BAD-HOST` | Posting/injection host matched a deny rule. |
| `header.reply_to` | `CF-BAD-REPLY-TO` | Reply-To matched a deny rule. |
| `header.sender` | `CF-BAD-SENDER` | Sender matched a deny rule. |
| `bot.signature` | `CF-BOT-SIGNATURE` | Historical bot/software signature matched. |
| `html.attachment` | `CF-HTML-ATTACHMENT` | HTML attachment forbidden by policy. |
| `html.multipart_plain_missing` | `CF-HTML-MULTIPART-NO-PLAIN` | HTML multipart lacks a text/plain alternative. |
| `html.multipart` | `CF-HTML-MULTIPART` | Multipart HTML forbidden by policy. |
| `html.image` | `CF-HTML-IMAGE` | HTML image tag forbidden by policy. |
| `html.article` | `CF-HTML-ARTICLE` | HTML article forbidden by policy. |
| `cancel.rogue` | `CF-CANCEL-ROGUE` | Cancel violated configured path/group/header policy. |
| `cancel.user` | `CF-CANCEL-USER` | User-issued cancel forbidden by policy. |
| `cancel.user_spam` | `CF-CANCEL-USER-SPAM` | User-issued spam cancel forbidden by policy. |
| `cancel.rejected_target` | `CF-CANCEL-REJECTED-TARGET` | Cancel targets an already rejected article. |
| `supersedes.rogue` | `CF-SUPERSEDES-ROGUE` | Supersedes violated configured path policy. |
| `repost.message_id` | `CF-REPOST-MESSAGE-ID` | Redundant repost detected by Message-ID history. |
| `repost.cache` | `CF-REPOST-CACHE` | Redundant repost detected by repost cache. |
| `approval.forged` | `CF-APPROVAL-FORGED` | Approval header failed configured trust rules. |
| `control.big8_source` | `CF-CONTROL-BIG8-SOURCE` | Big-8 control came from an unauthorized source. |
| `control.unapproved` | `CF-CONTROL-UNAPPROVED` | Control message lacked required approval. |
| `control.poison_group` | `CF-CONTROL-POISON-GROUP` | Newgroup targeted a configured poison group. |
| `control.obsolete` | `CF-CONTROL-OBSOLETE` | Obsolete control command rejected. |
| `control.invalid` | `CF-CONTROL-INVALID` | Invalid/unwanted control-message form. |
| `distribution.invalid` | `CF-DISTRIBUTION-INVALID` | Distribution violates site/U2 policy. |
| `distribution.hierarchy` | `CF-DISTRIBUTION-HIERARCHY` | Crosspost escaped an allowed hierarchy. |
| `crosspost.test` | `CF-CROSSPOST-TEST` | Test article crossed too many test groups. |
| `crosspost.topic` | `CF-CROSSPOST-TOPIC` | Topic crosspost policy failed. |
| `group.poison` | `CF-GROUP-POISON` | Article/control targets a poison group. |
| `tos.violation` | `CF-TOS-VIOLATION` | Site-defined Terms-of-Service rule matched. |
| `emp.md5` | `CF-EMP-MD5` | Duplicate-body EMP threshold exceeded. |
| `emp.phl` | `CF-EMP-PHL` | Posting-host/line-count EMP threshold exceeded. |
| `emp.phn` | `CF-EMP-PHN` | Posting identity/newsgroups PHN threshold exceeded; weak shared-injector matches audit by default. |
| `emp.phr` | `CF-EMP-PHR` | High-risk-group EMP threshold exceeded. |
| `emp.fsl` | `CF-EMP-FSL` | From/Subject/Lines EMP threshold exceeded. |
| `other` | `CF-OTHER` | Fallback category for a legacy rejection that has no more specific mapping. |

The table mirrors the explicit mappings in `reject_code()`. Unknown future rule
names are converted deterministically to `CF-<UPPERCASED-RULE>` form; new
public rules should still be added here when introduced.

## yEnc multipart semantics

For multipart yEnc, `=ybegin size` is the complete original file size. It is **not** compared with `=yend size`, which represents the current part. cleanfeed-ng compares multipart `=yend size` with `=ypart end - begin + 1`. For single-part yEnc only, `=ybegin size` and `=yend size` are directly comparable.


## Byte-profile enforcement scope

`binary.byte_profile` is a signal, not a universal prohibition. With the
recommended `binary_byte_profile_scope = policy`, it is evaluated only when the
effective policy has `allow_binary = 0`. The `all` scope is intentionally noisy
and should normally be used only with audit mode.


## Newsgroups and Followup-To count semantics

Historical Cleanfeed deliberately distinguishes three sets:

- `grpcnt`: number of targets in `Newsgroups`;
- `fupcnt`: number of **effective followup targets** — explicit `Followup-To`,
  otherwise a copy of `Newsgroups`;
- `grpfupcnt`: unique union of Newsgroups and effective followup targets.

`maxgroups` and several historical crosspost checks intentionally use `fupcnt`;
this permits, for example, a widely distributed FAQ whose `Followup-To` directs
discussion to one group.  In 2026.10.1, meow/topic subtraction was corrected so
values subtracted from `fupcnt` are counted by `followup_policy_counts()` from
the same effective followup set.  Union counters remain appropriate for rules
that ask whether a group class appears anywhere in the article's distribution
or followup routing.

## PHN structured-event fields

Since `2026.07.3-rc3`, `emp.phn` events add:

- `identity_source`: `posting_account`, `injection_posting_host`, `nntp_posting_host`, `path_posted_source`, or `shared_injector`;
- `identity_strength`: `strong` or `weak`;
- `identity_hash`: a raw-value-free correlation prefix, not the raw identity;
- `count` and `cutoff`: the current PHN counter and configured rejection threshold.

A weak `shared_injector` event is an audit under the shipped defaults. `phn_aggressive => 1` restores legacy rejection and should be used only when the injector is known to represent one posting source.
