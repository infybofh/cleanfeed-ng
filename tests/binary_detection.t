#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

BEGIN {
    $ENV{CLEANFEED_CONFIG_DIR} = '';
    package INN;
    sub syslog { return 1 }
    sub newsgroup { return '' }
    sub addhist { return 1 }
    sub cancel { return 1 }
    sub filesfor { return '' }
    sub head { return '' }
}

package main;
our (%hdr, %state, %config);
our $body;

do "$FindBin::Bin/../cleanfeed" or die "Cannot load cleanfeed: $@ $!";

sub classify {
    my (%a) = @_;
    %hdr = (
        Newsgroups => ($a{groups} || 'comp.test'),
        'Content-Type' => ($a{content_type} || ''),
        'Content-Disposition' => ($a{content_disposition} || ''),
        'Content-Transfer-Encoding' => ($a{cte} || ''),
        __BODY__ => ($a{body} || ''),
    );
    %state = (lines => (($hdr{__BODY__} =~ tr/\n//)));
    undef $body;
    return is_binary();
}

ok(classify(body => "=ybegin line=128 size=3 name=a.rar\nabc\n=yend size=3 crc32=00000000\n"),
   'short single-part yEnc detected');
ok(classify(body => "intro\n=ybegin part=1 line=128 size=100 name=a.bin\n=ypart begin=1 end=3\nabc\n=yend size=3 part=1 pcrc32=0\n"),
   'multipart yEnc detected');
ok(classify(body => ("ordinary text\n" x 500) . "=ybegin line=128 size=3 name=late.bin\nabc\n=yend size=3\n"),
   'yEnc marker beyond old 4 kB preview detected');
like(classify(content_type => 'application/octet-stream; name="x.zip"', cte => 'base64', body => "QUJDRA==\n"),
     qr/^MIME binary/, 'short top-level MIME binary detected');
like(classify(content_type => 'multipart/mixed; boundary=x', body => "--x\nContent-Type: application/zip; name=\"x.zip\"\nContent-Transfer-Encoding: base64\n\nQUJDRA==\n--x--\n"),
     qr/^MIME binary part/, 'short multipart MIME binary detected');
is(classify(content_type => 'text/plain', cte => 'base64', body => "SGVsbG8=\n"), 0,
   'base64 text/plain is not classified as binary');
is(classify(body => "This article discusses the literal marker =ybegin in prose.\n"), 0,
   'mere inline mention of ybegin is not a binary');
is(classify(body => "=ybegin is discussed here without attributes or terminator\n"), 0,
   'standalone discussion marker without evidence is not a binary');
ok(classify(body => "begin 644 payload.exe\n" . ("M" . ("A" x 60) . "\n") x 4),
   'uuencode detected');

# Detached signatures (RFC 1847 multipart/signed, RFC 3156 PGP/MIME,
# RFC 8551 S/MIME) are not payloads.  The signature is always the part whose
# Content-Type equals the multipart/signed "protocol" parameter.
my $pgp_sig = "-----BEGIN PGP SIGNATURE-----\n\niHUEARYKAB0WIQQx\n=AbCd\n-----END PGP SIGNATURE-----\n";
my $smime_sig = ("MIIGQAYJKoZIhvcNAQcCoIIGMTCCBi0CAQExDzANBglghkgBZQMEAgEFADALBgkq\n" x 40);

is(classify(content_type => 'multipart/signed; micalg=pgp-sha512; protocol="application/pgp-signature"; boundary="nextPart1"',
            body => "--nextPart1\nContent-Type: text/plain; charset=\"utf-8\"\n\nSigned mailing-list text.\n"
                  . "--nextPart1\nContent-Type: application/pgp-signature; name=\"signature.asc\"\n"
                  . "Content-Description: This is a digitally signed message part.\n"
                  . "Content-Disposition: attachment; filename=\"signature.asc\"\n\n$pgp_sig--nextPart1--\n"),
   0, 'PGP/MIME signed text is not a binary');

is(classify(content_type => 'multipart/signed; protocol="application/pgp-signature"; micalg=pgp-sha256; boundary="------------sig2"',
            body => "This is an OpenPGP/MIME signed message (RFC 4880 and 3156)\n"
                  . "--------------sig2\nContent-Type: multipart/mixed; boundary=\"------------inner\"\n\n"
                  . "--------------inner\nContent-Type: text/plain; charset=UTF-8\n\nHello.\n--------------inner--\n\n"
                  . "--------------sig2\nContent-Description: OpenPGP digital signature\n"
                  . "Content-Type: application/pgp-signature; name=\"OpenPGP_signature.asc\"\n"
                  . "Content-Disposition: attachment; filename=\"OpenPGP_signature.asc\"\n\n$pgp_sig\n--------------sig2--\n"),
   0, 'PGP/MIME signature with Content-Description before Content-Type is not a binary');

is(classify(content_type => 'multipart/signed; protocol="application/pkcs7-signature"; micalg=sha-256; boundary="smime"',
            body => "--smime\nContent-Type: text/plain; charset=us-ascii\n\nS/MIME signed text.\n"
                  . "--smime\nContent-Type: application/pkcs7-signature; name=\"smime.p7s\"\n"
                  . "Content-Transfer-Encoding: base64\n"
                  . "Content-Disposition: attachment; filename=\"smime.p7s\"\n\n$smime_sig\n--smime--\n"),
   0, 'S/MIME signed text is not a binary');

is(classify(content_type => 'multipart/signed; protocol="application/x-pkcs7-signature"; micalg=sha1; boundary=old',
            body => "--old\nContent-Type: text/plain\n\nLegacy S/MIME.\n"
                  . "--old\nContent-Type: application/x-pkcs7-signature; name=smime.p7s\n"
                  . "Content-Transfer-Encoding: base64\n"
                  . "Content-Disposition: attachment; filename=smime.p7s\n\n$smime_sig\n--old--\n"),
   0, 'legacy x-pkcs7 S/MIME signed text is not a binary');

# Real-world KMail article from a mailing-list gateway: folded Content-Type
# header with the protocol on the continuation line, CRLF line endings.
(my $crlf_sig = $pgp_sig) =~ s/\n/\r\n/g;
is(classify(content_type => "multipart/signed; boundary=\"nextPart3136248.hHqAuc6tWs\";\r\n micalg=\"pgp-sha384\"; protocol=\"application/pgp-signature\"",
            groups => 'muc.lists.freebsd.hackers',
            body => "--nextPart3136248.hHqAuc6tWs\r\nContent-Type: text/plain; charset=\"utf-8\"; protected-headers=\"v1\"\r\n"
                  . "Content-Transfer-Encoding: 7Bit\r\n\r\nReply text.\r\n\r\n"
                  . "--nextPart3136248.hHqAuc6tWs\r\nContent-Type: application/pgp-signature; name=\"signature.asc\"\r\n"
                  . "Content-Description: This is a digitally signed message part.\r\n"
                  . "Content-Transfer-Encoding: 7Bit\r\n\r\n$crlf_sig\r\n--nextPart3136248.hHqAuc6tWs--\r\n"),
   0, 'KMail PGP/MIME with folded Content-Type and CRLF is not a binary');

like(classify(content_type => 'multipart/signed; protocol="application/pgp-signature"; boundary="s"',
              body => "--s\nContent-Type: multipart/mixed; boundary=\"m\"\n\n"
                    . "--m\nContent-Type: text/plain\n\nsee attachment\n"
                    . "--m\nContent-Type: application/zip; name=\"x.zip\"\nContent-Transfer-Encoding: base64\n\nQUJDRA==\n--m--\n\n"
                    . "--s\nContent-Type: application/pgp-signature\n\n$pgp_sig--s--\n"),
     qr/^MIME binary part \(application\/zip\)/, 'binary attachment inside signed content is still detected');

like(classify(content_type => 'multipart/mixed; boundary="x"',
              body => "--x\nContent-Type: text/plain\n\nhi\n"
                    . "--x\nContent-Type: application/pgp-signature; name=\"x.asc\"\nContent-Transfer-Encoding: base64\n\nQUJDRA==\n--x--\n"),
     qr/^MIME binary part/, 'pgp-signature label outside multipart/signed is not exempt');

like(classify(content_type => 'multipart/signed; protocol="application/pgp-signature"; boundary="s"',
              body => "--s\nContent-Type: text/plain\n\ntext\n"
                    . "--s\nContent-Type: application/octet-stream; name=\"x.bin\"\nContent-Transfer-Encoding: base64\n\nQUJDRA==\n--s--\n"),
     qr/^MIME binary part \(application\/octet-stream\)/, 'second part not matching the protocol is not exempt');

like(classify(content_type => 'multipart/signed; protocol="application/pgp-signature"; boundary="s"',
              body => "--s\nContent-Type: application/pgp-signature; name=\"x.zip\"\nContent-Transfer-Encoding: base64\n\nQUJDRA==\n"
                    . "--s\nContent-Type: application/pgp-signature\n\n$pgp_sig--s--\n"),
     qr/^MIME binary part \(application\/pgp-signature\)/, 'only the second (signature) part is exempt');

ok(classify(content_type => 'multipart/signed; protocol="application/pgp-signature"; boundary="s"',
            body => "--s\nContent-Type: text/plain\n\ntext\n"
                  . "--s\nContent-Type: application/pgp-signature\nContent-Transfer-Encoding: base64\n\n"
                  . (("QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVphYmNkZWZnaGlqa2xtbm9wcXJzdHV2d3h5ejAx\n") x 400)
                  . "--s--\n"),
   'large base64 payload disguised as a signature is still caught by the base64 line check');

done_testing();
