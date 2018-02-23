#!/usr/local/bin/perl5
#=--------------------------------------=
#  Quizbot - qwizplayer.pm
#  Copyright (C) Ed Halley and other authors.
#
#  This program is free software. You may use, modify, and distribute it
#  under the terms of the Perl Artistic license, avialible on the world
#  wide web at:
#  http://www.perl.com/pub/a/language/misc/Artistic.html
#  and included in the file LICENSE.
#
# $Id: $
#
#=--------------------------------------=

#----------------------------------------------------------------------------

# team information
# Special case: team "1" is not Onyx, but the default unteam.

# This is overridden by the options file.

@teamname = qw(Pearl Onyx Bruisers Emerald Fireball Ruby Royal Sizzle Yellowjackets Nuclear Money Frostbite Bluestreak Hotstuff Shadowdance Silver);
@teamopen =   (0,    0,   0,       0,      0,       0,   0,    0,     0,            0,      0,    0,        0,         0,       0,          0     );
@teamwins =   (0,    0,   0,       0,      0,       0,   0,    0,     0,            0,      0,    0,        0,         0,       0,          0     );
@teamseas =   (0,    0,   0,       0,      0,       0,   0,    0,     0,            0,      0,    0,        0,         0,       0,          0     );

#----------------------------------------------------------------------------

%players = ();
%active = ();
%warns = ();
%authed = ();
%authfails = ();
@bans = ();

$nMeanQueueLength = 10;

# player persistent info consists of:
	$sNick					=	0;
	$sMask					=	1;
	$nRank					=	2;
	$nTeam					=	3;
	$sFlags					=	4;
	$tWhenMet				=	5;
	$tWhenSeen				=	6;
	$nTimesKicked			=	7;

	$nTimesWon				=	8;
	$tWhenLastWon			=	9;
	$sSpeedBestWon			=	10;
	$nBestStreakWon			=	11;

	$nTimesWonPeriod		=	12;
	$nTimesAskedPeriod		=	13;
	$sSpeedBestWonPeriod	=	14;
	$nBestStreakWonPeriod	=	15;

	$nTimesWonSeason		=	16;
	$nTimesAskedSeason		=	17;
	$sSpeedBestWonSeason	=	18;
	$nBestStreakWonSeason	=	19;

	$sLastSaid				=	20;
	$nTimesSaid				=	21;
	$tWhenLastSaid			=	22;
	$nSubmissions			=	23;

	$tWhenLastCategory		=	24;
	$nBonusPoints			=	25;
	$sPersonalStats			=	26;
	$sPersonalEmail			=	27; $sPersonalURL = 27;

	$nTimesFinishedSecond	=	28;
	$sMeanSpeedQueue		=	29;
	$sSupportCaptain		=	30;
	$sAuthPassword			=	31;
	
	$nPlayerPersistentInfo	=	31;##

@playerfieldnames =
	("Nick", "Mask", "Rank", "Team", "Flags", "First Joined", "Last Seen", "Times Kicked",
	 "Times Won", "When Last Won", "Fastest Win", "Best Streak",
	 "Times Won This Period", "When Last Won This Period", "Fastest Win This Period", "Best Streak This Period",
	 "Times Won This Season", "When Last Won This Season", "Fastest Win This Season", "Best Streak This Season",
	 "Last Thing Said", "Times Repeated Self", "When Last Said", "Questions Submitted",
	 "When Last Categoried", "TriviaBucks", "Personal Stats", "Personal Email",
	 "Times Finished Second", "Mean Speed for Wins", "Who Supported", "Authorization");
@playerfieldnumeric =
	(0, 0, 1, 1, 0, 1, 1, 1,
	 1, 1, 1, 1,
	 1, 1, 1, 1,
	 1, 1, 1, 1,
	 0, 1, 1, 1,
	 1, 1, 0, 0,
	 1, 1, 0, 1);
@playerfieldpublic =
	(1, 0, 1, 1, 0, 1, 1, 0,
	 1, 1, 1, 1,
	 1, 1, 1, 1,
	 1, 1, 1, 1,
	 0, 0, 0, 1,
	 0, 1, 0, 0,
	 1, 0, 0, 0);
@playerfieldtime =
	(0, 0, 0, 0, 0, 1, 1, 0,
	 0, 1, 0, 0,
	 0, 1, 0, 0,
	 0, 1, 0, 0,
	 0, 0, 1, 0,
	 1, 0, 0, 0,
	 0, 0, 0, 0);
@playerfieldtimespan =
	(0, 0, 0, 0, 0, 0, 0, 0,
	 0, 0, 1, 0,
	 0, 0, 1, 0,
	 0, 0, 1, 0,
	 0, 0, 0, 0,
	 0, 0, 0, 0,
	 0, 0, 0, 0);
@playerfieldmeanqueue =
	(0, 0, 0, 0, 0, 0, 0, 0,
	 0, 0, 0, 0,
	 0, 0, 0, 0,
	 0, 0, 0, 0,
	 0, 0, 0, 0,
	 0, 0, 0, 0,
	 0, 1, 0, 0);

@newplayer =
	('(nobody)', '(nowhere@nohost)', 0, 1, '', 0, 0, 0,
	 0, 0, 99999, 0,
	 0, 0, 99999, 0,
	 0, 0, 99999, 0,
	 '(nothing)', 0, 0, 0,
	 0, 0, '(0/i/nowhere)', '(noname@nohost)',
	 0, '', '(nobody)', '');

#----------------------------------------------------------------------------

%rankname =
	(0		=> 'beginner',
	 1		=> 'freshman',
	 3		=> 'sophomore',
	 5		=> 'journeyman',
	 7		=> 'junior',
	 10		=> 'habitual',
	 15		=> 'senior',
	 20		=> 'obsessive',
	 25		=> 'lunatic',
	 30		=> 'compulsive',
	 35		=> 'deranged',
	 40		=> 'dependent',
	 50		=> 'resident',
	 60		=> 'addict',
	 70		=> 'certifiable',
	 80		=> 'pathological',
	 90		=> 'schizophrenic',
	 100	=> 'looney',
	 110	=> 'homosexual',
	 120	=> 'crackhead',
	 130	=> 'wacko',
	 150	=> 'maniac',
	 175	=> 'beserk',
	 200	=> 'crackers',
	 225	=> 'cuckoo',
	 250	=> 'screwball',
	 275	=> 'frenzied',
	 300	=> 'disturbed',
	 325	=> 'unbelievable',
	 350	=> 'preposterous',
	 375	=> 'outrageous',
	 400	=> 'impossible',
	 450	=> 'automaton',
	 500	=> 'zombie'
	);

%rankstripes =
	(0		=> 'buck',
	 1		=> 'green',
	 2		=> 'practiced',
	 3		=> 'experienced',
	 4		=> 'seasoned',
	 5		=> 'veteran',
	 6		=> 'grizzled',
	 7		=> 'special',
	 8		=> 'expert',
	 9		=> 'ninja'
	);

#----------------------------------------------------------------------------

sub isplayer
{
	local($nick) = @_;
	$nick = lc($nick);
	if ($nick ne '' && defined($players{$nick}))
		{ return 1; }
	0;
}

sub isactive
{
	local($nick) = @_;
	$nick = lc($nick);
	if ($nick ne '' && defined($active{lc($nick)}))
		{ return 1; }
	0;
}

sub getplayer
{
	local($nick) = @_;
	$nick = lc($nick);
	split(/:/, $players{$nick});
}

sub setplayer
{
	local(@player) = @_;
	my $nick = lc($player[$sNick]);

	if ($#player > $nPlayerPersistentInfo)
	{
		my ($package, $filename, $line) = caller;
		print "----> setplayer called with invalid \@player ($player[$sNick]) from $package:$filename:$line\n";
	}

	$players{$nick} = join(':', @player);
}

#----------------------------------------------------------------------------

sub writeplayersbyflag
{
	local($file, $withflag, $withoutflag) = @_;

	my $now = time();

	foreach $nick (sort keys %players)
	{
		if ($nick eq '') { next; }
		my @player = getplayer($nick);


		if ($withoutflag ne '' && $player[$sFlags] =~ /$withoutflag/)
			{ next; }

		if ($withflag ne '' && $player[$sFlags] !~ /$withflag/)
			{ next; }


		# delete flyby (never won, never friended, never kicked, never setpassed) players
		#
		if (!isactive($nick) &&
		    ($player[$nTimesWon] == 0) &&
			($player[$sFlags] eq '') &&
			($player[$nTimesKicked] == 0) &&
			($player[$sAuthPassword] eq ''))
		{
			delete $players{lc($nick)};
			print "** Flyby $nick deleted.\n";
			next;
		}

		# delete ancient (4 month, not op) players
		#
		if (!isactive($nick) &&
		    ($player[$sFlags] !~ /[omw*]/) &&
			($player[$tWhenSeen] < ($now - (144 * 60*60*24* 31 )))) # 124days
		{
			delete $players{lc($nick)};
			print "** Ancient $nick deleted.\n";
			next;
		}

		# delete ancient (2 month, not expert played) players
		#
		if (!isactive($nick) &&
		    ($player[$nTimesWon] < 200) &&
			($player[$sFlags] !~ /[omw*]/) &&
			($player[$tWhenSeen] < ($now - (122 * 60*60*24* 31 )))) # 62days
		{
			delete $players{lc($nick)};
			print "** Ancient $nick deleted.\n";
			next;
		}

		# delete ancient (1 month, hardly played) players
		#
		if (!isactive($nick) &&
		    ($player[$nTimesWon] < 20) &&
			($player[$sFlags] !~ /[omw*]/) &&
			($player[$tWhenSeen] < ($now - (60*60*24* 31 )))) # 31days
		{
			delete $players{lc($nick)};
			print "** Ancient $nick deleted.\n";
			next;
		}

		# kick slacker (1 week unheard) players off their team
		#
		if (!isactive($nick) &&
			($player[$nTeam] != 1) &&
			($player[$tWhenSeen] < ($now - (60*60*24* 7 )))) # 7days
		{
			print "** Slacker $nick kicked off team $teamname[$player[$nTeam]].\n";
			$player[$nTeam] = 1;
			setplayer(@player);
		}

		# save player
		#
		print $file $players{$nick} . "\n";
	}

}

sub writeplayers
{
	open(INFO, ">$playerfile.new") || return;

	my $now = localtime();
	print INFO "# saved $now\n";

	print INFO "\n\# players\n";
	writeplayersbyflag(INFO, '', '[*od]');

	print INFO "\n\# operators\n";
	writeplayersbyflag(INFO, 'o', '[*d]');

	print INFO "\n\# blacklist\n";
	writeplayersbyflag(INFO, '\*', '[od]');

	print INFO "\n\# service bots\n";
	writeplayersbyflag(INFO, 'd', '[*o]');

	close(INFO);

	$now = time();
	if ($tWhenLastBackup + $nBackupSpan <= $now)
	{
		rename("$playerfile", "$playerfile.$now.txt");
		$tWhenLastBackup = $now;
		$now = localtime($now);
		print "!! Made backup of players at $now\n";
	}
	else
	{
		unlink("$playerfile.bak");
		rename("$playerfile", "$playerfile.bak");
	}
	rename("$playerfile.new", "$playerfile");
}

sub readplayers
{
	open(INFO, $playerfile) || return;
	@playerlist = <INFO>;
	close(INFO);

	my $count = 0;
	my $now = time();
	%players = ();
	foreach $playerline (@playerlist)
	{
		$playerline =~ s/\n//;
		$playerline =~ s/\r//;
		if ($playerline eq '') { next; }
		if ($playerline =~ /^\s*#/) { next; }

		my @player = split(/:/, $playerline);
		while (!defined($player[$nPlayerPersistentInfo]))
		{
			$player[$#player+1] = $newplayer[$#player+1];
		}
		if ($player[$tWhenMet] <= 1)
			{ $player[$tWhenMet] = $now; }

		if (($player[$nTeam] != int($player[$nTeam])) ||
		    ($teamopen[$player[$nTeam]] == 0))
		{
			if ($player[$nTeam] != 1)
				{ print "-- removing $player[$sNick] from closed or invalid team\n"; }
			$player[$nTeam] = $newplayer[$nTeam];
		}

#		my ($age,$sex,$loc) = ($player[$sPersonalStats] =~ /^\(([^\/]*)\/([^\/]*)\/([^\)]*)\)$/);
#		if (int($age) < 17 && $player[$sFlags] !~ /[doy]/)
#		{
#			$player[$sFlags] =~ tr/f//d;
#		}

		if ($player[$sSpeedBestWonPeriod] == 0) { $player[$sSpeedBestWonPeriod] = 99999; }
		if ($player[$sSpeedBestWonSeason] == 0) { $player[$sSpeedBestWonSeason] = 99999; }
		if ($player[$sSpeedBestWon] == 0) { $player[$sSpeedBestWon] = 99999; }
		$player[$nRank] = int($player[$nRank]);
		$player[$nBonusPoints] = int($player[$nBonusPoints]);
		setplayer(@player);
		$count++;
	}
	$count;
}

#----------------------------------------------------------------------------

sub isnotifyable
{
	local($nick) = @_;
	my @player = getplayer($nick);

	if ($player[$sFlags] =~ /[*d]/) { return 0; }
	if ($player[$sFlags] !~ /f/) { return 0; }
	if ($player[$nTeam] == 1) { return 0; }
	if ($player[$nRank] == 0) { return 0; }

	return 1;
}

#----------------------------------------------------------------------------

sub findrankname
{
	local($rank) = @_;
	my $a = 0;

	if ($rank < 0)
		{ $rank = 0; }

	while (!defined($rankname{int($rank-$a)}))
	{
		$a++;
	}

	if ($a != 0)
	{
		$a++;
		return ordinal($a) . " " . $rankname{int($rank-$a+1)};
	}

	return $rankname{int($rank-$a)};
}

sub teambanner
{
	local(@player) = @_;

	my $a = '';
	my $team = $player[$nTeam];
	if ($team != 1)
		{ $a = qwizcolor(" (team $teamname[$team])", $team); }

	$a;
}

sub teamcolor
{
	local(@player) = @_;

	my $team = $player[$nTeam];
	if ($bTeams == 0)
		{ $team = 1; }
	my $a = qwizcolor($player[$sNick], $team);
	if ($team != 1)
		{ $a = $a . qwizcolor(" (team $teamname[$team])", $team); }

	$a;
}

sub countteam
{
	local($team) = @_;

	my $c = 0;

	if ($$team == 1) { return 0; }
	if ($teamopen[$team] == 0) { return 0; }
	foreach $nick (keys %players)
	{
		my @player = getplayer($nick);
		if ($player[$nTeam] == $team)
			{ $c++; }
	}

	$c;
}

#----------------------------------------------------------------------------

sub noticeplayersbyflag
{
	local($withflag, $withoutflag, $message) = @_;

	foreach $nick (sort keys %active)
	{
		if ($nick eq '') { next; }
		if (lc($nick) eq lc($except)) { next; }
		my @player = getplayer($nick);

		if ($withoutflag ne '' && $player[$sFlags] =~ /$withoutflag/)
			{ next; }

		if ($withflag ne '' && $player[$sFlags] !~ /$withflag/)
			{ next; }

		&NOTICE($nick, $message);
	}
}

#----------------------------------------------------------------------------

sub statsplayer
{
	local($targetnick, $op, @player) = @_;

	my($a, $t, $n);

	#--  " Joe is a service bot to assist the channel. "
	if ($player[$sFlags] =~ /d/)
	{
		$a = " $player[$sNick] is a service bot to assist the channel. ";
		&NOTICE($targetnick, $a);
		return;
	}

	#--  " Joe (team Fireball) (channel friend) (31/m/austin) is ranked second journeyman "
	{
		$a = qwizcolor(" ", 1);
		$a = $a . teamcolor(@player) . $a;

		$t = $player[$sFlags];
		if ($t =~ /o/)
			{ $a = $a . qwizcolor("(channel operator) "); }
		if (defined($hCaptains{lc($player[$sNick])}))
			{ $a = $a . qwizcolor("(team captain) "); }
		elsif ($t =~ /f/)
			{ $a = $a . qwizcolor("(channel friend) "); }

		if ($player[$sPersonalStats] ne $newplayer[$sPersonalStats])
			{ $a .= $player[$sPersonalStats] . " "; }

		$t = $player[$nRank];
		$n = &findrankname($t);
		$a = $a . qwizcolor("is ranked $n ", 1);

		&NOTICE($targetnick, $a);
	}

	#--  " Joe has 5 wins this period (fastest was 2.4sec) "
	if (0 && isactive($player[$sNick]) && $player[$nTimesWonPeriod] > 0)
	{
		$a = " $player[$sNick] has $player[$nTimesWonPeriod] wins this period ";

		if ($player[$nTimesWonPeriod] > 0 && $player[$sSpeedBestWonPeriod] < 99999)
			{ $a = $a . "(fastest was " . describetimespan($player[$sSpeedBestWonPeriod]) . ") "; }

		&NOTICE($targetnick, qwizcolor($a));
	}

	#--  " Joe has 25 wins this season (fastest was 2.2sec) "
	if ($player[$nTimesWonSeason] != $player[$nTimesWon])
	{
		$a = " $player[$sNick] has $player[$nTimesWonSeason] wins this season ";

		if ($player[$nTimesWonSeason] > 0 && $player[$sSpeedBestWonSeason] < 99999)
			{ $a = $a . "(fastest was " . describetimespan($player[$sSpeedBestWonSeason]) . ") "; }

		&NOTICE($targetnick, qwizcolor($a));
	}

	#--  " Joe has 125 wins overall (fastest was 2.1sec), 60 close calls "
	{
		$a = " $player[$sNick] has $player[$nTimesWon] wins overall";

		if ($player[$nTimesWon] > 0 && $player[$sSpeedBestWon] < 99999)
			{ $a = $a . " (fastest was " . describetimespan($player[$sSpeedBestWon]) . ")"; }

		if ($player[$nTimesFinishedSecond] > 0)
			{ $a = $a . ", $player[$nTimesFinishedSecond] close calls"; }

		$a = $a . " ";

		&NOTICE($targetnick, qwizcolor($a));
	}

	#--  " Joe has had a streak of 4 wins in a row (2 this season) "
	if ($player[$nBestStreakWon] > 1)
	{
		$a = " $player[$sNick] has streaked $player[$nBestStreakWon] wins in a row ";

		if ($player[$nBestStreakWonSeason] != $player[$nBestStreakWon])
			{ $a = $a . "(streaked $player[$nBestStreakWonSeason] this season) "; }

		&NOTICE($targetnick, qwizcolor($a));
	}

	#--  " Joe has submitted 4 questions and earned 5 TriviaBucks "
	$a = '';
	if (($player[$nSubmissions] > 0) || ($player[$nBonusPoints] > 0))
		{ $a = " $player[$sNick] has "; }
	if ($player[$nSubmissions] > 0)
		{ $a .= "submitted $player[$nSubmissions] questions "; }
	if (($player[$nSubmissions] > 0) && ($player[$nBonusPoints] > 0))
		{ $a .= "and "; }
	if ($player[$nBonusPoints] > 0)
		{ $a .= "has earned $player[$nBonusPoints] TriviaBucks "; }
	if ($a ne '')
		{ &NOTICE($targetnick, qwizcolor($a)); }

	#
	# op's information
	#

	if ($op == 0)
		{ return; }

	#--  " Joe has a mean speed of 2.54 seconds for the past 10 wins "
	my @qu = split(/,/, $player[$sMeanSpeedQueue]);
	if ($#qu >= 0)
	{
		$t = 0;
		foreach (0 .. $#qu) { $t += $qu[$_]; }
		$t /= ($#qu + 1);
		$t = int($t * 100) / 100;
		$a = " $player[$sNick] has a ";
		$a .= "mean speed of " . $t . " seconds ";
		$a .= "for the past " . ($#qu + 1) . " wins ";
		&NOTICE($targetnick, qwizcolor($a, 7));
	}

	#--  " Joe!*ident@*.server.net mode +bf player 3 weeks kicked 3x"
	$a = " $player[$sNick]\!$player[$sMask] mode +$player[$sFlags] ";
	$t = describetimespan(time() - $player[$tWhenMet]);
	my @s = split(/,\s*/, $t);
	$t = $s[0];
	$a .= "player $t ";
	if ($player[$nTimesKicked] > 0)
		{ $a .= "kicked $player[$nTimesKicked]x "; }
	&NOTICE($targetnick, qwizcolor($a, 7));
}

#----------------------------------------------------------------------------

sub detectclones
{
	local($nick) = @_;

	foreach $compnick (keys %present)
	{
		if (lc($nick) eq lc($compnick)) { next; }
		if ($present{$nick} eq 'unknownhost') { next; }
		if ($present{$compnick} eq 'unknownhost') { next; }
		if ($present{$nick} eq $present{$compnick})
		{
			my $a = "IP match detected: $nick\! and $compnick\!$present{$compnick}";
			noticeplayersbyflag('o', '', $a);
		}
	}
}

#----------------------------------------------------------------------------

sub activateplayer
{
	local($nick, $host) = @_;

	if ($nick eq $botnick)
		{ return 0; }

	if (isactive($nick))
	{
		return 1;
	}

	my $found = 0;
	my $banished = 0;
	my @player = ();
	my $mask = $host;
	my $now = time();

	# if it's a nick we recognize, easy find; may or may not be banished
	#
	if (isplayer($nick))
	{
		@player = getplayer($nick);
		$mask = $player[$sMask];
		if (irchostinmask($host, $player[$sMask]))
		{
			$found = 1;
			if ($player[$sFlags] =~ /\*/)
			{
				$banished = 1;
			}
			if ($player[$sFlags] =~ /d/)
			{
				if ($player[$sFlags] =~ /o/)
					{ &OPS($nick); }
				$active{lc($nick)} = $host;
				detectclones($nick);
				gameactivateplayer($nick);
				return 1;
			}
		}
	}

	# if it's not a nick or mask we recognize, look to see if the mask matches a banished one
	#
	if ($found == 0)
	{
		foreach $check (keys %players)
		{
			@player = getplayer($check);
			if (irchostinmask($host, $player[$sMask]))
			{
				$found = 1;
				if ($player[$sFlags] =~ /\*/)
				{
					$banished = 1;
				}
				last;
			}
 		}
	}

	if ($banished == 1)
	{
		print "** Banishing $player[$sNick]\!$player[$sMask], came in as $nick.\n";
		&BAN('*', $host, "Message an operator if you wish to join.");
		return 0;
	}

	# new name, but matches host of another player; so 'unfind' them.
	#
	if ($found == 1 && !isplayer($nick))
	{
		$found = 0;
	}

	# old player, but new host.  replace their mask for them.
	# not supported for players with any privileges
	#
	if ($found == 0 && isplayer($nick))
	{
		if ($host eq 'unknownhost')
		{
			# don't bitch if we just haven't gotten the host yet
			$found = 1;
		}
		else
		{
			@player = getplayer($nick);
			if (1) # ($player[$sFlags] !~ /[a-eg-z]/)
			{
				my $mask = ircmaskfromhost($host);

				print "** Remasked player $nick from $player[$sMask] to $mask.\n";
				$player[$sMask] = $mask;
				$found = 1;
			}
			else
			{
				if ($found == 0 && isplayer($nick))
				{
					&NOTICE($nick, "You don't look like the regular player named $nick. You need to speak with an operator.\n");
					print "** Could not activate privileged player $nick from $host with mask $mask.\n";
					return 0;
				}
			}
		}
	}

	# new player!  figure a good *ident@*.server.net mask for them.
	#
	if ($found == 0 && !isplayer($nick))
	{
		$mask = ircmaskfromhost($host);

		@player = @newplayer;
		$player[$sNick] = $nick;
		$player[$sMask] = $mask;
		$player[$tWhenMet] = $now;

		&NOTICE($nick, "Hello, $nick. I've registered you as a $rankname{0}.\n");
		&NOTICE($nick, "To play, just type answers when I ask questions. Try !help for more details. Good luck!\n");
		print "** Created player $nick from $mask.\n";
		$found = 1;
	}

	# known player; let them know we know them
	#
	if ($found > 0 && isplayer($nick))
	{
		@player = getplayer($nick);
#		&NOTICE($nick, "Hello, $nick. I've checked your past scores (try !stats).\n");
	}

	$player[$tWhenLastSaid] = $now;
	$player[$tWhenSeen] = $now;
	if ($player[$tWhenMet] <= 1)
		{ $player[$tWhenMet] = $now; }
	setplayer(@player);
	if (!isplayer($nick))
		{ print "** Failed creating \'" . join(':', @player) . "\'\n"; }

	$active{lc($nick)} = $host;
	delete $warned{lc($nick)};
	print ">> Activating player $nick from $host.\n";

	detectclones($nick);
	gameactivateplayer($nick);

	return 1;
}

sub authplayer
{
	local($nick) = @_;

	my @player = getplayer($nick);
	if ($player[$nRank] > 0)
	{
		&VOICE($nick);
	}
	else
	{
		&DEVOICE($nick);
	}
}

sub deactivateplayer
{
	local($nick) = @_;

	if ($nick eq $botnick)
		{ return; }

	delete $warned{lc($nick)};
	delete $authed{lc($nick)};

	if (!isactive($nick))
		{ return 1; }

	delete $active{lc($nick)};
	print "<< Deactivating player $nick.\n";

	my @player = getplayer($nick);
	$player[$tWhenSeen] = time();
	setplayer(@player);
#	&NOTICE($nick, "Goodbye, $player[$sNick].");

	return 1;
}

#----------------------------------------------------------------------------

sub absorbplayer
{
	local($newnick, $obsnick) = @_;

	my @newplayer = getplayer($newnick);
	my @obsplayer = getplayer($obsnick);

	if ($newplayer[$tWhenMet] > $obsplayer[$tWhenMet]) { $newplayer[$tWhenMet] = $obsplayer[$tWhenMet]; }
	if ($newplayer[$tWhenSeen] < $obsplayer[$tWhenSeen]) { $newplayer[$tWhenSeen] = $obsplayer[$tWhenSeen]; }
	$newplayer[$nTimesKicked] += $obsplayer[$nTimesKicked];

	$newplayer[$nTimesWon] += $obsplayer[$nTimesWon];
	if ($newplayer[$tWhenLastWon] < $obsplayer[$tWhenLastWon]) { $newplayer[$tWhenLastWon] = $obsplayer[$tWhenLastWon]; }
	if ($newplayer[$sSpeedBestWon] > $obsplayer[$sSpeedBestWon]) { $newplayer[$sSpeedBestWon] = $obsplayer[$sSpeedBestWon]; }
	if ($newplayer[$nBestStreakWon] < $obsplayer[$nBestStreakWon]) { $newplayer[$nBestStreakWon] = $obsplayer[$nBestStreakWon]; }
	$newplayer[$nRank] = int($newplayer[$nTimesWon] / $nWinsPerRank);

	$newplayer[$nTimesWonPeriod] += $obsplayer[$nTimesWonPeriod];
	$newplayer[$nTimesAskedPeriod] += $obsplayer[$nTimesAskedPeriod];
	if ($newplayer[$sSpeedBestWonPeriod] > $obsplayer[$sSpeedBestWonPeriod]) { $newplayer[$sSpeedBestWonPeriod] = $obsplayer[$sSpeedBestWonPeriod]; }
	if ($newplayer[$nBestStreakWonPeriod] < $obsplayer[$nBestStreakWonPeriod]) { $newplayer[$nBestStreakWonPeriod] = $obsplayer[$nBestStreakWonPeriod]; }

	$newplayer[$nTimesWonSeason] += $obsplayer[$nTimesWonSeason];
	$newplayer[$nTimesAskedSeason] += $obsplayer[$nTimesAskedSeason];
	if ($newplayer[$sSpeedBestWonSeason] > $obsplayer[$sSpeedBestWonSeason]) { $newplayer[$sSpeedBestWonSeason] = $obsplayer[$sSpeedBestWonSeason]; }
	if ($newplayer[$nBestStreakWonSeason] < $obsplayer[$nBestStreakWonSeason]) { $newplayer[$nBestStreakWonSeason] = $obsplayer[$nBestStreakWonSeason]; }

	$newplayer[$nSubmissions] += $obsplayer[$nSubmissions];
	if ($newplayer[$tWhenLastCategory] < $obsplayer[$tWhenLastCategory]) { $newplayer[$tWhenLastCategory] = $obsplayer[$tWhenLastCategory]; }
	$newplayer[$nBonusPoints] += $obsplayer[$nBonusPoints];

	$newplayer[$nTimesFinishedSecond] += $obsplayer[$nTimesFinishedSecond];

	setplayer(@newplayer);
	delete $players{lc($obsnick)};
}

sub modeplayer
{
	local($cmdnick, $playernick, $plusmodes, $minusmodes) = @_;

	my @player = getplayer($playernick);

	my %flags = ();
	for $a (0 .. (length($player[$sFlags])-1))
	{
		$flags{substr($player[$sFlags],$a,1)} = 1;
	}

	for $a (0 .. (length($plusmodes)-1))
	{
		$flags{substr($plusmodes,$a,1)} = 1;
	}

	for $a (0 .. (length($minusmodes)-1))
	{
		delete $flags{substr($minusmodes,$a,1)};
	}

	$player[$sFlags] = join('', (sort keys %flags));
	&NOTICE($cmdnick, "$playernick is now mode +$player[$sFlags]");

	if ($player[$sFlags] =~ /\*/ && isactive($player[$sNick]))
	{
		&BAN('*' . $active{lc($player[$sNick])}, "Message an operator if you wish to join.");
		deactivateplayer($player[$sNick]);
	}

	setplayer(@player);
}

#----------------------------------------------------------------------------

1;
