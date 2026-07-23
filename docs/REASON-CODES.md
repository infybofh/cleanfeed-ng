# Stable rule and rejection codes

Automation should use the rule name or `CF-*` code, not the explanatory text. Heuristic checks default to audit; deterministic checks can be configured for rejection.

| Rule | Code | Meaning |
|---|---|---|
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
| `path.empty_token` | `CF-PATH-EMPTY-TOKEN` | Empty Path component. |
| `path.token_length` | `CF-PATH-TOKEN-LENGTH` | Path component is too long. |
| `path.repeated_token` | `CF-PATH-REPEATED-TOKEN` | One Path component repeats too often. |
| `anomaly.peer_rate` | `CF-PEER-RATE-ANOMALY` | Peer exceeds the audit rate threshold. |
| `anomaly.host_rate` | `CF-HOST-RATE-ANOMALY` | Posting host exceeds the audit rate threshold. |

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
| `emp.phn` | `CF-EMP-PHN` | Posting-host or Path/newsgroups EMP threshold exceeded. |
| `emp.phr` | `CF-EMP-PHR` | High-risk-group EMP threshold exceeded. |
| `emp.fsl` | `CF-EMP-FSL` | From/Subject/Lines EMP threshold exceeded. |

Other existing binary, policy, content and scoring rules retain their stable codes defined in `cleanfeed`.

## yEnc multipart semantics

For multipart yEnc, `=ybegin size` is the complete original file size. It is **not** compared with `=yend size`, which represents the current part. cleanfeed-ng compares multipart `=yend size` with `=ypart end - begin + 1`. For single-part yEnc only, `=ybegin size` and `=yend size` are directly comparable.


## Byte-profile enforcement scope

`binary.byte_profile` is a signal, not a universal prohibition. With the
recommended `binary_byte_profile_scope = policy`, it is evaluated only when the
effective policy has `allow_binary = 0`. The `all` scope is intentionally noisy
and should normally be used only with audit mode.
