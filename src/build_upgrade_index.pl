#!/usr/bin/perl -w

# reads files on command line can copies them to
# the upgrade area in the current directory.

use strict;
use FindBin;
use Cwd;

# The bk repository where this script is found
my $bkdir = "$FindBin::Bin/..";

my($version) = shift(@ARGV);

my($utc);
$utc = `bk prs -hd:UTC: -r$version $bkdir/ChangeSet`;
die "Can't find version $version in $bkdir\n" unless $utc;

my($file, $md5sum, $platform);
my(%seen);

open(I, ">INDEX") or die "Can't open INDEX file: $!";
print I "# file,md5sum,ver,utc,platform,unused\n";
foreach $file (@ARGV) {
    my($base);
    ($base = $file) =~ s/.*\///;

    system("bk crypto -e $FindBin::Bin/bkupgrade.key < $file > $base");
    die "encryption of $file to $base failed" unless $? == 0;
    chomp($md5sum = `bk crypto -h - < $base`);
    die "hash of $base failed" unless $md5sum;
    
    # parse bk install binary filename
    #   VERSION-PLATFORM.{bin,exe}
    ($platform) = ($base =~ /^$version-(.*)\./);
    die "Can't include $base, all images must be from $version\n"
	unless $platform;
    
    if ($seen{$platform}) {
	die "Only 1 installer for each platform: $base\n";
    }
    $seen{$platform} = 1;

    print I join(",", $base, $md5sum, $version, $utc, $platform, "bk");
    print I "\n";
    
}

my $olddir = getcwd;
my $base;
my %obsoletes;

# find which releases are obsoleted by the current versions

chdir $bkdir || die "Can't chdir to $bkdir: $!";
   
$base = `bk r2c -r1.1 src/upgrade.c 2> /dev/null`;
die if $? != 0;  # no upgrade command
chomp($base);

$_ = `bk set -d -r$base -r$version -tt 2> /dev/null`;
die if $? != 0;  # version doesn't exist in this release
	
foreach (split(/\n/, $_)) {
    $obsoletes{$_} = 1;
}
chdir $olddir;

foreach (sort keys %obsoletes) {
    print I "old $_\n";
}
print I "\n# checksum\n";
close(I);
my $sum = `bk crypto -h - 'WXVTpmDYN1GusoFq5hkAoA' < INDEX`;
open(I, ">>INDEX") or die "Can't append to INDEX: $!";
print I $sum;
close(I);
    
    
    