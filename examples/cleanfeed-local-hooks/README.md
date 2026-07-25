# Cleanfeed-NG local hook examples

This directory is a companion for newsmasters running Postfilter-NG together
with Cleanfeed-NG.  Postfilter-NG does not load this file.  Copy reviewed
functions into the `cleanfeed.local` used by Cleanfeed-NG.

The examples are deliberately complete: each rule contains its matching
conditions, saved-article bucket and rejection text.  They include adapted
historical checks from Steve Crook's public `cleanfeed.local` sample plus newer
composite examples.  The historical checks can be useful when auditing an
archive containing articles from the 1990s onward, but they must not be enabled
blindly on a live feed.

Source of the historical examples:

- <https://github.com/crooks/cleanfeed/blob/master/samples/cleanfeed.local>

## Safe rollout

1. Leave `$CFNG_LOCAL_AUDIT_ONLY = 1`.
2. Enable only the named rule families you want to inspect.
3. Review the files written by `saveart()`.
4. Narrow patterns for the archive or hierarchy being processed.
5. Set `$CFNG_LOCAL_AUDIT_ONLY = 0` only for rules whose saved samples are
   consistently unwanted.

The file uses Cleanfeed's established local-hook globals and helpers:
`%hdr`, `@groups`, `@followups`, `$localfeed`, `saveart()` and `reject()`.
It does not modify Postfilter-NG policy.

## Included examples

- forged local `Approved` headers outside permitted hierarchies;
- historical AspNNTP spam-client signatures;
- historical Google Groups wholesale-goods subjects;
- historical MI5 crosspost floods;
- suspicious multi-group job/recruitment posts carrying several external URLs;
- save-only tracking for resurrector reposts and selected rejection classes.

The default is audit-only.  A match is saved and allowed until the operator
changes the audit switch.
