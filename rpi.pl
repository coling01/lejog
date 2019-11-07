#!/usr/bin/perl

# Slows down a lot but makes no difference :(
#use bignum;

# Calculate RPI for a team based on 
# 25% WL
# 50% of opponents winning percentage ( excluding matches including this team )
# 25% of opponents opponents winning percentage ( excluding matches including this team )

$team=shift(@ARGV);

loadteams();
loadteamresults();
dumpteamsrpi( $team );

sub printfields{
	my ( $position, $team, $wlstring, $wl, $rpi, $sos, $hcrpi, $error )=@_;
	printf( "%4s %-6s %-8s %-8s %-8s %-8s %-8s %-8s\n", $position, $team, $wlstring, $wl, $rpi, $sos, $hcrpi, $error );
}

sub badSubtract{
	$s1="0.588";
	$s2="0.596";
	$diff=$s1 - $s2;
	print "\n";
	print "$s1 $s2 $diff\n";
}

sub round{
	# return nearest(.001, $_[0] );

#	my ($in, $digits)=@_;
#	my $up=int($in*1000);
#	return $up/1000;
	return int($_[0]+0.5);
}

sub loadteams{
	open( FILE, "teams.csv" ) || die "Failed to open team.csv";
	while( $line=<FILE> ){
		chomp $line;
		($position,$teamcode,$name,$rpi)=split(/,/, $line );
		$name=uc($name);
		$teams{$name}=$teamcode;
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

	printfields( "Pos", "Team", "WL", "WL%", "RPI", "SOS", "HCRPI", "ERROR" );
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

sub getteamwl{
	my $team=shift @_;
	my $excluded=shift @_;
	my $wins=0;
	my $losses=0;
	foreach $opp ( sort keys %{$results{$team}} ){
		$wl=$results{$team}{$opp};
		if( $excluded ne "" && $excluded eq $opp ){
			# print "$team excluding $excluded\n";
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
					print "ERROR - Bad WL\n";
					exit;
				}
			}
		}
	}
	return int(0.5+1000*$wins/($wins+$losses));
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
	my $total=0;
	my $count=0;
	foreach $opp ( sort keys %{$results{$team}} ){
		$wl=getteamwl($opp, $team);
		$total+=$wl;
		$count++;
	}
	return int(0.5+$total/$count);
}

sub getopponentsopponentswl{
	my $team=shift @_;
	my $total=0;
	my $count=0;
	foreach $opp ( sort keys %{$results{$team}} ){
		foreach $oppopp ( sort keys %{$results{$opp}} ){
			$wl=getteamwl($oppopp, $team);
			$total+=$wl;
			$count++;
		}
	}
	return int(0.5+$total/$count);
}

sub calcrpi{
	my $position=shift @_;
	my $teamcode=shift @_;

	my $wl=getteamwl($teamcode, "");
	my $wlc=0.25*$wl;
	# print "$teamcode WL:$wl WLC:$wlc\n";

	my $owl=getopponentswl($teamcode);
	my $owlc=0.5*$owl;
	# print "$teamcode OLW:$owl OWLC:$owlc\n";

	my $oowl=getopponentsopponentswl($teamcode);
	my $oowlc=0.25*$oowl;
	# print "$teamcode OOLW:$oowl OOLWC:$oowlc\n";

	my $sos=int(0.5+0.666*$owl + 0.333*$oowl);
	# print "sos:$sos\n";

	$wlstring=getteamwlstring($teamcode);
	$hcrpi=$targetrpi{$teamcode};
	$rpi=int(0.5+$wlc + $owlc + $oowlc);
	$error=$rpi-$hcrpi;
	printfields( $position, $teamcode, $wlstring, $wl, $rpi, $sos, $hcrpi, $error );
}
