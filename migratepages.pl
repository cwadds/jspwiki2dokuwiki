#!/usr/bin/perl -w
#
# migratepages.pl
#
# Author: Conrad Wadds<conrad at wadds dot net dot au>
#
# This script is intended to migrate an existing JSPWiki to an existing Dokuwiki
#
# The input directory is (a copy of) the directory from which JSPWiki deploys/maintains its pages
# The output directory is (a copy of) the pages directory for Dokuwiki
#
# usage example: <path-to>/migrate.pl /opt/jspwikiroot /opt/dokuwiki/data/pages
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
use strict;

my $link  = '';
my %page  = ();
my %links = ();
my $newpage = '';
my ($apache_uid, $apache_gid) = (getpwnam('apache'))[2,3];
my $indir  = shift or die "what directory to process?\n";
my $outdir = shift or die "what directory to output?\n";

# This string contains all of the likely non-image, non-page link extensions.
# You may add to it if this does not cater for enough extensions.
my $matchstr="(avi|bat|bmml|doc|docm|docx|exe|gz|htm|html|ini|jar|jgp|jpeg|lnk|mov|mp4|pdf|pfx|ppsx|ppt|pptx|properties|ren|rpm|rtf|sxw|txt|vbs|vdx|vsd|vss|war|wgx|xls|xlsx|xml|xsd|zip)";

# Collect page links
#
foreach (<$indir/*txt>) {
    my $filein = $_;
    $page{$_} = 1;

    open INFILE, "< $filein" or die "cannot open $filein: $?\n";

    while (<INFILE>) {
        next unless /\]/;

        my $tag = '';
        my $rest = '';
        $link = '';
        my $tstlnk = '';

        # Links
        ($link) = m/\[ [^\]^\|]* \| (.*) \]/x;
        ($link) = m/\[ ( [^\]]* ) \]/x unless $link;

        next unless $link;

        $link =~ s/\'/ /g;
        $link =~ s/\"/ /g;

	# Create a dokuwiki style page name
        $newpage =  "$link";
        $newpage =~ y/A-Z/a-z/;	# Lowercase
        $newpage =~ s/\ /_/g;	# Spaces become underscores
        $newpage =~ s/\)//g;	# Throw away left and right parentheses
        $newpage =~ s/\(//g;
        $newpage =~ s/\%28//g;	# JSPWiki (some version of) seems to 
        $newpage =~ s/\%29//g;	# encode parentheses
        $newpage =~ s/\&\_//g;	# Remove ampersand + underscore
        $newpage =~ s/\&//g;	# or just ampersand
        $newpage =~ s/\%26_//g;	# or encoded ampersand + underscore
        $newpage =~ s/\%26//g;	# or just encoded ampersand
        $newpage =~ s/__/_/g;	# Merge multiple underscores into one

	# Lowercase to assist searching
	$link =~ y/A-Z/a-z/;

	# Create JSPWiki style page links and store
	# the new page in the associative array.
        $tstlnk =  $link;
        $tstlnk =~ s/\ /\+/g;	# JSPWiki uses plus symbols to replace spaces
        $links{$tstlnk} = $newpage;

        $tstlnk =  $link;
        $tstlnk =~ s/\ //g;	# but sometimes just throws away spaces
        $links{$tstlnk} = $newpage;
    }
    close INFILE;
}

# For each page we have read in the above link search
foreach my $filein (sort keys %page) {
    my $outfile = '';
    # Retrieve the original file modification time
    my $ftime = (stat $filein)[9];

    $newpage = $filein;
    $newpage =~ s/$indir\/(.*).txt$/$1/;	# Strip off directory and trailing ".txt"
    $newpage =~ s/\%28/\(/g;	# Unencoded parentheses
    $newpage =~ s/\%29/\)/g;
    $newpage =~ s/\%26_//g;	# Strip away encoded ampersands
    $newpage =~ s/\%26\+//g;
    $newpage =~ s/\%26//g;
    $newpage =~ y/A-Z/a-z/;	# And lowercase

    # Check for an already defined output page name
    if ( defined $links{$newpage} ) {
        $outfile = $links{$newpage};
    } else {
	# Or just perform minimal transform
        $newpage =~ y/A-Z/a-z/;
        $newpage =~ s/\ /_/g;
        $newpage =~ s/\+/_/g;
        $outfile = $newpage;
    }

    # Display a page name to the screen.
    print STDOUT "$outfile\n";

    $outfile = "$outdir/$outfile.txt";

    open INFILE,  "< $filein"  or die "cannot open $filein: $?\n";
    open OUTFILE, "> $outfile" or die "cannot open $outfile: $?\n";

    # Ensure our output ends up in the correct place
    select OUTFILE;

    # For each line in the file,
    # perform all the appropriate transforms
    while (<INFILE>) {
        my $tag = '';
        my $rest = '';
        my $ext = '';
        my $tst = '';
        $link = '';

        # Remove any CR or CR/LF characters
        s/\r//;
        chomp;

        # Table of contents is not required in Dokuwiki
        next if m/\{\s*TableOfContents\s*\}/i;

        # Code
        s/\{\{\{/<code>/g;
        s/\}\}\}/<\/code>/g;

        # Monospaced
        s/\{\{/\'\'/g;
        s/\}\}/\'\'/g;

        # Links
        s/(\[[^\]]*\])/\[$1\]/g;

        # Swap aliased links
        s/\[\[([^\|]*)\|([^\]]*)\]\]/\[\[$2\|$1\]\]/g;

        # Headings
        if (($tag, $rest) = /^(\!+)(.*)/) {
            $tag = (length($tag) + 2);
            $tag = "=" x $tag;
            $_ = "$tag$rest $tag";

            # Fixup for links in headings
            if (/\[\[/) {
	        ($link) = m/(\[\[.*\]\])/;
		if ($link =~ /\|/) {
		    ($rest, $tag) = ($link =~ m/\[\[ ( [^\|]+ ) \| ( [^\]]+ ) \]\]/x);
		    s/$rest\s*\|//g;
		}
	        s/\[\[//g;
	        s/\]\]//g;
            }
        }

        # Links to non-page, non-image files (JSPWiki handles these like a page)
        if (/\[\[/) {
            ($ext) = m/\[\[ ( [^\]^\|]* ) \| .* \]\]/x;
            ($ext) = m/\[ ( [^\]]* ) \]/x unless $ext;
	    ($tst) = ($ext =~ m/.*\.([^\.]*)$/);
	    if ($tst and $tst =~ m/$matchstr/) {
	        s/\[\[/\{\{/;
		s/\]\]/\}\}/;
	    }
	}

        # Bulletted list
        if (($tag, $rest) = /^(\*+)(.*)/) {
            $tag = ("  " x length($tag)) . "*";
            $_ =  "$tag$rest";
        }

        # Numbered list
        if (($tag, $rest) = /^(\#+)(.*)/) {
            $tag = ("  " x length($tag)) . "-";
            $_ =  "$tag$rest";
        }

        # Italic
        s/\'\'/\/\//g;

        # Bold
        s/__([^_]*)__/**$1**/g;

        # Image link in JSPWiki
        if ( m/\[\{Image/ ) {
            s/\[\{Image src=\'/\{\{:/;
            s/(\.(gif|png|jpg|jpeg)\').*\}\]/$1\}\}/i;
        }

	# JSPWiki 'file:\\' type shares
	s/\[\[file:\\\\/\[\[\\\\/g;

        # Tables require a closing "|"
        if (/^\|/) {
            $_ .= '|';
        }

        # Table headings
        if (/\|\|/) {
            s/\|\|/\^/g;
            s/$/\|/ if not /\|$/;
        }

        # Strikethrough/deleted
        s/\%\%\(text-decoration: line-through;\)([^\%]*)\%\%/<del>$1<\/del>/g;

        # Output the result
        print "$_\n";
	print "$link\n" if $link;
    }

    close OUTFILE;
    close INFILE;

    # Change ownership to apache:apache to enable editing
    chown($apache_uid, $apache_gid, $outfile);
    # Maintain the original datetime stamp
    utime($ftime, $ftime, $outfile);
}
# All done