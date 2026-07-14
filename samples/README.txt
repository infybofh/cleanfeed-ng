CLEANFEED EXTERNAL RULE FILES - EXAMPLES AND FORMAT
===================================================

This directory contains safe example files for Cleanfeed external rules.
All example rules are commented out. Copy only the files you intend to use to
the Cleanfeed configuration directory and uncomment rules after testing them.

IMPORTANT SAFETY RULES
----------------------

1. Every non-empty, non-comment line is normally treated as a Perl regular
   expression. A broad or malformed expression can reject legitimate traffic.
2. Lines beginning with # are comments and are ignored.
3. Do not add surrounding /.../ delimiters.
4. Escape literal dots as \.
5. Prefer anchors (^ and $) whenever the value should match a complete host,
   group, address, or subject.
6. Test every changed file with the filter in audit mode where possible.
7. Reload the Perl filter and inspect news.notice after a change.
8. Keep site-specific rules under version control.

FILES
-----

bad_adult_paths
    Path or injection-host expressions considered unacceptable for articles
    posted to adult groups.

bad_body
    Body expressions that cause unconditional rejection. This is the most
    dangerous external rule file; use narrowly scoped expressions.

bad_cancel_paths
    Path expressions from which user-generated cancel messages are rejected.
    INN2 remains responsible for Cancel-Lock/Cancel-Key verification.

bad_from
    Expressions matched against From, Reply-To, and related identity fields.

bad_hosts
    Local posting-host or injection-host expressions considered abusive.

bad_hosts_central
    Same syntax as bad_hosts, intended for a centrally generated/shared list.

bad_paths
    Expressions matched against the Path header.

bad_subject
    Subject expressions that cause unconditional rejection.

bad_url
    Local URL/domain expressions used by the scoring filter. These entries
    affect score rather than necessarily causing immediate rejection.

bad_url_central
    Same syntax as bad_url, intended for a centrally generated/shared list.

The comments inside each file contain syntax examples and operational notes.

TRUSTED LISTS
-------------
trusted_paths, trusted_hosts, trusted_from, and trusted_message_ids are optional
allowlists. A match does not bypass every filter. cleanfeed.local controls the
individual bypass classes (scoring, content, binary, crosspost, and size).
The safe defaults only bypass scoring/EMP checks. Binary, size, and crosspost
checks remain active unless explicitly changed.


REGEX QUICK CHECKLIST
---------------------
Before enabling any line:

1. Escape literal dots in hostnames and newsgroups (example\\.net).
2. Anchor exact strings with ^ and $.
3. For Path tokens, use (?:^|!) and (?:!|$).
4. Prefer bounded repetitions such as [0-9]{6} over .+ or .*.
5. Test at least one intended match and several legitimate non-matches.
6. Run cleanfeed-admin.pl --check-config after editing.
7. Deploy behavioural changes in audit mode before reject mode.

See docs/REGEX-COOKBOOK.md for a longer tutorial and copyable examples.
