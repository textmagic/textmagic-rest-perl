#!/usr/bin/perl -w
#
# textmagic-cli.pl - simple TextMagic REST API client demo
#
# Author: Dmitry <dmitry@textmagic.biz>
#
# This is the simple demonstration of the new TextMagic API. Interactive shell
# allows you to browse contacts, lists, templates and send messages. Just add
# your credentials at line 35/36 and have fun.
#
# Copyright (c) 2015 TextMagic Ltd. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
use strict;

use lib ("lib");

use Net::SMS::TextmagicRest;
use Try::Tiny;

##################################################################
# CONFIGURATION
##################################################################

# To suppress warning on printing undef. It's better not to use it in production
no warnings 'uninitialized';

use constant {
    TRUE            => 1,
    FALSE           => 0,
    VERSION         => '0.01',
};

# API Credentials. You may obtain it at https://my.textmagic.com/online/rest-api/keys/
use constant {
    API_USERNAME   => '',
    API_TOKEN      => '',
};

# Error codes
use constant {
    E_GENERAL_ERROR         => 1,
    E_INVALID_CREDENTIALS   => 2,    
};

# Constructing base TextmagicRest object
my $tm = Net::SMS::TextmagicRest->new(
    username => API_USERNAME,
    token    => API_TOKEN,
);

# User object
my $user = undef;

# Pagination
my $page  = 1;
my $limit = 10;
my $paginatedFunction = \&exitOk;

# sendMessage containers
my $sendingContacts = ();
my $sendingLists    = ();

# Default "Back to main menu" link
my %backMenu = (
    ('Back to main menu' => \&showMainMenu),
);

##################################################################
# MENU
#
# Methods for handling TUI menus
##################################################################

# MAIN
sub showMainMenu {
    flushPagination();
    
    my %items = (
        ('Contacts'  => \&showAllContacts),
        ('Lists'     => \&showAllLists),
        ('Messages'  => \&showMessagesMenu),
        ('Templates' => \&showAllTemplates),
        ('Information'=> \&showInformation),
    );
    
    showMenu(\%items);
}

# MESSAGES
sub showMessagesMenu {
    my %items = (
        ('Show outgoing messages'  => \&showMessagesOut),
        ('Show incoming messages'  => \&showMessagesIn),
        ('Send message'  => \&sendMessage),
    );
    
    showMenu(\%items);
}

##################################################################
# ACTIONS
#
# Methods which work directly with TM API (it's most likely you
# want to see here!)
##################################################################

# Show base account information
sub showInformation {
    print <<EOT;

ACCOUNT INFORMATION
===================

ID          : $user->{id}
Username    : $user->{username}
First Name  : $user->{firstName}
Last Name   : $user->{lastName}
Balance     : $user->{balance} $user->{currency}->{id}
Timezone    : $user->{timezone}->{timezone} ($user->{timezone}->{offset})
EOT

    showMenu(\%backMenu);
}

# Show all user contacts (including shared)
sub showAllContacts {
    $paginatedFunction = \&showAllContacts;
    
    my $response = $tm->getContacts(
        page    => $page,
        limit   => $limit,
        shared  => TRUE,
    );
    my @contacts = @{$response->{resources}};
    
    print <<EOT;

ALL CONTACTS
============
Page $response->{page} of $response->{pageCount}

EOT

    foreach (@contacts) {
        my $contact = $_;
        print "$contact->{id}. $contact->{firstName} $contact->{lastName}, $contact->{phone}\n";
    }
        
    my %items = (
        ('Previous page'        => \&goToPreviousPage),
        ('Next page'            => \&goToNextPage),
        ('Show contact details' => \&showContact),
        ('Delete contact'       => \&deleteContact),
        ('Back to main menu'    => \&showMainMenu),
    );
    
    showMenu(\%items);
}

# Show one contact details
sub showContact {
    my $id = readNumber("Enter contact ID");
    
    if (!$id) {
        return showAllContacts();
    }
    
    my $contact = $tm->getContact($id);
    
    print <<EOT;
    
CONTACT INFORMATION
===================

Name    : $contact->{firstName} $contact->{lastName}
Phone   : +$contact->{phone} ($contact->{country}->{name})
Company : $contact->{companyName}
EOT
    
    return showAllContacts();
}

# Delete contact permanently
sub deleteContact {
    my $id = readNumber("Enter contact ID");
    
    if (!$id) {
        return showAllContacts();
    }
    
    $tm->deleteContact($id);
    
    print "Contact deleted successfully";
    return showAllContacts();
}

# Show all user lists (including shared)
sub showAllLists {
    $paginatedFunction = \&showAllLists;
    
    my $response = $tm->getLists(
        page    => $page,
        limit   => $limit,
        shared  => TRUE,
    );
    my @contacts = @{$response->{resources}};
    
    print <<EOT;

ALL LISTS
=========
Page $response->{page} of $response->{pageCount}

EOT

    foreach (@contacts) {
        my $list = $_;
        print "$list->{id}. $list->{name} ($list->{description})\n";
    }
        
    my %items = (
        ('Previous page'        => \&goToPreviousPage),
        ('Next page'            => \&goToNextPage),
        ('Back to main menu'    => \&showMainMenu),
    );
    
    showMenu(\%items);
}

# Show all sent messages
sub showMessagesOut {
    $paginatedFunction = \&showMessagesOut;
    
    my $response = $tm->getMessages(
        page    => $page,
        limit   => $limit,
    );
    my @messages = @{$response->{resources}};
    
    print <<EOT;

SENT MESSAGES
=============
Page $response->{page} of $response->{pageCount}

EOT

    foreach (@messages) {
        my $message = $_;
        print "$message->{id}. $message->{text} (to $message->{receiver})\n";
    }
        
    my %items = (
        ('Previous page'        => \&goToPreviousPage),
        ('Next page'            => \&goToNextPage),
        ('Delete message'       => \&deleteMessagesOut),
        ('Back to main menu'    => \&showMainMenu),
    );
    
    showMenu(\%items);
}

# Delete one sent message
sub deleteMessagesOut {
    my $id = readNumber("Enter message ID");
    
    if (!$id) {
        return showMessagesOut();
    }
    
    $tm->deleteMessage($id);
    
    print "Message deleted successfully\n";
    return showMessagesOut();
}

# Show all received messages
sub showMessagesIn {
    $paginatedFunction = \&showMessagesIn;
    
    my $response = $tm->getReplies(
        page    => $page,
        limit   => $limit,
    );
    my @messages = @{$response->{resources}};
    
    print <<EOT;

RECEIVED MESSAGES
=================
Page $response->{page} of $response->{pageCount}

EOT

    foreach (@messages) {
        my $message = $_;
        print "$message->{id}. $message->{text} (from $message->{sender})\n";
    }
        
    my %items = (
        ('Previous page'        => \&goToPreviousPage),
        ('Next page'            => \&goToNextPage),
        ('Delete message'       => \&deleteMessageIn),
        ('Back to main menu'    => \&showMainMenu),
    );
    
    showMenu(\%items);
}

# Delete one received message
sub deleteMessagesIn {
    my $id = readNumber("Enter message ID");
    
    if (!$id) {
        return showMessagesIn();
    }
    
    $tm->deleteReply($id);
    
    print "Message deleted successfully\n";
    return showMessagesIn();
}

# Show all message templates
sub showAllTemplates {
    $paginatedFunction = \&showAllTemplates;
    
    my $response = $tm->getTemplates(
        page    => $page,
        limit   => $limit,
    );
    my @templates = @{$response->{resources}};
    
    print <<EOT;

TEMPLATES
=========
Page $response->{page} of $response->{pageCount}

EOT

    foreach (@templates) {
        my $template = $_;
        print "$template->{id}. $template->{name}: $template->{content}\n";
    }
        
    my %items = (
        ('Previous page'        => \&goToPreviousPage),
        ('Next page'            => \&goToNextPage),
        ('Delete template'      => \&deleteTemplate),
        ('Back to main menu'    => \&showMainMenu),
    );
    
    showMenu(\%items);
}

# Delete one message template
sub deleteTemplate {
    my $id = readNumber("Enter template ID");
    
    if (!$id) {
        return showAllTemplates();
    }
    
    $tm->deleteTemplate($id);
    
    print "Template deleted successfully\n";
    return showAllTemplates();
}

# Send outgoing message to phones, contacts and/or contact lists
sub sendMessage {
    print <<EOT;

SEND MESSAGE
============

EOT
    print "Text: ";
    chomp(my $sendingText = <STDIN>);
    print "\n\n";
    
    print "Enter phone numbers, separated by [ENTER]. Empty string to break.\n";

    my @sendingPhones   = ();
    my @sendingContacts = ();
    my @sendingLists    = ();
    
    my $phone;
    do {
       $phone = readNumber('Phone');
       push(@sendingPhones, $phone)
    } until (!$phone);
    pop(@sendingPhones);
    
    print "\n\nEnter contact IDs, separated by [ENTER]. Empty string to break.\n";
    
    my $contact;
    do {
       $contact = readNumber('Contact');
       push(@sendingContacts, $contact)
    } until (!$contact);
    pop(@sendingContacts);
    
    print "\n\nEnter list IDs, separated by [ENTER]. Empty string to break.\n";
    
    my $list;
    do {
       $list = readNumber('List');
       push(@sendingLists, $list)
    } until (!$list);
    pop(@sendingLists);
    
    print "\n\nYOU ARE ABOUT TO SEND MESSAGES TO:" .
          (scalar @sendingPhones?    "\nPhone numbers: " . join(', ', @sendingPhones): '') .
          (scalar @sendingContacts?  "\nContacts: "  . join(', ', @sendingContacts): '') .
          (scalar @sendingLists?     "\nLists: " . join(', ', @sendingLists): '');
    print "\nAre you sure (y/n)? ";
    
    chomp(my $answer = <STDIN>);
    if (!$answer eq 'y') {
        return showMainMenu();
    }
    
    my $result = $tm->send(
        text    => $sendingText,
        phones  => \@sendingPhones,
        contacts=> \@sendingContacts,
        lists   => \@sendingLists,
    );
        
    print "Message session $result->{id} sent\n\n";
    
    return showMainMenu;
}

##################################################################
# SERVICE
#
# Service methods like TUI menu builder, pagination and so on.
##################################################################

# Error handler
sub error {
    my $text = shift;
    my $code = shift || 1;
    
    print "[ERROR] " . $text . "\n";
    
    exit $code;
}

# Show top user info banner
sub showUserInfo {
    print 'TextMagic CLI v' . VERSION . " || $user->{firstName} $user->{lastName} ($user->{username}) || $user->{balance} $user->{currency}->{id}\n";
}

# Show numered menu and return user choice
sub showMenu {
    my $itemsRef = shift;
    my @functionRefs = undef;
    
    print "\n";
    
    my $i = 0;
    foreach (keys %{$itemsRef}) {
        $i++;
        print "$i. $_\n";
        $functionRefs[$i] = $itemsRef->{$_};
    }
    
    $i++;
    print "$i. Exit\n";
    $functionRefs[$i] = \&exitOk;
       
    my $choice = readNumber("Your choice ($i)");
    
    if (!$choice || $choice =~ /\D/ || !exists $functionRefs[$choice]) {
        $functionRefs[$i]->();
    } else {
        $functionRefs[$choice]->();
    }
    
    return $choice;
}

# Go to previous page when browsing paginated resource
sub goToPreviousPage {
    if ($page <= 2) {
        $page = 1;
    } else {
        $page--;
    }
    
    $paginatedFunction->();
}

# Go to next page when browsing paginated resource
sub goToNextPage {
    $page++;
    
    $paginatedFunction->();
}

# Reset current page, limit and paginated resource fetch function 
sub flushPagination {
    $page   = 1;
    $limit  = 10;
    $paginatedFunction = \&exitOk;
}

# Normal program termination
sub exitOk {
    print "Bye!\n";
    exit 0;
}

# Ask user for numeric input
sub readNumber {
    my $text = shift;
    
    print "$text: ";
    my $choice = <STDIN>;
    chomp $choice;
    
    $choice =~ s/^\s+|\s+$//g;
    
    return $choice;
}

# Main program procedure
sub main {
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0; # for api.textmagictesting.com
    ($^O=~/MSWin/)? system('cls'): system('clear');
    
    try {
        $user = $tm->getUserInfo();
    } catch {
        error("Invalid username or token", E_INVALID_CREDENTIALS);
    };
    
    showUserInfo();
    showMainMenu();
}

main();
