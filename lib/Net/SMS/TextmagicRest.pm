#
# Net::SMS::TextmagicRest. This module provides access to TextMagic REST APIv2 SMS messaging service
#
# Author: Dmitry <dmitry@textmagic.biz>
#
# Copyright (c) 2015 TextMagic Ltd. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
package Net::SMS::TextmagicRest;

our ($VERSION) = '2.00';

use strict;
use warnings;
use diagnostics;

use feature 'switch';
no warnings 'experimental::smartmatch';

use constant TRUE => 1;
use constant FALSE => 0;

use REST::Client;
use URI::Escape qw(uri_escape);
use JSON;
use Carp;
use String::CamelCase qw(decamelize);
use Time::HiRes qw(time);

use Data::Dumper;

our %paginatorArgs = (
    page    => 1,
    limit   => 10
);

our %messagesArgs = (
    text        => undef,
    phones      => undef,
    contacts    => undef,
    lists       => undef,
    templateId  => undef,
    sendingTime => undef,
    cutExtra    => FALSE,
    partsCount  => undef,
    referenceId => undef,
    from        => undef,
    rrule       => undef,
    dummy       => FALSE,
);

our %contactsArgs = (
    firstName   => undef,
    lastName    => undef,
    phone       => undef,
    email       => undef,
    companyName => undef,
    country     => undef,
    lists       => undef,
);

our %listsArgs = (
    name        => undef,
    description => undef,
    shared      => FALSE,
);

our %numberArgs = (
    phone       => undef,
    country     => undef,
    userId      => undef,
);

=head1 NAME

Net::SMS::TextmagicRest - A simple client for interacting with TextMagic REST APIv2

=head1 SYNOPSIS

 use NET::SMS::TextmagicRest;
 
 #The basic use case
 my $client = NET::SMS::TextmagicRest->new();
 $tm->send(
    text    => 'My API SMS',
    phones  => ( '99912345' ),
    contacts => ( '27039' )
 )

=head1 DESCRIPTION

Net::SMS::TextmagicRest provides a simple way to interact with TextMagic REST API resources.

=head1 METHODS

=head3 new

Construct a new REST::Client. Takes an optional hash or hash reference or
config flags. Each config flag also has get/set accessors of the form
getHost/setHost, getUserAgent/setUserAgent, etc.  These can be called on the
instantiated object to change or check values.

Usage:

  my $tm = Net::SMS::TextmagicRest->new(username => 'username', token => 'longAZaz09token');
  
Config flags:

=over 4

=item username (required)

TextMagic account username.

=item token (required)

API access token. You can generate a new one at https://my.textmagic.com/online/api/rest-api/keys.

=item baseUrl

TextMagic API base URL prepended to all resources. Default is https://rest.textmagic.com/api/v2.

=back

=cut

sub new {
    my $class = shift || undef;
    if (!defined $class) {
        return undef;
    }        
    
    my %args = (
        baseUrl     => 'https://rest.textmagic.com/api/v2',
        userAgent   => 'textmagic-rest-perl/' . $Net::SMS::TextmagicRest::VERSION,
        @_
    );
    
    $class->_buildAccessors();
    
    if (!exists $args{username} || !exists $args{token}) {
        $class->error('No username or token supplied');
    }
    
    my $self = bless {}, $class;
    
    $self->setUsername($args{username});
    $self->setToken($args{token});
    $self->setBaseUrl($args{baseUrl});
    $self->setUserAgent($args{userAgent});
    $self->_buildClient();
    
    $self->{previousRequestTime} = 0;
    
    return $self;
}

####################################################################################

=head2 User

=head3 getUserInfo

Returns User resource which represents current user account infromation.

=over 4

=item id

Internal TextMagic user ID.

=item username

TextMagic username.

=item firstName

First name.

=item lastName

Last name.

=item balance

Current account balance in account currency points.

=item currency

A hash reference with the following keys:

=over

=item * C<id> - The 3-letter ISO currency code: http://en.wikipedia.org/wiki/ISO_4217

=item * C<htmlSymbol> - The html entity which which can be directly prepended to the "balance" amount.

=back

=item timezone

A hash reference with the following keys:

=over

=item * C<area> - The account's ISO timezone area (usually one of America, Europe, Asia, or Africa)

=item * C<dst> - When Daylight Savings Time is on in the user's timezone, this is 1, otherwise 0.

=item * C<id> - The ISO timezone ID.

=item * C<offset> - The timezone offset from UTC in minutes.

=item * C<timezone> - The ISO timezone name (something like "America/Chicago").

=back

=back

=cut

sub getUserInfo {
    my $self = shift || undef;
    if(!defined $self) {
      return undef;
    }
    
    $self->request('GET', '/user');
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 setUserInfo

Updates existing user info based on the arguments passed in. The arguments are a
hash (not a hash reference) with keys matching the keys returned from
C<getUserInfo>. See the documentation of that method for details. The keys
C<firstName> and C<lastName> are required.

    $tm->setUserInfo(firstName => "First", lastName => "Last", currency => { id => "USD" });

=cut

sub setUserInfo {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        firstName   => undef,
        lastName    => undef,
        @_
    );
    
    $self->error('firstName and lastName should be specified') if (!$args{firstName} || !$args{lastName});
    
    my %requestArgs;
    
    while ((my $key, my $value) = each(%args)){
        my $newKey = 'user[' . lcfirst(decamelize($key)) . ']';
        $requestArgs{$newKey} = $value;
    }    
    
    $self->request('PUT', '/user', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '204') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 auth

Authenticate user by given username and password. Returning a username and token that you should pass to the all requests (in X-TM-Username and X-TM-Key, respectively).

=over 4

=item username

Account username or email.

=item password

Account password.

=back

=cut

sub auth {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        username    => undef,
        password    => undef,
        @_
    );
    
    $self->error('Username and password should be specified') if (!$args{username} || !$args{password});
    
    my %requestArgs;
    
    while ((my $key, my $value) = each(%args)){
        my $newKey = lcfirst(decamelize($key));
        $requestArgs{$newKey} = $value;
    }    
    
    $self->request('POST', '/tokens', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 refresh

Refresh current access token. Only non-expired tokens can be renewed

=cut

sub refresh {
    my $self = shift || undef;
    if(!defined $self) {
      return undef;
    }
    
    $self->request('GET', '/tokens/refresh');
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

####################################################################################

=head2 Messages

=head3 send

Send outbound SMS message to one or multiple phone numbers, contacts or lists.
This method can be also used for scheduling messages for sending it later.
Method can return a link to Session resource, Bulk resource or Schedule resource.

=over 4

=item text

Message text. Required if templateId is not set

=item templateId

Template used instead of message text. Required if text is not send.

=item sendingTime

Optional (required with recurrency_rule set). Message sending time in unix timestamp format. Default is now.

=item contacts

Array of contact resources id message will be sent to.

=item lists

Array of list resources id message will be sent to

=item phones

Array of E.164 phone numbers message will be sent to.

=item cutExtra

Optional. Should sending method cut extra characters which not fit supplied parts_count or return 400 Bad request response instead. Default is false.

=item partsCount

Optional. Maximum message parts count (TextMagic allows sending 1 to 6 message parts). Default is 6.

=item referenceId

Optional. Custom message reference id which can be used in your application infrastructure.

=item from

Optional. One of allowed Sender ID (phone number or alphanumeric sender ID). If specified Sender ID is not allowed for some destinations, a fallback default Sender ID will be used to ensure delivery

=item rrule

Optional. iCal RRULE parameter to create recurrent scheduled messages. When used, sending_time is mandatory as start point of sending

=back

=cut

sub send {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %messagesArgs,
        @_
    );    
    
    $self->error('Either text or templateId should be specified') if (!$args{text} && !$args{templateId});
    $self->error('Either phones, contacts or lists should be specified') if (!($args{phones} || $args{contacts} || $args{lists}));
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('POST', '/messages', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if (substr($self->getClient()->responseCode(), 0, 2) ne '20') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getMessage

Get a single outgoing message. Receives "id" of message as a parameter. Example:

  %message = $tm->getMessage(4820993);

=cut

sub getMessage {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Message ID should be numeric');
    }
    
    $self->request('GET', '/messages/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getMessages

Get all user oubound messages. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getMessages {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );

    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/messages', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getReply

Get a single outgoing message. Receives "id" of message as a parameter. Example:

  %message = $tm->getReply(9463004);

=cut

sub getReply {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Reply ID should be numeric');
    }
    
    $self->request('GET', '/replies/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getReplies

Get all inbox messages. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getReplies {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/replies', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getSession

Get a message session. Receives "id" of session as a parameter. Example:

  %message = $tm->getSession(31545);

=cut

sub getSession {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Session ID should be numeric');
    }
    
    $self->request('GET', '/sessions/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getSessions

Get all sending sessions. Arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

=back

How many results to return (default: 10).

=cut

sub getSessions {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/sessions', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getSessionMessages

Fetch messages by given session id. Arguments:

=over 4

=item id

Session ID.

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getSessionMessages {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if (!$args{id} || $args{id} !~ /^\d+$/) {
        $self->error('Session ID should be numeric');
    }
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }

    my $id = delete $args{id};
    
    $self->request('GET', '/sessions/' . $id . '/messages', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getSchedule

Get message sending schedule. Receives "id" of session as a parameter. Example:

  %message = $tm->getSchedule(382);

=cut

sub getSchedule {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Schedule ID should be numeric');
    }
    
    $self->request('GET', '/schedules/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getSchedules

Get all scheduled messages. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getSchedules {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/schedules', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getBulk

Get bulk message session status. Receives "id" of bulk session as a parameter. Example:

  %message = $tm->getBulk(994135);

=cut

sub getBulk {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Bulk ID should be numeric');
    }
    
    $self->request('GET', '/bulks/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getBulks

Get all bulk message sessions. Arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

=back

How many results to return (default: 10).

=cut

sub getBulks {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/bulks', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getChats

Get all chats. Arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

=back

How many results to return (default: 10).

=cut

sub getChats {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/chats', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getChat

Fetch messages from chat with specified phone number. Arguments:

=over 4

=item phone

Phone number in E.164 format.

=item page

Fetch specified results page (default: 1).

=item limit

=back

How many results to return (default: 10).

=cut

sub getChat {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }        
    
    my %args = (
        %paginatorArgs,
        @_
    );
    
    if (!$args{phone} || $args{phone} !~ /^\+?\d+$/) {
        $self->error('Specify a valid phone number');
    }
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }

    my $phone = delete $args{phone};
    
    $self->request('GET', '/chats/' . $phone, \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getPrice

Check pricing for a new outbound message. See "send" command reference for available arguments list.

=cut

sub getPrice {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %messagesArgs,        
        @_,
        dummy   => TRUE,
    );
    
    $self->error('Either text or templateId should be specified') if (!$args{text} && !$args{templateId});
    $self->error('Either phones, contacts or lists should be specified') if (!$args{phones} && !$args{contacts} && !$args{lists});
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('GET', '/messages/price', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 deleteMessage

Delete a single message.. Receives "id" of message as a parameter. Example:

  $tm->deleteMessage(4820993);

=cut

sub deleteMessage {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Message ID should be numeric');
    }
    
    $self->request('DELETE', '/messages/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

=head3 deleteReply

Delete the incoming message. Receives "id" of reply as a parameter. Example:

  $tm->deleteReply(32184555);

=cut

sub deleteReply {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Reply ID should be numeric');
    }
    
    $self->request('DELETE', '/replies/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

=head3 deleteSchedule

Delete a message session, together with all nested messages. Receives "id" of schedule as a parameter. Example:

  $tm->deleteSchedule(1384);

=cut

sub deleteSchedule {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Schedule ID should be numeric');
    }
    
    $self->request('DELETE', '/schedules/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

=head3 deleteSession

Delete a message session, together with all nested messages. Receives "id" of session as a parameter. Example:

  $tm->deleteSession(1384);

=cut

sub deleteSession {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Session ID should be numeric');
    }
    
    $self->request('DELETE', '/sessions/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

####################################################################################

=head2 Templates

=head3 getTemplate

Get a single template. Receives "id" of template as a parameter. Example:

  %template = $tm->getTemplate(382);

=cut

sub getTemplate {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Template ID should be numeric');
    }
    
    $self->request('GET', '/templates/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getTemplates

Get all user templates. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getTemplates {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/templates', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 deleteTemplate

Delete a single template. Receives "id" of template as a parameter. Example:

  $tm->deleteSession(1384);

=cut

sub deleteTemplate {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Template ID should be numeric');
    }
    
    $self->request('DELETE', '/templates/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

=head3 addTemplate

Create a new template from the submitted data.

=over 4

=item name

Template name.

=item body

Template text. May contain tags inside braces.

=back

=cut

sub addTemplate {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        @_
    );
    
    $self->error('Template text and body should be specified') if (!$args{name} || !$args{body});
      
    my %requestArgs = convertArgs(\%args);
    
    $self->request('POST', '/templates', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 updateTemplate

Update existing template.

=over 4

=item id

Template id.

=item name

Template name.

=item body

Template text. May contain tags inside braces.

=back

=cut

sub updateTemplate {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        @_
    );
    
    $self->error('Template id, text and body should be specified') if (!$args{id} || !$args{name} || !$args{body});
    
    if (!$args{id} || $args{id} !~ /^\d+$/) {
        $self->error("Template ID should be numeric");
    }
    
    my %requestArgs;
    
    while ((my $key, my $value) = each(%args)){
        if ($key eq 'id') {
            next;
        }
        
        my $newKey = 'template[' . lcfirst(decamelize($key)) . ']';
        $requestArgs{$newKey} = $value;
    }    

    $self->request('PUT', '/templates/' . $args{id}, \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

####################################################################################

=head2 Statistics

=head3 getMessagingStats

Return messaging statistics. Optional arguments:

=over 4

=item by

Group results by specified period: "off", "day", "month" or "year". Default is "off".

=item start

Optional. Start date in unix timestamp format. Default is 7 days ago.

=item end

Optional. End date in unix timestamp format. Default is now.

=back

=cut

sub getMessagingStats {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        by      => 'off',
        start   => undef,
        end     => undef,
        @_
    );    
    
    $self->request('GET', '/stats/messaging', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getSpendingStats

Return messaging statistics. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=item start

Optional. Start date in unix timestamp format. Default is 7 days ago.

=item end

Optional. End date in unix timestamp format. Default is now.

=back

=cut

sub getSpendingStats {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        start   => undef,
        end     => undef,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/stats/spending', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getInvoices

Get all user invoices. Arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

=back

How many results to return (default: 10).

=cut

sub getInvoices {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/invoices', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

####################################################################################

=head2 Contacts

=head3 getContact

Get a single contact. Receives "id" of template as a parameter. Example:

  $contact = $tm->getContact(334223);

=cut

sub getContact {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Contact ID should be numeric');
    }
    
    $self->request('GET', '/contacts/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getContacts

Get all user contacts. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=item shared

Should shared contacts to be included (default FALSE).

=back

=cut

sub getContacts {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        shared  => FALSE,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/contacts', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 deleteContact

Delete a single contact. Receives "id" of contact as a parameter. Example:

  $tm->deleteContact(334223);

=cut

sub deleteContact {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Contact ID should be numeric');
    }
    
    $self->request('DELETE', '/contacts/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

=head3 addContact

Create a new contact from the submitted data.

=over 4

=item firstName

Contact first name.

=item lastName

Contact last name.

=item phone

Contact phone number.

=item email

Contact email address.

=item companyName

Contact company name.

=item country

Two letter ISO country code.

=item lists

Array of lists contact will be assigned to.

=back

=cut

sub addContact {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %contactsArgs,
        @_
    );
    
    $self->error('Contact phone and at least one list should be specified') if (!$args{phone} || !$args{lists});
    
    if ($args{phone} !~ /^\+?\d+$/) {
        $self->error('Specify a valid phone number');
    }
    if (ref $args{lists} ne 'ARRAY' || join(",", $args{lists}) !~ /\d+(,\d+)*/) {
        $self->error('Specify a valid array of numeric list ids');
    }

    my %requestArgs = convertArgs(\%args);
    
    $self->request('POST', '/contacts', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 updateContact

Update existing template.

=over 4

=item id

Contact ID.

=item firstName

Contact first name.

=item lastName

Contact last name.

=item phone

Contact phone number.

=item email

Contact email address.

=item companyName

Contact company name.

=item country

Two letter ISO country code.

=item lists

Array of lists contact will be assigned to.

=back

=cut

sub updateContact {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        id  => undef,
        %contactsArgs,
        @_
    );
    
    $self->error('Contact ID, phone and at least one list should be specified') if (!$args{id} || !$args{phone} || !$args{lists});
        
    if ($args{id} !~ /^\d+$/) {
        $self->error('Contact ID should be numeric');
    }
    if ($args{phone} !~ /^\+?\d+$/) {
        $self->error('Specify a valid phone number');
    }
    if (ref $args{lists} ne 'ARRAY' || join(",", $args{lists}) !~ /\d+(,\d+)*/) {
        $self->error('Specify a valid array of numeric list ids');
    }

    my %requestArgs = convertArgs(\%args);
    
    $self->request('PUT', '/contacts/' . $args{id}, \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getContactLists

Return lists which contact belongs to. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getContactLists {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        id  => undef,
        %paginatorArgs,
        @_
    );
    
    if (!$args{id} || $args{id} !~ /^\d+$/) {
        $self->error('Contact ID should be numeric');
    }
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }

    my $id = delete $args{id};
    
    $self->request('GET', '/contacts/' . $id . '/lists', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getUnsubscribedContact

Get a single unsubscribed contact. Receives "id" of template as a parameter. Example:

  $template = $tm->getUnsubscribedContact(4398);

=cut

sub getUnsubscribedContact {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Unsubscriber ID should be numeric');
    }
    
    $self->request('GET', '/unsubscribers/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getUnsubscribedContacts

Get all contact have unsubscribed from your communication. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getUnsubscribedContacts {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/unsubscribers', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 unsubscribeContact

Unsubscribe contact from your communication by phone number.

=over 4

=item phone

Phone number.

=back

=cut

sub unsubscribeContact {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        phone   => undef,
        @_
    );
    
    if (!$args{phone} || $args{phone} !~ /^\+?\d+$/) {
        $self->error('Specify a valid phone number');
    }
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('POST', '/unsubscribers', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head2 Custom fields

=head3 getCustomField

Get a single custom field.. Receives "id" of template as a parameter. Example:

  %cf = $tm->getCustomField(415);

=cut

sub getCustomField {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Custom field ID should be numeric');
    }
    
    $self->request('GET', '/customfields/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getCustomFields

Get all available custom fields. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getCustomFields {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/customfields', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 deleteCustomField

Delete a single custom field. Receives "id" of template as a parameter. Example:

  $tm->deleteCustomField(384);

=cut

sub deleteCustomField {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Custom field ID should be numeric');
    }
    
    $self->request('DELETE', '/customfields/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

=head3 addCustomField

Create a new custom field from the submitted data.

=over 4

=item name

Custom field name.

=back

=cut

sub addCustomField {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        @_
    );
    
    $self->error('Custom field name should be specified') if (!$args{name});
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('POST', '/customfields', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 updateCustomField

Update existing custom field.

=over 4

=item id

Custom field id.

=item name

Custom field name.

=back

=cut

sub updateCustomField {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        @_
    );
    
    $self->error('Custom field ID and name should be specified') if (!$args{id} || !$args{name});    
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('PUT', '/customfields/' . $args{id}, \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 updateCustomFieldValue

Update contact's custom field value.

=over 4

=item id

Custom field ID.

=item contactId

Contact ID.

=item value

Custom field value.

=back

=cut

sub updateCustomFieldValue {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        @_
    );
    
    $self->error('Custom field ID, value and contact ID hould be specified') if (!$args{id} || !$args{contactId} || !$args{value});
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('PUT', '/customfields/' . $args{id} . '/update', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

####################################################################################

=head2 Lists

=head3 getList

Get a single list. Receives "id" of the list as a parameter. Example:

  $list = $tm->getList(31322);

=cut

sub getList {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('List ID should be numeric');
    }
    
    $self->request('GET', '/lists/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getLists

Get all user lists. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getLists {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/lists', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 deleteList

Delete a single list. Receives "id" of template as a parameter. Example:

  $tm->deleteList(31332);

=cut

sub deleteList {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('List ID should be numeric');
    }
    
    $self->request('DELETE', '/lists/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

=head3 addList

Create a new list from the submitted data.

=over 4

=item name

List name.

=item description

List description.

=item shared

Should this list be shared with sub-accounts.

=back

=cut

sub addList {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %listsArgs,
        @_
    );
    
    $self->error('List name should be specified') if (!$args{name});
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('POST', '/lists', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 addContactsToList

Assign contacts to the specified list.

=over 4

=item id

List id.

=item contacts

List contacts.

=back

=cut

sub addContactsToList {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        id  => undef,
        @_
    );
    
    $self->error('List ID and least one contact should be specified') if (!$args{id} || !$args{contacts});
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('PUT', '/lists/' . $args{id} . '/contacts', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getListContacts

Fetch user contacts by given group id. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getListContacts {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        id  => undef,
        %paginatorArgs,
        @_
    );
    
    my $id = delete $args{id};
    
    if (!$id || $id !~ /^\d+$/) {
        $self->error('List ID should be numeric');
    }
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/lists/' . $id . '/contacts', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 deleteContactsFromList

Unassign contacts from the specified list.

=over 4

=item id

List id.

=item contacts

List contacts.

=back

=cut

sub deleteContactsFromList {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
   my %args = (
        id  => undef,
        @_
    );
    
    $self->error('List ID and least one contact should be specified') if (!$args{id} || !$args{contacts});
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('DELETE', '/lists/' . $args{id} . '/contacts', \%requestArgs);    
    
    if ($self->getClient()->responseCode() eq '201') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

####################################################################################

=head2 Sending sources

=head3 getDedicatedNumber

Get a single dedicated number.. Receives "id" of template as a parameter. Example:

  $number = $tm->getDedicatedNumber(334223);

=cut

sub getDedicatedNumber {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Number ID should be numeric');
    }
    
    $self->request('GET', '/numbers/' . $id);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 getDedicatedNumbers

Get all bought dedicated numbers. Optional arguments:

=over 4

=item page

Fetch specified results page (default: 1).

=item limit

How many results to return (default: 10).

=back

=cut

sub getDedicatedNumbers {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %paginatorArgs,
        @_
    );    
    
    if ($args{page} !~ /^\d+$/) {
        $self->error("page should be numeric");
    }
    if ($args{limit} !~ /^\d+$/) {
        $self->error("limit should be numeric");
    }
    
    $self->request('GET', '/numbers', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 searchDedicatedNumbers

Find available dedicated numbers to buy. Arguments:

=over 4

=item country

ISO 2-letter dedicated number country ID (e.g. DE for Germany).

=item prefix

Optional. Desired number prefix. Should include country code (e.g. 447 for GB)

=back

=cut

sub searchDedicatedNumbers {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        @_
    );
    
    $self->error('Country ID should be specified') if (!$args{country});
    
    $self->request('GET', '/numbers/available', \%args);
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '200') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 buyDedicatedNumber

Buy a dedicated number and assign it to the specified account.

=over 4

=item phone

Desired dedicated phone number in international E.164 format.

=item country

Dedicated number country 2-letter ISO country code.

=item userId

User ID this number will be assigned to

=back

=cut

sub buyDedicatedNumber {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my %args = (
        %numberArgs,
        @_
    );
    
    $self->error('All arguments are mandatory: phone, country and userId') if (!$args{phone} || !$args{country} || !$args{userId});
    
    my %requestArgs = convertArgs(\%args);
    
    $self->request('POST', '/numbers', \%requestArgs);    
    
    my $response = from_json($self->getClient()->responseContent());
    
    if ($self->getClient()->responseCode() ne '201') {
        $self->error($response->{message});
    } else {    
        return $response;
    }
}

=head3 cancelDedicatedNumber

Cancel dedicated number subscription. Receives "id" of dedicated number as a parameter. Example:

  $tm->cancelDedicatedNumber(334223);

=cut

sub cancelDedicatedNumber {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $id = shift;
    
    if (!defined $id || $id !~ /^\d+$/) {
        $self->error('Dedicated number ID should be numeric');
    }
    
    $self->request('DELETE', '/numbers/' . $id);
    
    if ($self->getClient()->responseCode() eq '204') {
        return TRUE;
    }
    
    my $response = from_json($self->getClient()->responseContent());
    $self->error($response->{message});    
}

####################################################################################

sub request {
    my $self = shift || undef;
    if (!defined $self) {
        return undef;
    }
    
    my $method   = shift;
    my $resource = shift;
    my $request  = shift || {};
    
    if (time - $self->{previousRequestTime} < 0.5) {
        Time::HiRes::sleep(time - $self->{previousRequestTime});
    }
        
    $self->error('No resource specified') unless $resource;    
    
    if (!$request) {
        $request = undef;
    } else {
        $request = $self->getClient()->buildQuery($request);
    }    
    
    $self->_buildClient();
    
    $self->{previousRequestTime} = time;
    
    if ($request) {
        given ($method) {
            when ($_ eq 'POST' || $_ eq 'PUT') {
                return $self->getClient()->$method($resource, substr($request, 1));
            }
            default {
                return $self->getClient()->$method($resource . $request);
            }
        }   
    } else {
        return $self->getClient()->$method($resource);
    }
}

sub error {
    my $self = shift;    
    my $text = shift || 'Unknown';
    
    croak 'Net::SMS::TextmagicRest exception: ' . $text;
}

# Convert arguments before making request
sub convertArgs {
    my $argsRef     = shift;
    my $name        = shift || undef;
    my $decamelize  = shift || FALSE;
    my %args        = %$argsRef;
    my %requestArgs = ();
    
    while ((my $key, my $value) = each(%args)){
        if ($key eq 'id') {
            next;
        }
        
        if (ref($value) eq 'ARRAY') {
            $value = join(',', @{$value});
        }
        
        my $newKey = $key;        
        $newKey    = lcfirst(decamelize($newKey)) if $decamelize;
        $newKey    = $name . '[' . $newKey . ']' if defined $name;

        $requestArgs{$newKey} = $value;
    }
    
    return %requestArgs;
}

sub _buildAccessors {
    my $self = shift;

    my @attributes = qw(BaseUrl Username Token UserAgent Client);

    for my $attribute (@attributes){
        my $local_attribute = $attribute;

        my $set_method = sub {
            my $self = shift;
            $self->{'_config'}{$local_attribute} = shift;
            return $self->{'_config'}{$local_attribute};
        };

        my $get_method = sub {
            my $self = shift;
            return $self->{'_config'}{$local_attribute};
        };


        {
            no strict 'refs';
            no warnings 'redefine';
            *{'Net::SMS::TextmagicRest::set'.$attribute} = $set_method;
            *{'Net::SMS::TextmagicRest::get'.$attribute} = $get_method;
        }

    }

    return;
}

sub _buildClient {
    my $self  = shift;
    
    $self->error('No username/token supplied') if (!$self->getUsername() || !$self->getToken() || !$self->getBaseUrl());

    my $client = REST::Client->new(
        host    => $self->getBaseUrl(),
        timeout => 30,
    );
    $client->addHeader('X-TM-Username', $self->getUsername());
    $client->addHeader('X-TM-Key', $self->getToken());
    $client->addHeader('Content-type', 'application/x-www-form-urlencoded');
    $client->getUseragent()->agent($self->getUserAgent());
    
    $self->setClient($client);

    return;
}
