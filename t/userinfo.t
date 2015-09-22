use strict;
use warnings;
use Test::More tests => 7;

use Net::SMS::TextmagicRest;
use Data::Dumper;

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';

my $tm = Net::SMS::TextmagicRest->new(username => $username, token => $token);

my $userinfo = $tm->getUserInfo();

print Dumper($userinfo);

ok($userinfo->{'id'}, "initial id is set");
cmp_ok($userinfo->{'username'}, 'eq', $username, "initial username value");
cmp_ok($userinfo->{'firstName'}, 'eq', "Jesse", "initial first name set");
cmp_ok($userinfo->{'lastName'}, 'eq', "Bangs", "initial last name set");
cmp_ok($userinfo->{'balance'}, 'eq', "0.338", "initial balance");
is_deeply($userinfo->{'currency'}, {id => 'EUR', htmlSymbol => '&euro;'});
is_deeply($userinfo->{'timezone'}, {timezone => "Europe/Bucharest", area => 'Europe', dst => 1, id => 143, offset => 7200});
