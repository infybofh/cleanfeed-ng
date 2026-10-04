# Perl regular-expression cookbook for cleanfeed-ng

cleanfeed-ng list files contain **one Perl regular expression per active line**.
Do not wrap expressions in `/.../`. Empty lines and lines beginning with `#`
are ignored.

## Exact values

```text
^reader1\.example\.net$
```

`^` anchors the beginning, `$` anchors the end, and `\.` means a literal dot.
Without anchors, the expression may match a substring of an unrelated value.

## Alternatives

```text
^(?:reader1|reader2|reader7)\.example\.net$
```

`(?:...)` groups alternatives without creating a capture. Use `|` for "or".

## Numbered hosts

```text
^reader[0-9]+\.example\.net$
```

This matches reader1 and reader123, but not reader.example.net. To permit only
one through three digits, use `[0-9]{1,3}`.

## Path-token boundaries

```text
(?:^|!)feed\.example\.net(?:!|$)
```

Path tokens are separated by `!`. These boundaries prevent a match inside a
longer hostname.

## Optional text

```text
^Campaign(?: update)? ID-[0-9]{6}$
```

The `?` applies to the preceding group, making ` update` optional.

## Literal metacharacters

Escape characters that have regex meaning when you need the literal character:

```text
\.  \+  \[  \]  \(  \)  \?  \*
```

## Expressions to avoid

Avoid unbounded catch-all patterns such as `.*spam.*`, nested quantifiers such
as `(a+)+`, executable Perl regex constructs such as `(?{ ... })`, and broad
public domains. They are slow, unsafe, or prone to false positives.

## Testing

Use the administration tool before installation:

```sh
./cleanfeed-admin.pl --config-dir /etc/news/cleanfeed --check-config
```

Then deploy the relevant policy in audit mode and inspect real traffic before
changing it to reject.


## Appending to shipped expressions from cleanfeed.local

Use `%config_append` when adding a local exception without replacing the shipped
expression. Example PHN exclusions using real group-name syntax:

```perl
$config_append{phn_exclude} =
    '|^fr\.soc\.politique$|^de\.soc\.politik\.misc$';
```

The leading `|` is intentional because the value is appended to an existing
alternation. These groups are examples of exact anchoring only; they are not a
recommended default exclusion list.

## Debugging an unexpected rule

Start with the `rule=` or `CF-*` value from `cleanfeed_event`, look it up in
`docs/REASON-CODES.md`, then inspect the named source function. This is faster
and more reliable than grepping the human-readable reason string, which may be
clarified without changing the stable rule/code.
