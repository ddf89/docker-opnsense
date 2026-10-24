#!/usr/bin/env perl

use strict;
use warnings;
use XML::Simple;
use LWP::Simple;
use File::Basename;
use File::Spec;

my $url = "https://raw.githubusercontent.com/opnsense/core/master/src/opnsense/mvc/app/models/OPNsense/Core/repositories/opnsense.xml";
my $mirrors_file   = File::Spec->catfile(dirname(__FILE__), 'src', 'mirrors.txt');
my $exclusion_file = File::Spec->catfile(dirname(__FILE__), 'src', 'exclusions.txt');

sub normalize {
    my $u = shift;
    $u =~ s/^\s+|\s+$//g;
    $u .= '/' unless $u =~ m{/$};
    return $u;
}

my %excluded;
if (-e $exclusion_file) {
    open(my $efh, '<', $exclusion_file)
        or die "Could not open file '$exclusion_file' $!";
    while (my $line = <$efh>) {
        chomp $line;
        $line =~ s/\r$//;
        next if $line =~ /^\s*(#|$)/;
    }
    close $efh;
}

my $xml  = get($url) or die "Could not fetch $url";
my $data = XMLin($xml);

open(my $fh, '>', $mirrors_file) or die "Could not open file '$mirrors_file' $!";
for my $mirror (@{$data->{mirrors}->{mirror}}) {
    next if ref $mirror->{url};
    my $mirror_url = normalize($mirror->{url});
    next if $excluded{$mirror_url};
    print $fh "$mirror_url\n";
}
close $fh;
