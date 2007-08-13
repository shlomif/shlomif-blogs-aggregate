#!/usr/bin/perl 

use strict;
use warnings;

my %feeds=
(
    'homesite' => "http://community.livejournal.com/shlomif_hsite/data/rss",
    'tech' => "http://community.livejournal.com/shlomif_tech/data/rss",
    'linmag' => "http://linmagazine.co.il/blog/feed/200",
    'lj' => "http://shlomif.livejournal.com/data/rss",
    'perl' => "http://use.perl.org/~Shlomi%20Fish/journal/rss",
    'flickr' => "http://www.flickr.com/services/feeds/photos_public.gne?id=81969889\@N00&format=rss_200",
);

my @collections =
(
    {
        fn => "shlomif-blogs-aggregate",
        feeds => [qw(homesite tech linmag lj perl flickr)],
        items => 40,
    },
    {
        fn => "shlomif-english-blogs-aggregate",
        feeds => [qw(homesite tech lj perl)],
        items => 20,
    },
    {
        fn => "shlomif-no-photos-blogs-aggregate",
        feeds => [qw(homesite tech lj perl linmag)],
        items => 20,
    },  
);

sub get_feed_url_param
{
    my $id = shift;

    # Enable to overcome the linmagazine invalid feed.
    return () if ($id eq "linmag");

    my $f = $feeds{$id}; 
    if (!defined($f))
    {
        die "Unknown feed \"$f\"!";
    }
    return ("--url", $f);
}

foreach my $col (@collections)
{
    my @cmd = ("$ENV{HOME}/bin/xml-feed-collect",
        (map { 
                get_feed_url_param($_)
            } @{$col->{feeds}}
        ),
        "-o", "to-upload/$col->{fn}.xml",
        "--num-items=$col->{items}",
        "--feed-link", "http://shlomif.livejournal.com/",
    );
    # print join(" ", (map {"'$_'" } @cmd)), "\n";
    if (system(@cmd))
    {
        die "Could not run aggregator for $col->{fn}!";
    }
}

system("bash", "upload.sh");

