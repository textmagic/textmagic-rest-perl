use strict;
use warnings;
use Test::More;

require_ok( 'Net::SMS::TextmagicRest' );
use_ok( 'Net::SMS::TextmagicRest' );

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';
my $baseUrl = 'http://example.com';

my $obj = Net::SMS::TextmagicRest->new(user => $username, token => $token, baseUrl => $baseUrl);

ok($obj, "Object created with constructor should not be null");

cmp_ok($ojb->getUser(), 'eq', $username, "getUser() reflects param passed in constructor");
cmp_ok($ojb->getToken(), 'eq', $token, "getToken() reflects param passed in constructor");
cmp_ok($ojb->getBaseUrl(), 'eq', $baseUrl, "getBaseUrl() reflects param passed in constructor");

# Test no username

my $fail = Net::SMS::TextmagicRest->new(token => $token);

ok (not $fail, "Shouldn't create an object without a username");

$fail = Net::SMS::TextmagicRest->new(user => $username);

ok(not $fail, "Shouldn't create an object without a token");
