#!/usr/bin/perl -w
#
# migratemedia.pl
#
# Author: Conrad Wadds<conrad at wadds dot net dot au>
#
# This script is intended to assist in migrating an existing JSPWiki to an existing Dokuwiki
#
# The input directory is (a copy of) the directory from which JSPWiki deploys/maintains its pages
# The output directory is (a copy of) the pages directory for Dokuwiki
#
# usage example: <path-to>/migratemedia.pl /opt/jspwikiroot /opt/dokuwiki/data/pages
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
#
use strict;

sub processFile($$$$$);
sub mangle($);

# Command for Unix/Linux
my $copycmd = "/bin/cp --force --preserve ";

# Command for Windows (?)
# my $copycmd = "COPY /Y "

my %att = ();
my $ext = '';
my $newpage = '';
my $firsttime = '1';
my $dir = '';
my $page = '';
my $file = '';
my $gen = '';
my $outfile = '';
my $lastdir = '';
my $lastpage = '';
my $lastfile = '';
my $lastext = '';
my $lastgen = '';
my $processed = 0;

my ($apache_uid, $apache_gid) = (getpwnam('apache'))[2,3];
my $indir  = shift or die "what directory to process?\n";
my $outdir = shift or die "what directory to output?\n";

# JSPWiki attachments have the format:
# <WikiRoot>/<PageName>-att/<NameOfFile>-dir/<GenerationNumber>.extension
# Where: PageName is the wiki name of the page the file is attached to
#        NameOfFile is the name of the file attached
#        GenerationNumber is a decimal number of the file generation
#        EG: if the attached file has been updated twice after the 
#            initial attachement and is a zip file: 3.zip
#
print "Collecting all attachments.\n";
my @attachment = (<$indir/*-att/*-dir/[0-9]*>);
my $attachments = @attachment;

print "Processing $attachments attachments.\n";
foreach (@attachment) {
    # Split the filename into components
    ($dir, $page, $file, $gen) = ($_ =~ m#(.*)/(.*)-att/(.*)-dir/(.*)#);
    # and extract the attachment suffix.
    ($ext) = ($gen =~ m/.*\.([^\.]*)$/);

    if ( $firsttime ) {
        $firsttime = 0;
        $lastdir  = $dir;
        $lastpage = $page;
        $lastfile = $file;
        $lastgen  = $gen;
        $lastext  = $ext;
    }

    if ($lastfile ne $file) {
        print ".";
        $processed++;
        processFile($lastdir, $lastpage, $lastfile, $lastgen, $lastext);
        %att = ();
        $lastdir  = $dir;
        $lastpage = $page;
        $lastfile = $file;
        $lastgen  = $gen;
        $lastext  = $ext;
    }

    $gen =~ s/\.$ext//;
    $att{$gen} = $file;
}
print "\n";
processFile($lastdir, $lastpage, $lastfile, $lastgen, $lastext);

++$processed;
print "Migrated $processed attachments.\n";

# Guts of the script
sub processFile($$$$$) {
    my $lastdir  = shift;
    my $lastpage = shift;
    local $_     = shift;
    my $lastgen  = shift;
    my $lastext  = shift;
    my $fname = '';
    my $infile = '';

    # Obtain the hightest numbered attachement
    foreach (sort rnum keys %att) {
        $fname = "$_.$lastext";
        last;
    }
    # Re-assemble to input filename
    $infile =  "$lastdir/$lastpage-att/$lastfile-dir/$fname";

    # Create an output filename
    $outfile = mangle($lastfile);
    $outfile = "$outdir/$outfile";

    # Copy the file from old dir/fname to new dir/fname
    # (Hopefully) maintaining ownership, permissions and timestamps
    my $cmd = "$copycmd $infile $outfile";

    if (my $result = `$cmd`) {
        die "cannot copy $lastfile: $result\n";
    }

    # Change ownership to apache:apache to enable editing
    chown($apache_uid, $apache_gid, $outfile);
}

#
# Reverse numeric sort subroutime
#
sub rnum { $b <=> $a; }

#
# Mangle the filename to strip out
# crud and lowercase the result.
# This should give us a Dokuwiki style name
#
sub mangle($) {
    local $_ = shift;

    s/\+/_/g;
    s/\s/_/g;
    s/\%28//g;
    s/\%29//g;
    s/\%26//g;
    s/__/_/g;
    y/A-Z/a-z/;

    return $_;
}