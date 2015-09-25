This is the Perl wrapper for the [TextMagic SMS API](https://www.textmagic.com/docs/api/).
TextMagic SMS API is a platform for building your own messaging app using our messaging
infrastructure. It allows you to send and receive SMS text messages, query information about
inbound and outbound messages, manage contacts, create templates (i.e. message formats and
static texts), and schedule recurrent & process bulk SMS messages.

The Perl wrapper for the TextMagic SMS API exposes all methods in the base REST API,
allowing for sending and receiving text messages, and managing chat sessions, setting text
templates, managing contact lists, gathering account statistics, and handling all other
aspects of the TextMagic SMS API.

After downloading the current version of the Perl wrapper, you can install it with the
following commands in the directory where you've downloaded the source:

    perl Makefile.PL 
    make
    make test
    make install

