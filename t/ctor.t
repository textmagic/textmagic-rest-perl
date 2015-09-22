use strict;
use warnings;
use Test::More tests => 8;

BEGIN { use_ok( 'Net::SMS::TextmagicRest' ); }

require_ok( 'Net::SMS::TextmagicRest' );

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';
my $baseUrl = 'http://example.com';

my $obj = Net::SMS::TextmagicRest->new(username => $username, token => $token, baseUrl => $baseUrl);

ok($obj, "Object created with constructor should not be null");

cmp_ok($obj->getUsername(), 'eq', $username, "getUser() reflects param passed in constructor");
cmp_ok($obj->getToken(), 'eq', $token, "getToken() reflects param passed in constructor");
cmp_ok($obj->getBaseUrl(), 'eq', $baseUrl, "getBaseUrl() reflects param passed in constructor");

# Test no username

eval {
    my $fail = Net::SMS::TextmagicRest->new(token => $token);
};
like($@, qr/No username or token supplied/);

eval { 
    my $fail = Net::SMS::TextmagicRest->new(user => $username);
};
like ($@, qr/No username or token supplied/);
