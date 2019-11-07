#!/usr/bin/perl

use URI;
use LWP::Simple 'get';

getteamconfs();

sub getteamconfs{
	# <tr role="row"> <td>1</td> <td>North Carolina</td> <td>ACC</td>
	open(FILE, "confs.html" ) || die "Failed to open confs.html";
	open(OUT, ">teamconfs.csv" ) || die "Failed to create teamconfs.csv";
	while( $line=<FILE> ){
		chomp $line;
		($line=~/\<tr/ ) && ( $next="team" );
		if( $next eq "team" && $line=~/[A-Z]/ ) {
			$team=striptd($line);
			$next="conf";
		}
		elsif( $next eq "conf" && $line=~/[A-Z]/ ) {
			$conf=striptd($line);
			$next="done";
			print OUT "$team,$conf\n";
			$teams++;
		}
	}
	close(FILE);
	close(OUT);
	print "Saved $teams teams\n";
}
sub striptd{
	( $s=$_[0] )=~s/^.*\<td\>\s*//;
	$s=~s/\s*\<\/td\>.*$//;
	$s=~s/\&amp;/\&/;
	return uc($s);
}
