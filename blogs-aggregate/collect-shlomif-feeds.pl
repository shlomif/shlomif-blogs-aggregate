#!/usr/bin/perl 

use strict;
use warnings;

use Getopt::Long;
use XML::Feed;
use List::Util qw(min);
use Time::HiRes;
use List::MoreUtils qw(any);
use File::Copy qw(copy);

my $rand = 0;

GetOptions('rand' => \$rand);

my %feed_urls=
(
    'homesite' => "http://community.livejournal.com/shlomif_hsite/data/rss",
    'tech' => "http://community.livejournal.com/shlomif_tech/data/rss",
    'linmag' => "http://feeds.feedburner.com/linmagazine/blogs/200",
    'lj' => "http://shlomif.livejournal.com/data/rss",
    'perl' => "http://use.perl.org/~Shlomi%20Fish/journal/rss",
    'flickr' => "http://www.flickr.com/services/feeds/photos_public.gne?id=81969889\@N00&format=rss_200",
    'fc_solve' => "http://fc-solve.blogspot.com/feeds/posts/default?alt=rss",
);

my @collections =
(
    {
        fn => "shlomif-blogs-aggregate",
        feeds => [qw(homesite tech linmag lj perl flickr fc_solve)],
        items => 40,
    },
    {
        fn => "shlomif-english-blogs-aggregate",
        feeds => [qw(homesite tech lj perl fc_solve)],
        items => 20,
    },
    {
        fn => "shlomif-no-photos-blogs-aggregate",
        feeds => [qw(homesite tech lj perl linmag fc_solve)],
        items => 20,
    },
    {
        fn => "shlomif-tech-aggregate",
        feeds => [qw(tech perl fc_solve)],
        items => 10,
    },
    {
        fn => "shlomif-perl-aggregate",
        feeds => [qw(perl tech_with_perl_tag)],
        items => 10,
    },
    {
        fn => "perl-begin",
        feeds => [qw(tech_with_perl_begin perl_begin_cache)],
        items => 10,
    },
    
);

=begin use_perl_org

# Put it if and when use.perl.org is back online.
foreach my $col (@collections)
{
    $col->{'feeds'} = [grep { $_ ne "perl" } @{$col->{'feeds'}}];
}
delete($feed_urls{'perl'});

=end use_perl_org

=cut

sub process_feed
{
    my $feed = shift;

    foreach my $entry ($feed->entries())
    {
        $entry->author("Shlomi Fish ( shlomif\@iglu.org.il )");
    }
}

sub get_feed
{
    my ($id, $url) = @_;

    # Enable to overcome the linmagazine invalid feed.
    return if ($id eq "linmag");

    my $url_feed = XML::Feed->parse(URI->new($url))
        or die "For feed '$url' " . XML::Feed->errstr;

    process_feed($url_feed);

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

# If --rand is specified - sleep for a given time before reading the
# feeds so to not overload the servers simultaneously.
if ($rand)
{
    open my $in, "<", "/dev/urandom";
    my $buf;
    read($in, $buf, 4);
    close($in);
    my $l = unpack("l", $buf);
    Time::HiRes::sleep(($l%7000)/10);
}

while (my ($id, $url) = each(%feed_urls))
{
    $feeds{$id} = get_feed($id,$url);
}

$feeds{'perl_begin_cache'} = XML::Feed->parse("cache/perl-begin.rss");

my $output_format = "RSS";

sub filter_feed_by_category
{
    my $feed = shift;
    my $category= shift;

    my $tech_with_perl_tag = XML::Feed->new($output_format);
    my @entries = grep
        { any { $_ eq $category } ($_->category()) }
        ($feed->entries())
        ;

    foreach my $entry (@entries)
    {
        $tech_with_perl_tag->add_entry($entry);
    }

    return $tech_with_perl_tag;
}

sub filter_feeds_feed
{
    my ($new, $old, $cat) = @_;

    $feeds{$new} = 
        filter_feed_by_category(
            $feeds{$old},
            $cat,
        );
    
    return;
}

filter_feeds_feed("tech_with_perl_tag", "tech", "perl");
filter_feeds_feed("tech_with_perl_begin", "tech", "perl-begin");

foreach my $col (@collections)
{
    # Configuration for this feed.
    my $num_items = $col->{items};
    my $feed_link = "http://www.shlomifish.org/me/blogs/";
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

if (-s "to-upload/perl-begin.xml")
{
    copy("to-upload/perl-begin.xml", "cache/perl-begin.rss");
}

system("bash", "upload.sh");

