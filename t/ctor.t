use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More tests => 14;

# Variables capturing data passed into or out of the REST client.
my $injected_json = "{}";
my $injected_code = 200;
my $captured_self = undef;
my $captured_resource = "";
my %called = (
    GET => 0,
    DELETE => 0,
    POST => 0,
    PUT => 0,
);

#
# Create our mock REST client; doing this before creating the TextMagic object
# causes our mock definitions to be loaded by TextmagicRest
#
my $mock = Test::MockModule->new('REST::Client');
$mock->mock("GET", sub { ($captured_self, $captured_resource) = @_; $called{GET}++;  });
$mock->mock("responseContent", sub { return $injected_json; });
$mock->mock("responseCode", sub { return $injected_code });

BEGIN { use_ok( 'Net::SMS::TextmagicRest' ); }

require_ok( 'Net::SMS::TextmagicRest' );

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';
my $baseUrl = 'http://example.com';

my $tm = Net::SMS::TextmagicRest->new(username => $username, token => $token, baseUrl => $baseUrl);

ok($tm, "Object created with constructor should not be null");

cmp_ok($tm->getUsername(), 'eq', $username, "getUser() reflects param passed in constructor");
cmp_ok($tm->getToken(), 'eq', $token, "getToken() reflects param passed in constructor");
cmp_ok($tm->getBaseUrl(), 'eq', $baseUrl, "getBaseUrl() reflects param passed in constructor");

#
# Test invalid/missing params
#

eval {
    my $fail = Net::SMS::TextmagicRest->new(token => $token);
    fail("should have thrown without username");
};
like($@, qr/No username or token supplied/);

eval { 
    my $fail = Net::SMS::TextmagicRest->new(user => $username);
    fail("should have thrown without API key");
};
like ($@, qr/No username or token supplied/);

eval { 
    my $fail = Net::SMS::TextmagicRest->new(user => $username, token => $token, baseUrl => "");
    fail("should have thrown with empty baseURL");
};
like ($@, qr/No username or token supplied/);

# 
# auth() is tested in crud.t
#

# 
# refresh success case
#
$injected_json = JSON::encode_json({ success => "ok" });

my $resp = $tm->refresh();
cmp_ok($called{GET}, '==', 1, "calling refresh() should make a GET call to the server");
cmp_ok($captured_resource, 'eq', "/tokens/refresh", "refresh() called to the expected uri /tokens/refresh");
is_deeply($resp, { success => "ok" }, "the message returned from refresh was successfully decoded from JSON");

# 
# server error response
#
$injected_code = 500;
$injected_json = JSON::encode_json({ message => "test error message" });
eval {
    $called{GET} = 0;
    $tm->refresh();
    fail("refresh should throw when the server returns an error code");
};
cmp_ok($called{GET}, '==', 1, "calling refresh should make a GET call to the server");
like($@, qr/test error message/, "expected error message wasn't thrown");
