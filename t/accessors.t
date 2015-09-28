use strict;
use warnings;
use Test::More tests => 10;

use Net::SMS::TextmagicRest;

my @accessors = qw(BaseUrl Username Token UserAgent Client);

my $tm = Net::SMS::TextmagicRest->new(username => "testuser", token => "testtoken");

#
# Ensure that accessors exist and do what we expect them to do
#
for my $accessor (@accessors) {
    my $getter = "get$accessor";
    my $setter = "set$accessor";

    my $val = $tm->$getter();
    ok($val, "value from $getter should initially be non-falsy");

    my $test_string = "test string";
    $tm->$setter($test_string);
    $val = $tm->$getter();

    cmp_ok($val, 'eq', $test_string, "value should be round-tripped successfully through accessor");
}
