#!/usr/bin/perl 

use strict;
use warnings;

use XML::Feed;
use List::Util qw(min);

my %feed_urls=
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

sub get_feed
{
    my ($id, $url) = @_;

    # Enable to overcome the linmagazine invalid feed.
    return if ($id eq "linmag");

    my $url_feed = XML::Feed->parse(URI->new($url))
        or die "For feed '$url' " . XML::Feed->errstr;

    return $url_feed;
}

sub myconvert
{
    my ($feed, $output_format) = @_;
    if (
        (($output_format eq "RSS") && ($feed->format() eq "Atom")) ||
        (($output_format eq "Atom") && ($feed->format() ne "Atom"))
       )
    {
        return $feed->convert($output_format);
    }
    else
    {
        return $feed;
    }
}

my %feeds;

while (my ($id, $url) = each(%feed_urls))
{
    $feeds{$id} = get_feed($id,$url);
}

foreach my $col (@collections)
{
    # Configuration for this feed.
    my $output_format = "RSS";
    my $num_items = $col->{items};
    my $feed_link = "http://shlomif.livejournal.com/";
    my $output_file = "to-upload/$col->{fn}.xml";

    my $total_feed = XML::Feed->new($output_format) or
        die XML::Feed->errstr;

    foreach my $feed_id (@{$col->{feeds}})
    {
        if (defined($feeds{$feed_id}))
        {
            $total_feed->splice(myconvert($feeds{$feed_id}, $output_format));
        }
    }

    my $feed_with_less_items = XML::Feed->new($output_format) or
        die XML::Feed->errstr;

    my @entries = $total_feed->entries();

=begin Removed

    @entries = 
    (grep
        {
            (defined($subj_filter) ? ($_->title() =~ /$subj_filter/) : 1)
                &&
            (defined($subj_filter_out) ? ($_->title() !~ /$subj_filter_out/) : 1)
        }
        @entries
    );

=end

=cut

    @entries = (reverse(sort { $a->issued() <=> $b->issued() } @entries));

    foreach my $e (@entries[0 .. min($num_items-1, $#entries)])
    {
        $feed_with_less_items->add_entry($e);
    }

    $feed_with_less_items->link($feed_link);

    {
        my $out;

        if ($output_file)
        {
            open $out, ">", $output_file;
        }
        else
        {
            open $out, ">&STDOUT";
        }
        binmode $out, ":utf8";
        print {$out} $feed_with_less_items->as_xml();
        close($out);
    }
}

system("bash", "upload.sh");

