#!/usr/bin/perl
# 
# Script that will pull down the teams list ( into teams.csv ) and each teams result file ( into results folder )
# Will skip any teams that already have a file in the results folder.
# Thus ... To refresh the team(s) results, remove the file(s) from the results folder
#
use URI;
use LWP::Simple 'get';

getteams();
loadteams();
getteamfiles();

sub getteams{
	( -f "teams.csv" ) && return;
	my $url="http://www.fieldhockeycorner.com/ratings.php?div=1&col=rpi&display_region=";
	my $content = get($url) or die "Failed to access URL";

	# <tr align=center><td>1</td><td align=left><a href='/scores.php?action=schedule&tcode=UNC&div=1'>North Carolina</a></td><td>17-0</td><td>  100.0</td><td>0.742</td><td>0.692</td></tr>
	open( OUT, ">teams.csv" ) || die "Failed to create teams.csv";
	foreach $line ( split( /\n/, $content ) ){
		( $line=~/tcode/ ) || next;
		( $teamcode=$line )=~s/.*\&tcode=//;
		$teamcode=~s/\&.*$//;

        	( $name=$line )=~s/^.*\'>//;
       		 $name=~s/\<.*$//;

        	@split=split('<td>', $line );
        	( $position=$split[1] )=~s/\<\/td\>//;
		$position=~s/\<td.*$//;
		
        	( $rpi=$split[4] )=~s/\<\/td\>//;
		print OUT "$position,".uc($teamcode).",".uc($name).",$rpi\n";
	}
	close(OUT);
}

sub loadteams{
	open(FILE, "teams.csv" ) || die "Failed to open teams.csv";
	while( $line=<FILE> ){
		chomp $line;
		my ( $position, $teamcode, $teamname )=split( /,/, $line );
		push(@teamcodes, $teamcode );
		$teamcodes{$teamname}=$teamcode;
		$teamnames{$teamcode}=$teamname;
	}
	close( FILE );
}

sub getteamfiles{
	( -d "results" ) || mkdir( "results" );
	for $teamcode ( @teamcodes ){
		if( ! -f "results/$teamcode.csv" ){
			print "Getting team:$teamcode\n";
			my $url="http://www.fieldhockeycorner.com/scores.php?action=schedule&tcode=$teamcode&div=1";
			my $content = get($url) or die "Failed to access URL";
			foreach $line ( split( /\n/, $content ) ){
				storeresult( $teamcode, $line );
			}
		}
	}
}

sub storeresult{
	# <tr><td>Oct. 5</td><td>vs. UC Davis</td><td>W, 1-0</td><td>at Iowa</td></tr>
 	# <tr><td>Sep. 6</td><td>at Albany</td><td>W, 2-1 (OT)</td><td>&nbsp;</td></tr>
	# <tr><td>Sep. 8</td><td>at Connecticut</td><td>L,&nbsp; 0-3</td><td>&nbsp;</td></tr>
	# <tr><td>Aug. 31</td><td>vs. Miami</td><td>W, 2-0</td><td>at Delaware</td></tr>
	my $teamcode=shift @_;
	my $line=shift @_;

	if($line!~/Aug/ &&  $line!~/Sep/ && $line!~/Oct/ && $line!~/Nov/ ){
		return;
	}
	if( $line=~/\<td\>W/ ){
		$thiswl="W";
	}
	elsif( $line=~/\<td\>L/ ){
		$thiswl="L";
	}
	else {
		$thiswl="?";
	}
	
	@split=split('<td>', $line );
	( $date=$split[1] )=~s/\<\/td\>//;
	( $opponent=$split[2] )=~s/\<\/td\>//;
	$opponent=~s/vs. //;
	$opponent=~s/at //;
	$opponent=~s/\<b\>//;
	$opponent=~s/\<\/b\>//;
	$opponent=uc($opponent);
	$oppcode=$teamcodes{$opponent};
	if( ! $oppcode ){
		print "Error no tcode found for team opponent:$opponent!\n";
		exit;
	}
	open( OUT, ">>results/$teamcode.csv" ) || die "Failed to append to $teamcode.csv";
	print OUT "$date,$oppcode,$thiswl\n";
	close( OUT );
}
