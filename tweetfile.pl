#!/usr/bin/perl
#
# (c) John Bokma, 2021
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

use strict;
use warnings;

use Try::Tiny;
use Path::Tiny;
use Getopt::Long;
use Net::Twitter::Lite::WithAPIv1_1;
use Scalar::Util 'blessed';

my $conf_filename;
my $tweets_filename;
my $help    = 0;
my $quiet   = 0;
my $dry_run = 0;
my $first;

GetOptions(
    'conf=s'   => \$conf_filename,
    'tweets=s' => \$tweets_filename,
    'help'     => \$help,
    'quiet'    => \$quiet,
    'dry-run'  => \$dry_run,
    'first'    => \$first,
);

show_usage_and_exit() if $help;

if ( !defined $conf_filename || !defined $tweets_filename ) {
    warn "Error: both --conf and --tweets must be given\n\n";
    show_usage_and_exit( 2 );
}

$quiet or binmode STDOUT, ':encoding(UTF-8)';
$quiet or print "Reading configuration from $conf_filename\n";
my $conf = read_conf( $conf_filename );

$quiet or print "Reading tweets from $tweets_filename\n";
my $tweets = read_tweets( $tweets_filename );

my $count = @$tweets;
$count or die "No tweets found";
$quiet or print "Found $count tweets\n";
my $index = defined $first ? 0 : rand $count;
my $tweet = $tweets->[ $index ];

$quiet or print "Going to tweet:\n\n$tweet\n";
tweet( $conf, $tweet ) unless $dry_run;

sub read_conf {

    my $filename = shift;

    my %conf;
    my @keys = qw( consumer_key consumer_secret
                   access_token access_token_secret );
    my %required;
    @required{ @keys } = ();
    my $fh = path( $filename )->openr_utf8();
    while ( my $line = <$fh> ) {
        chomp $line;
        if ( my ( $key, $value ) = $line =~ /^([a-z_]+)\s*[:=]\s*(\S+)$/ ) {
            exists $required{ $key } or
                die "Unexpected key $key at $filename line $.\n";
            !exists $conf{ $key } or
                die "Duplicate key $key at $filename line $.\n";
            $conf{ $key } = $value;
        }
    }
    exists $conf{ $_ } or die "Missing key $_ at $filename line $.\n"
        for @keys;

    close( $fh );

    return \%conf;
}

sub read_tweets {

    my $filename = shift;
    return [ split /^%\n/m, path( $filename )->slurp_utf8() ];
}

sub tweet {

    my ( $conf, $tweet ) = @_;

    my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
        traits => [ 'API::RESTv1_1' ],
        ssl    => 1,
        %$conf,
    );

    my $result;
    my $error_message;
    try {
        $result = $nt->update( $tweet );
    }
    catch {
        my $error = $_;
        if ( blessed $error and $error->isa( 'Net::Twitter::Lite::Error' ) ) {
            $error_message = $error->message . "\n" . $error->error . "<<<\n";
        }
        else {
            $error_message = $error;
        }
    };
    die $error_message if defined $error_message;

    return;
}

sub show_usage_and_exit {

    my $exit_code = shift // 0;

    print { $exit_code ? *STDERR : *STDOUT } <<'END_USAGE';
NAME
        tweetfile.pl - Posts a random tweet from a file to twitter

SYNOPSIS
        tweetfile.pl [--quiet] [--dry-run] [--first]
            --conf=CONF --tweets=TWEETFILE
        tweetfile.pl --help

DESCRIPTION

        Tweets a single message picked at random from a file given by
        the --tweets argument. In this file, each tweet must be separated by
        a % character on a line by itself.

        The authentication keys and tokens must be made available in a file
        given by the --conf argument. In this file, the following names must
        be available: consumer_key, consumer_secret, access_token, and
        access_token_secret. Each name must be followed by either a : or
        an = character and its value as provided by Twitter.

        The --quiet option prevents the program from printing information
        regarding the progress and which tweet it's going to post.

        The --dry-run option prevents the program from actually posting
        the selected tweet to Twitter. This is useful in testing.

        The --first option picks the first tweet instead of a random one.
        This is useful if you add each new tweet to the top of the file and
        want to manually tweet the first one.

        The --help option shows this information.
END_USAGE

    exit $exit_code;
}

