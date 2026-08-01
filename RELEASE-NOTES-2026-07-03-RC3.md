# cleanfeed-ng 2026.07.3-rc3 release notes

RC3 corrects a PHN false-positive class found in real transit traffic. A public
injector can serve many unrelated users; the old aggressive fallback counted
only injector plus Newsgroups and could therefore reject a quiet user after
other users filled the shared counter.

## PHN behaviour

The detector now uses the first available per-poster identity:

1. `Injection-Info` `posting-account`;
2. `Injection-Info` `posting-host`;
3. `NNTP-Posting-Host`;
4. Path `.POSTED.<source>`.

Strong identities keep the existing PHN cutoff, ceiling, and decay behaviour.
When none is available, the shared-injector fallback audits by default.

```perl
phn_aggressive => 0,
phn_weak_identity_mode => 1,
```

`phn_aggressive => 1` remains supported for compatibility and restores legacy
weak-identity rejection, with a startup warning. `phn_weak_identity_mode => 0`
disables the weak fallback completely when aggressive mode is off.

## Logging

Structured events preserve the real Message-ID and complete group list. PHN
events add identity source/strength, a truncated correlation hash that omits the raw identity, count,
and cutoff. Raw posting accounts and posting hosts are not added to the event.

## Upgrade

Review any local `phn_aggressive` override. Existing installations that set it
to `1` explicitly retain the old reject behaviour. Administrators should prefer
the RC3 defaults, inspect weak audit events, and add only narrow, evidence-based
`phn_exclude` exceptions.  For example, site-local exceptions may be appended
without replacing the shipped expression:

```perl
$config_append{phn_exclude} =
    '|^fr\.soc\.politique$|^de\.soc\.politik\.misc$';
```

These are real group names used only to demonstrate exact anchoring; they are
not enabled or recommended as default policy.
