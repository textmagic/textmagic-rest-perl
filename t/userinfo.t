use strict;
use warnings;

use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More tests => 10;

# Variables capturing data passed into or out of the REST client.
my $injected_json = "{}";
my $injected_code = 200;
my $captured_self = undef;
my $captured_resource = "";
my $captured_data = "";

#
# Create our mock REST client; doing this before creating the TextMagic object
# causes our mock definitions to be loaded by TextmagicRest
#
my $mock = Test::MockModule->new('REST::Client');
$mock->mock("GET", sub { ($captured_self, $captured_resource, $captured_data) = @_; });
$mock->mock("PUT", sub { ($captured_self, $captured_resource, $captured_data) = @_; });
$mock->mock("buildQuery", sub { return " " . JSON::encode_json($_[1]) if $_[1] && keys %{$_[1]}; }); # Encode query strings as JSON, just to make them easy to decode
$mock->mock("responseContent", sub { return $injected_json; });
$mock->mock("responseCode", sub { return $injected_code });

my $tm = Net::SMS::TextmagicRest->new(username => "testuser", token => "testtoken");

# 
# Create a mock userinfo object which imitates the contents of an actual message
#
my $mock_userinfo = {
    id => 54321,
    username => "testuser",
    firstName => "Testy",
    lastName => "McTesterson",
    balance => 99.99,
    currency => { id => "EUR", htmlSymbol => "&euro;" },
    timezone => { timezone => "Europe/Athens", area => "Europe", dst => 0, id => 23, offset => 1234 }
};
$injected_json = JSON::encode_json($mock_userinfo);
$injected_code = 200;

my $userinfo = $tm->getUserInfo();
cmp_ok($captured_resource, 'eq', '/user', "calling getUserInfo() should request /user");
ok(!defined $captured_data, "calling getUserInfo() doesn't pass query data");
is_deeply($userinfo, $mock_userinfo, "json from responseContent was decoded and returned as expected");

# 
# Create a mock error message with an injected error code
#
my $error_msg = "a testing error message";
$injected_json = JSON::encode_json({ message => $error_msg });
$injected_code = 300;

eval { 
    $userinfo = $tm->getUserInfo(); 
    fail("getUserInfo() with an error response code should throw"); 
};
like($@, qr/$error_msg/, "the error message from the response string is included in the error");

# 
# Set user info to something reasonable
#
my %mock_setinfo = (
    firstName => "Testy",
    lastName => "McTesterson",
    foo => "foovalue"
);
my $munged_setinfo = { # This is the data structure after it's internally mangled by the API
    "user[foo]" => "foovalue",
    "user[first_name]" => "Testy",
    "user[last_name]", => "McTesterson"
};
$injected_json = JSON::encode_json({ success => 'ok' });
$injected_code = 204;

my $result = $tm->setUserInfo(%mock_setinfo);
cmp_ok($captured_resource, 'eq', "/user", "calling setUserInfo should put to /user");
is_deeply(JSON::decode_json($captured_data), $munged_setinfo, "calling setUserInfo should pass the expected data structure");
is_deeply($result, { success => 'ok' }, "json from responseContent was decoded and returned as expected");

#
# setUserInfo handling of bad params
#
eval {
    $result = $tm->setUserInfo(firstName => "Tester", foo => "val");
    fail("setUserInfo without last name should fail");
};
like($@, qr/firstName and lastName should be specified/, "expected error message was not found");

eval {
    $result = $tm->setUserInfo(lastName => "McTesterson", foo => "val");
    fail("setUserInfo without first name should fail");
};
like($@, qr/firstName and lastName should be specified/, "expected error message was not found");

# 
# setUserInfo handling of an error message returned from the server
#
$error_msg = "setUserInfo error message";
$injected_json = JSON::encode_json({ message => $error_msg });
$injected_code = 500;

eval {
    $result = $tm->setUserInfo(%mock_setinfo);
    fail("setUserInfo() with an error response code should throw");
};
like($@, qr/$error_msg/, "the error message from the response should be included in the thrown error");

=not Non-mock tests
ok($userinfo->{'id'}, "initial id is set");
cmp_ok($userinfo->{'username'}, 'eq', $username, "initial username value");
cmp_ok($userinfo->{'firstName'}, 'eq', "Jesse", "initial first name set");
cmp_ok($userinfo->{'lastName'}, 'eq', "Bangs", "initial last name set");
cmp_ok($userinfo->{'balance'}, 'eq', "0.338", "initial balance");
is_deeply($userinfo->{'currency'}, {id => 'EUR', htmlSymbol => '&euro;'});
is_deeply($userinfo->{'timezone'}, {timezone => "Europe/Bucharest", area => 'Europe', dst => 1, id => 143, offset => 7200});
=cut
