use strict;
use warnings;
use Test::More tests => 10;

use Net::SMS::TextmagicRest;

my @accessors = qw(BaseUrl Username Token UserAgent Client);

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';
my $baseUrl = 'http://example.com';

my $tm = Net::SMS::TextmagicRest->new(username => $username, token => $token, baseUrl => $baseUrl);

for my $accessor (@accessors) {
    my $getter = "get$accessor";
    my $setter = "set$accessor";

    my $val = $tm->$getter();
    ok($val, "value from $getter should initially be non-falsy (actually $val)");

    my $test_string = "test string";
    $tm->$setter($test_string);
    $val = $tm->$getter();

    cmp_ok($val, 'eq', $test_string, "value should be round-tripped successfully through accessor");
}
