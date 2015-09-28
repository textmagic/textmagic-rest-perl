use strict;
use warnings;

use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More;

# 
# This file contains tests for getMessagingStats, getSpendingStats, and
# getInvoices.
#

# Variables capturing data passed into or out of the REST client.
my $injected_json = "{}";
my $injected_code = 200;
my $captured_self = undef;
my $captured_resource = "";
my $captured_data = "";
my %called = (
    GET => 0
);

#
# Create our mock REST client; doing this before creating the TextMagic object
# causes our mock definitions to be loaded by TextmagicRest
#
my $mock = Test::MockModule->new('REST::Client');
$mock->mock("GET", sub { ($captured_self, $captured_resource, $captured_data) = @_; $called{GET}++; });
$mock->mock("buildQuery", sub { return " " . JSON::encode_json($_[1]) if $_[1] && keys %{$_[1]}; });
$mock->mock("responseContent", sub { return $injected_json; });
$mock->mock("responseCode", sub { return $injected_code });

my $tm = Net::SMS::TextmagicRest->new(username => "testuser", token => "testtoken");

# 
# getMessagingStats success cases
#
$injected_json = JSON::encode_json({ success => "ok" });
$injected_code = 200;

my $result = $tm->getMessagingStats();
cmp_ok($called{GET}, '==', 1, "getMessagingStats resulted in a GET call");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/stats/messaging', "should have made a call to expected endpoint");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { by => "off", start => undef, end => undef }, "default arguments passed through to server");
is_deeply($result, { success => "ok" }, "result response decoded from JSON");

my %args = (by => "day", start => time - 5000, end => time - 5000);
$tm->getMessagingStats(%args);
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/stats/messaging', "should have made a call to expected endpoint");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), \%args, "explicit arguments passed through to server");

# 
# getMessagingStats server error response
#
$injected_json = JSON::encode_json({ message => "test error" });
$injected_code = 500;

eval {
    $called{GET} = 0;
    $tm->getMessagingStats();
    fail("should throw exception after server error response");
};
cmp_ok($called{GET}, '==', 1, "should have resulted in a GET call");
like($@, qr/test error/, "expected error message thrown");

# 
# getSpendingStats success cases
#
$injected_json = JSON::encode_json({ success => "ok" });
$injected_code = 200;
$called{GET} = 0;

$result = $tm->getSpendingStats();
cmp_ok($called{GET}, '==', 1, "getSpendingStats resulted in a GET call");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/stats/spending", "should have made a call to expected endpoint");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10, start => undef, end => undef }, "default arguments passed through to server");
is_deeply($result, { success => "ok" }, "result response decoded from JSON");

%args = (page => 3, limit => 20, start => time - 5000, end => time - 1000);
$tm->getSpendingStats(%args);
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/stats/spending', "should have made a call to expected endpoint");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), \%args, "explicit arguments passed through to server");

#
# getSpendingStats server error response
#
$injected_json = JSON::encode_json({ message => "test error" });
$injected_code = 500;

eval {
    $called{GET} = 0;
    $tm->getMessagingStats();
    fail("should throw exception after server error response");
};
cmp_ok($called{GET}, '==', 1, "should have resulted in a GET call");
like($@, qr/test error/, "expected error message thrown");

#
# getInvoices success cases
#
$injected_json = JSON::encode_json({ success => "ok" });
$injected_code = 200;
$called{GET} = 0;

$result = $tm->getInvoices();
cmp_ok($called{GET}, '==', 1, "getInvoices resulted in a GET call");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/invoices", "should have made a call to expected endpoint");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10 }, "default arguments passed through to server");
is_deeply($result, { success => "ok" }, "result response decoded from JSON");

%args = (page => 3, limit => 20);
$tm->getInvoices(%args);
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/invoices', "should have made a call to expected endpoint");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), \%args, "explicit arguments passed through to server");

# 
# getInvoices server error response
# 
$injected_json = JSON::encode_json({ message => "test error" });
$injected_code = 500;

eval {
    $called{GET} = 0;
    $tm->getInvoices();
    fail("should throw exception after server error response");
};
cmp_ok($called{GET}, '==', 1, "should have resulted in a GET call");
like($@, qr/test error/, "expected error message thrown");

done_testing();
