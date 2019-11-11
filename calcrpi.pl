#!/usr/bin/perl

# Calculate RPI for a team based on 
# 25% WL ( sum of wins / sum of wins+losses )
# 50% of OPPSWL ( opponents winning percentage excluding matches including the team being calculated )
# 25% of OPPSOPPSWL ( opponents opponents winning percentage excluding matches including this team being calculated )
$team=shift(@ARGV);

setteamconfs();
loadteams();
loadteamresults();
dumpteamsrpi( $team );
printnewrpi();


sub exiterror{
	print $_[0];
	exit;
}

sub printfields{
	my ( $position, $team, $conf, $wlstring, $wl, $rpi, $sos, $hcrpi, $diff )=@_;
	printf( "%4s %-6s %-14s %-8s %-8s %-8s %-8s %-8s %-8s\n", $position, $team, $conf, $wlstring, $wl, $rpi, $sos, $hcrpi, $diff );
}

sub round{
	return int($_[0]+0.5);
}

sub loadteams{
	open( FILE, "teams.csv" ) || die "Failed to open team.csv";
	while( $line=<FILE> ){
		chomp $line;
		($position,$teamcode,$teamname,$rpi)=split(/,/, $line );
		$teamname=uc($teamname);
		$teamnames{$teamcode}=$teamname;
		$targetrpi{$teamcode}=$rpi*1000;
		push( @teamsbyposition, $teamcode );
	}
	close( FILE );
}

sub loadteamresults{
	opendir(DIR, "results" ) || die "Failed to open results dir";
	while($FILE=readdir(DIR)){
		( $FILE=~/\.csv/ ) || next;
		( $teamcode=$FILE )=~s/\.csv//;
		open(FILE, "results/$FILE" ) || die "Failed to open file results/$FILE\n";
		while( $line=<FILE> ){
			chomp $line;
			storeresults( $teamcode, $line );
		}
		close(FILE);
	}
	closedir( "teams" );
}

sub storeresults{
	# opponent,result
	my $teamcode=shift @_;
	my $line=shift @_;
	my ( $date, $oppcode, $thiswl )=split(/,/, $line );
	if( $thiswl ne "W" && $thiswl ne "L" ){
		print "Skipping unplayed match $date $teamcode $oppcode\n";
		return;
	}
	$results{$teamcode}{$oppcode}.=$thiswl;
}

sub dumpteamsrpi{
	$number=25;
	$team=shift @_;

	printfields( "Pos", "Team", "Conference", "WL", "WL%", "RPI", "SOS", "HCRPI", "DIFF" );
	if($team){
		calcrpi("", $team);
	}
	else{
		for( my $n=0; $n<$number; $n++ ){
			my $team=$teamsbyposition[$n];
			calcrpi($n+1, $team);
		}
	}
}

sub printnewrpi{
	my @sorted = sort {$b->{RPI} <=> $a->{RPI}} @rpiresults;
	my $position=1;
	my %conferences;
	foreach $team ( @sorted ){
		$conf=$$team{"CONF"};
		$n=$conferences{$conf}+1;
		printfields( $position++, $$team{"TEAM"}, $$team{"CONF"}." $n", $$team{"WLSTRING"}, $$team{"WL"}, $$team{"RPI"}, $$team{"SOS"}, $$team{"HCRPI"}, $$team{"DIFF"} );
		$conferences{$conf}=$n;
	}
}

sub getteamwl{
	my $team=shift @_;
	my $exclude=shift @_;
	my $level=shift @_;
	my $wins=0;
	my $losses=0;
my $count=0;
	foreach $opp ( sort keys %{$results{$team}} ){
$count++;
		$wl=$results{$team}{$opp};
		if( $exclude ne "" && $exclude eq $opp ){
			$wl="X";
			# print "$team excluding $exclude\n";
		}
		elsif( $wl eq "" ) {
			print "Error - no WL for $team $opp\n";
			exit;
		}
		else {
			for( $n=0; $n<length($wl); $n++ ){
				my $thiswl=substr($wl, $n, 1 );
				if( $thiswl eq "W" ){
					$wins++;
				}
				elsif( $thiswl eq "L" ){
					$losses++;
				}
				else {
					exiterror "ERROR - Bad WL\n";
				}
			}
		}
		if( $debug ){
			if( $level == 1 ){
				printf( "%10s %6s %6s %10s %10s %4s %3s %3s\n", "WL", $count, $exclude, $team, $opp, $wl, $wins, $losses);
			}
			elsif( $level == 2){
				printf( "%10s %6s %6s %10s %10s %4s %3s %3s\n", "OPPWL", $count, $exclude, $team, $opp, $wl, $wins, $losses);
			}
			elsif( $level == 3){
				printf( "%10s %6s %6s %10s %10s %4s %3s %3s\n", "OPPOPPWL", $count, $exclude, $team, $opp, $wl, $wins, $losses);
			}
			else {
				exiterror "Bad level $level!\n";
	
			}
		}
	}
		
	if( $debug ){	
		printf( "%10s %6s %6s %10s %10s %4s %3s %3s\n", "RESULT", $exclude, $team, $wins, $losses);
	}
	if( $wins+$losses == 0 ) {
		exiterror "ERROR - No wins or losses for $team. Likely bad or missing data\n";
	}
	my %wl=( wins=>$wins, losses=>$losses );
	return %wl;
}


sub getteamwlstring{
	my $team=shift @_;
	my $wins=0;
	my $losses=0;
	foreach $opp ( sort keys %{$results{$team}} ){
		$wl=$results{$team}{$opp};
		if( $wl eq "" ) {
			print "Error - no WL for $team $opp\n";
			exit;
		}
		else {
			for( $n=0; $n<length($wl); $n++ ){
				my $thiswl=substr($wl, $n, 1 );
				if( $thiswl eq "W" ){
					$wins++;
				}
				elsif( $thiswl eq "L" ){
					$losses++;
				}
				else {
					print "ERROR - Bad WL\n";
					exit;
				}
			}
		}
	}
	return "$wins-$losses";
}


sub getopponentswl{
	my $team=shift @_;
	my $wins=0;
	my $losses=0;
	foreach $opp ( sort keys %{$results{$team}} ){
		my %wl=getteamwl($opp, $team, 2);
		$wins+=$wl{"wins"};
		$losses+=$wl{"losses"};
	}
	return $wins/($wins+$losses);
}

sub getopponentsopponentswl{
	my $team=shift @_;
	my $wins=0;
	my $losses=0;
	foreach $opp ( sort keys %{$results{$team}} ){
		foreach $oppopp ( sort keys %{$results{$opp}} ){
			my %wl=getteamwl($oppopp, $team, 3);
			$wins+=$wl{"wins"};
			$losses+=$wl{"losses"};
		}
	}
	return $wins/($wins+$losses);
}

sub calcrpi{
	my $oldposition=shift @_;
	my $teamcode=shift @_;

	( $teamname=$teamnames{$teamcode} ) || die "Failed to find teamname for teamcode:$teamcode\n";
	( $conf=$teamconfs{$teamname} ) || die "Failed to find teamconf for teamname:$teamname\n";
	my %wl=getteamwl($teamcode, "", 1);
	my $wlstring=$wl{"wins"}."-".$wl{"losses"};
	my $wl=$wl{"wins"}/($wl{"wins"}+$wl{"losses"});
	my $wlc=int(0.5+1000*0.25*$wl);
	print "$teamcode WL:$wl WLC:$wlc\n";

	my $owl=getopponentswl($teamcode);
	my $owlc=int(1000*0.5*$owl+0.5);
	print "$teamcode OLW:$owl OWLC:$owlc\n";

	my $oowl=getopponentsopponentswl($teamcode);
	my $oowlc=int(1000*0.25*$oowl+0.5);
	print "$teamcode OOLW:$oowl OOLWC:$oowlc\n";

	my $sos=int(0.5+0.666*$owl + 0.333*$oowl);
	# print "sos:$sos\n";

	$hcrpi=$targetrpi{$teamcode};
	$rpi=int(0.5+$wlc + $owlc + $oowlc);
	$diff=$rpi-$hcrpi;

	saverpi( $oldposition, $teamcode, $conf, $wlstring, $wl, $rpi, $sos, $hcrpi, $diff );
}

sub saverpi{
	my ( $oldposition, $team, $conf, $wlstring, $wl, $rpi, $sos, $hcrpi, $diff )=@_;
	my %result = (
		"OLDPOSITION"=> $oldposition,
		"TEAM"=> $team,
		"CONF"=> $conf,
		"WLSTRING"=> $wlstring,
		"WL"=> $wl,
		"RPI"=> $rpi,
		"SOS"=> $sos,
		"HCRPI"=> $hcrpi,
		"DIFF"=> $diff,
	);
	push( @rpiresults, \%result );
}

sub setteamconfs{
	%teamconfs=(
"NORTH CAROLINA"=>"ACC",
"MARYLAND"=>"BIG TEN",
"VIRGINIA"=>"ACC",
"CONNECTICUT"=>"BIG EAST",
"DUKE"=>"ACC",
"LOUISVILLE"=>"ACC",
"BOSTON COLLEGE"=>"ACC",
"SYRACUSE"=>"ACC",
"PRINCETON"=>"IVY LEAGUE",
"IOWA"=>"BIG TEN",
"DELAWARE"=>"CAA",
"MICHIGAN"=>"BIG TEN",
"SAINT JOSEPH'S"=>"ATLANTIC 10",
"NORTHWESTERN"=>"BIG TEN",
"OLD DOMINION"=>"BIG EAST",
"RUTGERS"=>"BIG TEN",
"HARVARD"=>"IVY LEAGUE",
"STANFORD"=>"AMERICA EAST",
"WAKE FOREST"=>"ACC",
"LIBERTY"=>"BIG EAST",
"MONMOUTH"=>"AMERICA EAST",
"WILLIAM & MARY"=>"CAA",
"OHIO STATE"=>"BIG TEN",
"PENN STATE"=>"BIG TEN",
"CORNELL"=>"IVY LEAGUE",
"FAIRFIELD"=>"NEC",
"PROVIDENCE"=>"BIG EAST",
"AMERICAN"=>"PATRIOT",
"JAMES MADISON"=>"CAA",
"ALBANY (NY)"=>"AMERICA EAST",
"LAFAYETTE"=>"PATRIOT",
"RICHMOND"=>"ATLANTIC 10",
"PENN"=>"IVY LEAGUE",
"KENT ST."=>"MAC",
"NEW HAMPSHIRE"=>"AMERICA EAST",
"MICHIGAN ST."=>"BIG TEN",
"NORTHEASTERN"=>"CAA",
"MASSACHUSETTS"=>"ATLANTIC 10",
"CALIFORNIA"=>"AMERICA EAST",
"MIAMI (OH)"=>"MAC",
"MAINE"=>"AMERICA EAST",
"UC DAVIS"=>"AMERICA EAST",
"COLUMBIA"=>"IVY LEAGUE",
"UMASS LOWELL"=>"AMERICA EAST",
"BOSTON U."=>"PATRIOT",
"BUCKNELL"=>"PATRIOT",
"VCU"=>"ATLANTIC 10",
"VILLANOVA"=>"BIG EAST",
"RIDER"=>"NEC",
"LOCK HAVEN"=>"ATLANTIC 10",
"APPALACHIAN ST."=>"MAC",
"OHIO"=>"MAC",
"INDIANA"=>"BIG TEN",
"LONGWOOD"=>"MAC",
"VERMONT"=>"AMERICA EAST",
"TEMPLE"=>"BIG EAST",
"DREXEL"=>"CAA",
"YALE"=>"IVY LEAGUE",
"HOFSTRA"=>"CAA",
"BROWN"=>"IVY LEAGUE",
"QUINNIPIAC"=>"BIG EAST",
"GEORGETOWN"=>"BIG EAST",
"DARTMOUTH"=>"IVY LEAGUE",
"BALL ST."=>"MAC",
"LIU"=>"NEC",
"HOLY CROSS"=>"PATRIOT",
"SAINT FRANCIS (PA)"=>"ATLANTIC 10",
"LA SALLE"=>"ATLANTIC 10",
"LEHIGH"=>"PATRIOT",
"TOWSON"=>"CAA",
"SACRED HEART"=>"NEC",
"COLGATE"=>"PATRIOT",
"DAVIDSON"=>"ATLANTIC 10",
"CENTRAL MICH."=>"MAC",
"WAGNER"=>"NEC",
"BRYANT"=>"NEC",
"MERRIMACK"=>"NEC",
"SAINT LOUIS"=>"ATLANTIC 10",
);
}
