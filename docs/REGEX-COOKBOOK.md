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
