#!/usr/local/bin/perl5
#=--------------------------------------=
#  Quizbot - qwizgame.pm
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

# game files
	$fixedfile = lc($botname . '.fixed.txt');
	$questionfile = lc($botname . '.questions.txt');
	$submissionfile = lc($botname . '.submissions.txt');
	$acceptedfile = lc($botname . '.accepted.txt');
	$categoryfile = lc($botname . '.categories.txt');
	$optionsfile = lc($botname . '.options.txt');
	$seasonfile = lc($botname . '.season.txt');
	$mailfile = lc($botname . '.mail.txt');
	$pollfile = lc($botname . '.polls.txt');
	$logfile = lc($botname . '.log.txt');

#----------------------------------------------------------------------------

# game colors
	$kQuestion = 8; $kQuestionBack = 2;
	$kAnnounce = 8; $kAnnounceBack = 6;
	$kPeriodic = 8; $kPeriodicBack = 12;
	$kCongrats = 8; $kCongratsBack = 4;
	$kCategory = 4; $kCategoryBack = 0;
	$kPollster = 8; $kPollsterBack = 3;
	$kAlternateBack = 5;
	$kAlternate = 11;

#----------------------------------------------------------------------------

require qwizquestion;

#----------------------------------------------------------------------------

# quiz adjustments:

	$quizperperiod		=	12;
	$bHintsOkay		=	1;
	$nMaxHints		=	6;
	$nWinsPerRank		=	100;
	$nDontRepeat		=	(60*60*12);
	$nCategoryAllowance	=	(60*60*2);
	$nCategoryRepeat	=	(60*60*1);
	$nChanceMirrorQwiz	=	2;
	$nTeamCap		=	8;
	$nSeasonScore		=	2000;
	$nTeamAdjust		=	(2*60*60);
	$nJoinCost		=	1;
	$nFixCost		=	0;
	$bCategoryEnable	=	1;

#----------------------------------------------------------------------------

# each period has several quiz questions.
# the usual cycle repeats the billboard..answerquiz range for each question.

@statenames   = qw(preperiod prequiz billboard breather announce askquiz listen answerquiz housekeeping postperiod periodbreather, polling, postpolling);
@statetimes   =   (10,       8,      4,        8,       2,       0,      120,   2,         10,          10,        20,             40,      5          );
@statesafes   =   (0,        1,      1,        1,       1,       1,      1,     1,         1,           0,         0,              0,       0          );

#----------------------------------------------------------------------------

# qwiz status;

	$bFirstRound		=	1;
	$nCurrentState		=	9;
	$nLastBillboard		=	-1;
	@CurrentQuestion	=	();
	$nWinPlaceShow		=	0;
	$tWhenLastPeriod	=	0;
	$tWhenAnythingAsked	=	0;
	$tWhenAdvance		=	0;
	$bListening			=	0;
	$bHinting			=	0;
	$nHintsGiven		=	0;
	$nHintsRate			=	$statetimes[6] / ($nMaxHints + 1);
	$nFirstHint			=	12;
	$tWhenLastHint		=	0;
	$bTimeIsUp			=	0;
	$nQuizThisPeriod	=	0;
	@sNickFinish		=	('(nobody)', '(nobody)', '(nobody)');
	%hNickFinish		=	();
	$sNickStreak		=	'(nobody)';
	$nNickStreak		=	0;
	$bTeams				=	0;
	$nNextIndex			=	-1;
	$bFlippingCoin		=	0;
	$sCoinFlip			=	'unknown';
	$sCoinCall			=	'unknown';
	$nWorm				=	0;
	$fEndRound			=	0;
	$fEndSeason			=	0;
	@aCaptains			=	();
	%hCaptains			=	();

	%challengers		=	();
	%challengees		=	();
	$bChallenge			=	0;
	$fChallenge			=	0;
	$nChallengeRank		=	0;
	$nChallengeFee		=	5;
	$nChallengePot		=	0;

	$bPotatoQwiz		=	0;
	$fPotatoQwiz		=	0;
	$bMirrorQwiz		=	0;
	$fMirrorQwiz		=	0;
	$nBounty			=	0;
	$bCatCall			=	0;
	$fCatCall			=	0;
	$bBlackOut			=	0;
	$fBlackOut			=	0;
	$sBlackOut			=	'';
	%catscalled			=	();
	$bToughie			=	0;
	$nMaxAsked			=	0;
	$bMineHit			=	0;
	$bIgnoreMined		=	1;
	%mined				=	();
	%vowel				=	();
	$nShotgun			=	0;
	$fShotgun			=	0;

	$fMysteryCat			=	0;
	$bMysteryCat			=	0;

	%saidvocab			=	();
	$bScanVocab			=	1;

	$sLastRanked			=	'';

	%themetimes			=	();
	$themespan			=	(1*60*60);

	%themenominators		=	();
	%themenominees		=	();

	$sMagicWoyd			=	'';
	$sOldMagicWoyd		=	'';
	$sNickHitWoyd		=	0;
	$tWhenHitWoyd		=	0;
	$sNickSetWoyd		=	0;
	$tWhenSetWoyd		=	0;

	$sPollKey			=	'';
	$bCounterMeasures	=	0;

#----------------------------------------------------------------------------

sub initializegame
{
	print "Initializing game.\n";
	
	srand(time());

	readoptions($optionsfile);
	print "Options checked.\n";
	print "Hints Rate is $nHintsRate\n";

	print readmail($mailfile) . " unread gmails on file\n";
	print readpolls($pollfile) . " polls on file\n";

	print readcategories($categoryfile) . " categories on file\n";

	if (-e $fixedfile && -s $fixedfile)
	{
		unlink($questionfile);
		rename($fixedfile, $questionfile);
		print "Incorporated fixed question file.\n";
	}
	
	print readquestions($questionfile, 0, '') . " questions on file\n";
	print readquestions($acceptedfile, 1, '') . " questions accepted\n";
	print readquestions($submissionfile, 2, '') . " questions loaded from old submission file\n";

	if ($nNewQuestions > 0)
	{
		if (writequestions($questionfile) > 0)
		{
			unlink("$acceptedfile.done");
			rename($acceptedfile, "$acceptedfile.done");
			unlink("$submissionfile.done");
			rename($submissionfile, "$submissionfile.done");
		}
	}

	my $d, $e;
	print "$nQuestions total\n";

	$d = int($nAskedQuestions * 100.0 / $nQuestions);
	print "$nAskedQuestions asked ($d\% of total)\n";

	$d = int($nHitQuestions * 100.0 / $nQuestions);
	$e = int($nHitQuestions * 100.0 / $nAskedQuestions);
	print "$nHitQuestions hit ($d\% of total, $e\% of asked)\n";
	print "-----------------------\n";

if (0)
{
	foreach $nick (keys %players)
	{
		my @player = getplayer($nick);
		$player[$nSubmissions] = 0;
		setplayer(@player);
	}
	foreach $index (keys %questions)
	{
		my @question = getquestion($index);
		if (!isplayer($question[$sNickSubmitted])) { next; }
		if ($question[$bFlaggedForEdit] =~ /REVIEW|BURY/) { next; }
		my @player = getplayer($question[$sNickSubmitted]);
		$player[$nSubmissions]++;
		setplayer(@player);
	}

	print "Recounted player question submissions.\n";

	print "-----------------------\n";
}

	$tWhenAdvance = time() + 180;
}

sub savegame
{
	&writequestions($questionfile);
	&writemail($mailfile);
	&writeoptions($optionsfile);
	&writepolls($pollfile);
}

sub pumpgame
{
	if (time() >= $tWhenAdvance)
		{ &nextstate(); }
	else
		{ &processstate(); }
}

sub terminategame
{
	savegame();
	print "Terminated game.\n";
}

#----------------------------------------------------------------------------

sub gamesaid
{
	local($cmdnick, $said, @player) = @_;

	if ($bListening)
		{ &checkanswer($said, @player); }

	if ($nCurrentState == 11 && $sPollKey ne '')
		{ &checkpoll($cmdnick, $said); }

	if ($bFlippingCoin > 0 &&
	    lc($cmdnick) eq lc($sNickStreak) &&
	    $sCoinCall eq 'unknown')
	{
		if ($said =~ /heads/i) { $sCoinCall = 'heads'; }
		elsif ($said =~ /tails/i) { $sCoinCall = 'tails'; }

		if ($sCoinCall ne 'unknown')
		{
			&CHANACTION("nods to $sNickStreak. You called " . ucfirst($sCoinCall) . ".");
			checkflip();
		}
	}

	if ($sMagicWoyd ne '' && $said =~ /\b\Q$sMagicWoyd\E\b/i)
	{
		if (lc($cmdnick) eq lc($sNickSetWoyd))
		{
			&NOTICE($cmdnick, "Shh! You just said your own Magic Woyd!");
		}
		else
		{
			@player = getplayer($cmdnick);
			$player[$nBonusPoints]++;
			&CHANMSG(qwizcolor(" $cmdnick just said the magic woyd! \'$sMagicWoyd\' ", $kAlternate, $kPollsterBack));
			&NOTICE($cmdnick, "You earned a TriviaBuck for saying the magic woyd!");
			setplayer(@player);

			$sOldMagicWoyd = $sMagicWoyd;
			$sNickHitWoyd = $player[$sNick];
			$tWhenHitWoyd = time();

			$sMagicWoyd = '';
		}
	}

	if ($bScanVocab)
	{
		my @vocab = split(/ /, $said);
		foreach $w (@vocab)
		{
			if ($w =~ /[^A-Za-z]/) { next; }
			my $ww = lc($w);
			if (!defined($saidvocab{$ww}))
			{
				$saidvocab{$ww} = '1:' . lc($cmdnick);
			}
			elsif ($saidvocab{$ww} =~ /^(\d+):/)
			{
				$saidvocab{$ww} = int($1) + 1;
			}
			else
			{
				$saidvocab{$ww} = int($saidvocab{$ww}) + 1;
			}
		}
	}
}

sub gamecommand
{
	local($cmdnick,$cmdhost,$rcommand,$ispublic) = @_;
	my $isexpress = 0;

	if ($cmdchan eq $botnick)
		{ $cmdchan = $cmdnick; }

	if ($rcommand =~ /^\@/)
	{
		$isexpress = 1;
		$rcommand =~ s/^\@//;
	}

	$rcommand =~ s/\n//;
	$rcommand =~ s/\r//;

	@commandfields = split (/ /, $rcommand);
	$thecommand = lc($commandfields[0]);

	if (!isactive($cmdnick))
		{ return; }

	my @player = getplayer($cmdnick);
	$player[$tWhenLastSaid] = time();
	setplayer(@player);

	#
	# blacklisted folks and bots have NO commands
	#
	if ($player[$sFlags] =~ /[*d]/)
		{ return; }

	if ($player[$sFlags] !~ /o/)
		{ $isexpress = 0; }

	#
	# absorb command -------------------------------------------------------------
	#
	if ($thecommand eq 'absorb' && $player[$sFlags] =~ /m/ && $player[$sFlags] =~ /x/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[2] eq '' ||
		    $commandfields[1] eq $commandfields[2] ||
			!isplayer($commandfields[1]))
		{
			&NOTICE($cmdnick, "Usage:  \!absorb  RegularPlayer  ObsoletePlayer");
			return;
		}

		if (isactive($commandfields[2]))
		{
			&NOTICE($cmdnick, "Usage:  \!absorb  RegularPlayer  ObsoletePlayer");
			&NOTICE($cmdnick, "The ObsoletePlayer is currently seen as active.");
			return;
		}

		my @player = getplayer($commandfields[1]);
		for $index (keys %questions)
		{
			my @question = getquestion($index);
			if (lc($question[$sNickSubmitted]) ne lc($commandfields[2])) { next; }
			if ($index eq $CurrentQuestion[$nIndex]) { next; }
			$question[$sNickSubmitted] = $commandfields[1];
			$player[$nSubmissions]++;
			setquestion(@question);
		}
		setplayer(@player);
		writequestions($questionfile);

		if (isplayer($commandfields[2]))
		{
			absorbplayer($commandfields[1], $commandfields[2]);
			writeplayers();
		}

		&NOTICE($cmdnick, "The identity $commandfields[1] has absorbed $commandfields[2].");
		if (isactive($commandfields[1]))
			{ &NOTICE($commandfields[1], "You have absorbed all scores from $commandfields[2], who has now been erased."); }
		return;
	}

	#
	# accept command -------------------------------------------------------------
	#
	if ($thecommand eq 'accept' && $player[$sFlags] =~ /[ap]/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my $honor = '';
		if ($commandfields[1] eq '' || isplayer($commandfields[1]))
		{
			$honor = $commandfields[1];
			my $a = readquestions($acceptedfile, 1, $honor);
			my $b = readquestions($submissionfile, 2, '');
			my $c = writequestions($questionfile);
			if ($a > 0)
			{
				if ($honor eq '')
					{ $honor = 'everyone'; }
				&CHANMSG(qwizcolor("Just now accepted $a new questions into the database! Thanks $honor! See !add for details.", $kCongrats, $kCongratsBack));
			}
			if ($b > 0)
			{
				noticeplayersbyflag('a', '', "Added $b new submissions for review.");
			}
			if ($c > 0)
			{
				unlink("$acceptedfile.done");
				rename($acceptedfile, "$acceptedfile.done");
				unlink("$submissionfile.done");
				rename($submissionfile, "$submissionfile.done");
			}
		}
		elsif (isquestion($commandfields[1]))
		{
			my @question = getquestion($commandfields[1]);
			$question[$bFlaggedForEdit] = "ACCEPTED($cmdnick)";
			setquestion(@question);

			if (isplayer($question[$sNickSubmitted]))
			{
				my @player = getplayer($question[$sNickSubmitted]);
				$player[$nSubmissions]++;
				setplayer(@player);
				if (isactive($player[$sNick]))
				{
					&NOTICE($player[$sNick], "One of your questions was just reviewed and accepted! Thanks!");
				}
			}
			&NOTICE($cmdnick, "Accepted question $commandfields[1] into the active database.");
		}
		else
		{
			&NOTICE($cmdnick, "No new reviewed questions are ready to be accepted.");
		}
		return;
	}
	if ($thecommand eq 'massaccept' && $player[$sFlags] =~ /x/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] eq '')
		{
			&NOTICE($cmdnick, "Usage: !massaccept <searchpattern>");
			return;
		}

		my ($pat) = ($rcommand =~ /$thecommand\s+(.*)\s*$/i );
		my %finds = ();
		foreach $index (keys %questions)
		{
			if ($questions{$index} =~ /BURY/) { next; }
			if ($questions{$index} !~ /REVIEW/) { next; }
			if ($questions{$index} =~ /$pat/i)
			{
				$finds{$index} = $questions{$index};
				my @question = getquestion($index);
				$question[$bFlaggedForEdit] = "ACCEPT($cmdnick)";
				setquestion(@question);
			}
		}
		my @fk = (keys %finds);
		my $ft = $#fk+1;
		&NOTICE($cmdnick, "Accepted questions ($ft total).");
		return;
	}
	if ($thecommand eq 'review' && $player[$sFlags] =~ /[ap]/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] eq '' || !isquestion($commandfields[1]))
		{
			my $e = -1;
			my $c = 0;
			for $index (keys %questions)
			{
				my $questionline = $questions{$index};
				if ($questionline =~ /REVIEW/ && $questionline !~ /BURY/)
				{
					$c++; $e = $index;
				}
			}
			&NOTICE($cmdnick, "There are $c submitted questions needing review.");
			if ($player[$sFlags] =~ /a/ && $e >= 0)
				{ &NOTICE($cmdnick, "Use !review $e to review one."); }
			return;
		}

		my @question = getquestion($commandfields[1]);
		if ($question[$bFlaggedForEdit] !~ /REVIEW|FIX/ && $player[$sFlags] !~ /p/)
		{
			&PRIVMSG($cmdnick, "That question is not marked for review or fixing.");
			return;
		}
		if ($bListening && $player[$sFlags] !~ /p/ &&
		    $question[$nIndex] == $CurrentQuestion[$nIndex])
		{
			&PRIVMSG($cmdnick, "Wait for the question to be answered, or time to expire.  Then try !review $CurrentQuestion[$nIndex] again.");
			return;
		}
		noticeplayersbyflag('a', '', "$cmdnick is reviewing question $commandfields[1].");
		showquestion($cmdnick, @question);
		return;
	}
	if ($thecommand eq 'bury' && $player[$sFlags] =~ /[ap]/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] eq '' || !isquestion($commandfields[1] ||
		    $commandfields[2] !~ /^(dupe|broken|wrong|tech|trash)$/))
		{
			&NOTICE($cmdnick, "Usage: !bury <questionnumber> <dupe|broken|wrong|tech|trash>");
			return;
		}

		my @question = getquestion($commandfields[1]);
		if ($question[$bFlaggedForEdit] !~ /REVIEW|FIX/ && $player[$sFlags] !~ /p/)
		{
			&PRIVMSG($cmdnick, "That question is not marked for review or fixing.");
			return;
		}

		$question[$bFlaggedForEdit] = "BURY($commandfields[2])" . $question[$bFlaggedForEdit];
		setquestion(@question);
		&NOTICE($cmdnick, "Question $question[$index] is now buried for manual review later.");
		return;
	}
	if ($thecommand eq 'massbury' && $player[$sFlags] =~ /x/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] eq '')
		{
			&NOTICE($cmdnick, "Usage: !bury <searchpattern>");
			return;
		}

		my ($pat) = ($rcommand =~ /$thecommand\s+(.*)\s*$/i );
		my %finds = ();
		foreach $index (keys %questions)
		{
			if ($questions{$index} =~ /BURY/) { next; }
			if ($questions{$index} =~ /$pat/i)
			{
				$finds{$index} = $questions{$index};
				my @question = getquestion($index);
				$question[$bFlaggedForEdit] = "MASS\+BURY($cmdnick)";
				setquestion(@question);
			}
		}
		my @fk = (keys %finds);
		my $ft = $#fk+1;
		&NOTICE($cmdnick, "Buried questions ($ft total).");
		return;
	}
	if ($thecommand eq 'burn' && $player[$sFlags] =~ /p/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] eq '' || !isquestion($commandfields[1]))
		{
			&NOTICE($cmdnick, "Usage: \!burn \<questionnumber\>");
			return;
		}

		my @question = getquestion($commandfields[1]);
		if ($question[$bFlaggedForEdit] !~ /BURY/)
		{
			&PRIVMSG($cmdnick, "That question is not buried.");
			return;
		}
		if ($question[$bFlaggedForEdit] =~ /BURN/)
		{
			&PRIVMSG($cmdnick, "That question was already burned.");
			return;
		}

		$question[$bFlaggedForEdit] = "BURN\+BURY($cmdnick)";
		setquestion(@question);
		&NOTICE($cmdnick, "Question $question[$index] is now burned beyond recovery.");
		return;
	}
	if ($thecommand eq 'exhume' && $player[$sFlags] =~ /[ap]/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] eq '' || !isquestion($commandfields[1]))
		{
			my @e = ();
			my $c = 0;
			for $index (keys %questions)
			{
				my $questionline = $questions{$index};
				if ($questionline =~ /BURY/ && $questionline !~ /BURN/)
				{
					$c++; if ($#e < 6) { $e[++$#e] = $index; }
				}
			}
			&NOTICE($cmdnick, "There are $c buried but exhumable questions.");
			if ($player[$sFlags] =~ /a/ && $#e >= 0)
				{ &NOTICE($cmdnick, "Marked for critical review: " . join(', ', @e)); }
			return;
		}

		my @question = getquestion($commandfields[1]);
		if ($question[$bFlaggedForEdit] !~ /BURY/ && $player[$sFlags] !~ /p/)
		{
			&PRIVMSG($cmdnick, "That question is not buried.");
			return;
		}
		noticeplayersbyflag('a', '', "$cmdnick is reviewing question $commandfields[1].");
		showquestion($cmdnick, @question);
		return;
	}

	#
	# add (question) public command -------------------------------------------------------------
	#
	if ($thecommand eq 'add' && $commandfields[1] eq '')
	{
		&NOTICE($cmdnick, "To add a question, submit a command in this format:");
		&NOTICE($cmdnick, qwizcolor("/msg $botnick add What color is a green crayon?", 2, 11) . qwizcolor("|",4,11) . qwizcolor("green", 2, 11));
		&NOTICE($cmdnick, "Please read !tips for some ideas to help $qwizbot accept your questions quickly.");
		return;
	}

	#
	# add (question) private command -------------------------------------------------------------
	#
	if ($thecommand eq 'add' && $ispublic == 0)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my($sub) = ($rcommand =~ /$thecommand\s+(.+)$/i);

		my @question = &addquestion($cmdnick, $sub);
		if ($question[0] ne '*') { return; }
		print "-- \[$question[$sQuestion]\|$question[$sAnswer1]\|$question[$sAnswer2]\] $cmdnick\n";

		if ($isexpress == 0)
		{
			#
			# save submission to the submission file
			#
			if (!open(INFO, ">>$submissionfile"))
			{
				if ($cmdnick ne '')
				{
					&NOTICE($cmdnick, "Unable to save your submission. Try again later.\n");
				}
				return;
			}
			my $catline = join("\º", @question);
			print INFO "$catline\n";
			close(INFO);

			&showquestion($cmdnick, @question);
			&PRIVMSG($cmdnick, "Submission accepted for review. Thank you!\n");

			noticeplayersbyflag('a', '', "$cmdnick just submitted a new question for review.");
		}
		else
		{
			my $index = setquestion(@question);
			&showquestion($cmdnick, @question);

			noticeplayersbyflag('a', '', "$cmdnick just quick-added question $index.");
		}

		return;
	}

	#
	# answer command -------------------------------------------------------------
	#
	if ($thecommand eq 'answer' && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$bListening = 0;
		if ($nCurrentState == 6)
		{
			$nWinPlaceShow = -1;
			$tWhenAdvance = 0;
		}
		return;
	}

	#
	# bonus command -------------------------------------------------------------
	#
	$thecommand = 'bonus' if ($thecommand eq 'TriviaBucks');
	if ($thecommand eq 'bonus' && $player[$sFlags] =~ /[bx]/ && isplayer($commandfields[1]))
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my @target = getplayer($commandfields[1]);
		my $bonus = 1;
		if ($commandfields[2] != 0)
			{ $bonus = $commandfields[2]; }
		$target[$nBonusPoints] += $bonus;
		setplayer(@target);
		if (isactive($commandfields[1]))
			{ &NOTICE($commandfields[1], "$cmdnick just hit you with $bonus TriviaBucks!"); }
		&NOTICE($cmdnick, "Hit $commandfields[1] with $bonus free TriviaBucks.");
		return;
	}
	elsif (0 && $thecommand eq 'bonus' && isplayer($commandfields[1]))  ####### DISABLED  (0 && x)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if (lc($commandfields[1]) eq lc($cmdnick))
		{
			&NOTICE($cmdnick, "Can't give TriviaBucks to yourself, you must earn them.");
			return;
		}

		my @target = getplayer($commandfields[1]);
		my $bonus = 1;
		my $s = '';
		if ($commandfields[2] > 0)
		{
			$bonus = $commandfields[2];
		}
		$s = 's' if $bonus != 1;
		if ($commandfields[2] < 0)
		{
			&NOTICE($cmdnick, "You can\'t give a negative number of TriviaBucks.");
			return;
		}
		if ($player[$nBonusPoints] < $commandfields[2])
		{
			&NOTICE($cmdnick, "You don\'t have $bonus TriviaBuck$s to give $commandfields[1].");
			return;
		}

		$player[$nBonusPoints] -= $bonus;
		setplayer(@player);

		$target[$nBonusPoints] += $bonus;
		setplayer(@target);

		if (isactive($commandfields[1]))
			{ &NOTICE($commandfields[1], "$cmdnick just gave you $bonus of their TriviaBucks\!"); }
		&NOTICE($cmdnick, "Gave $commandfields[1] $bonus of your TriviaBucks.");
		return;
	}

	if ($thecommand eq 'added' && $player[$sFlags] =~ /x/ && isplayer($commandfields[1]))
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my @target = getplayer($commandfields[1]);
		my $bonus = 1;
		if ($commandfields[2] != 0)
			{ $bonus = $commandfields[2]; }
		$target[$nSubmissions] += $bonus;
		setplayer(@target);
		&NOTICE($cmdnick, "Hit $commandfields[1] with $bonus added questions.");
		return;
	}

	#
	# best command -------------------------------------------------------------
	#
	if ($thecommand eq 'best')
	{
		if (!isreportokay()) { &NOTICE($cmdnick, "Please wait a few moments and try again."); return; }

		my $sortby = $nTimesWonSeason;
		my $topcount = 5;
		my $shownick = '';

		if ($commandfields[1] ne '')
		{
			if (int($commandfields[1]) > 0) { $sortby = int($commandfields[1]); }
			elsif (lc($commandfields[1]) eq 'season-wins') { $sortby = $nTimesWonSeason; }
			elsif (lc($commandfields[1]) eq 'wins') { $sortby = $nTimesWon; }
			elsif (lc($commandfields[1]) eq 'season-streak') { $sortby = $nBestStreakWonSeason; }
			elsif (lc($commandfields[1]) eq 'streak') { $sortby = $nBestStreakWon; }
			elsif (lc($commandfields[1]) eq 'added') { $sortby = $nSubmissions; }
			elsif (lc($commandfields[1]) eq 'met') { $sortby = $tWhenMet; }
			elsif (lc($commandfields[1]) =~ /bonus|buck/) { $sortby = $nBonusPoints; }
			elsif (lc($commandfields[1]) eq 'second') { $sortby = $nTimesFinishedSecond; }
			elsif (lc($commandfields[1]) eq 'mean-speed') { $sortby = $sMeanSpeedQueue; }
			elsif (lc($commandfields[1]) eq 'category') { $sortby = $tWhenLastCategory; }
			else
			{
				&NOTICE($cmdnick, "Unknown data type. For available types, see !help best");
				return;
			}
		}

		if ($player[$sFlags] =~ /o/)
		{
			if (int($commandfields[2]) != 0) { $topcount = int($commandfields[2]); }
			if ($ispublic == 0 || $playerfieldpublic[$sortby] == 0) { $shownick = $cmdnick; }
		}

		if ($sortby < 0 || $sortby > $nPlayerPersistentInfo) { $sortby = $nTimesWonSeason; }

		if ($playerfieldpublic[$sortby] == 0 && $player[$sFlags] !~ /o/)
		{
			&NOTICE($cmdnick, "Cannot sort by that data for you. For available types, see !help best");
			return;
		}

		leaderboard($shownick, $sortby, $topcount);
		return;
	}
	#
	#top20 command
	#
	#

	if ($thecommand eq 'top10' && $player[$sFlags] =~ /z/)
	{
		if (!isreportokay()) { &NOTICE($cmdnick, "Please wait a few moments and try again."); return; }

		my $sortby = $nTimesWonSeason;
		my $topcount = 10;
		my $shownick = '';

		if ($commandfields[1] ne '')
		{
			if (int($commandfields[1]) > 0) { $sortby = int($commandfields[1]); }
			elsif (lc($commandfields[1]) eq 'season-wins') { $sortby = $nTimesWonSeason; }
			elsif (lc($commandfields[1]) eq 'wins') { $sortby = $nTimesWon; }
			elsif (lc($commandfields[1]) eq 'season-streak') { $sortby = $nBestStreakWonSeason; }
			elsif (lc($commandfields[1]) eq 'streak') { $sortby = $nBestStreakWon; }
			elsif (lc($commandfields[1]) eq 'added') { $sortby = $nSubmissions; }
			elsif (lc($commandfields[1]) eq 'met') { $sortby = $tWhenMet; }
			elsif (lc($commandfields[1]) =~ /bonus|buck/) { $sortby = $nBonusPoints; }
			elsif (lc($commandfields[1]) eq 'second') { $sortby = $nTimesFinishedSecond; }
			elsif (lc($commandfields[1]) eq 'mean-speed') { $sortby = $sMeanSpeedQueue; }
			elsif (lc($commandfields[1]) eq 'category') { $sortby = $tWhenLastCategory; }
			else
			{
				&NOTICE($cmdnick, "Unknown data type. For available types, see !help best");
				return;
			}
		}

		if ($player[$sFlags] =~ /o/)
		{
			if (int($commandfields[2]) != 0) { $topcount = int($commandfields[2]); }
			if ($ispublic == 0 || $playerfieldpublic[$sortby] == 0) { $shownick = $cmdnick; }
		}

		if ($sortby < 0 || $sortby > $nPlayerPersistentInfo) { $sortby = $nTimesWonSeason; }

		if ($playerfieldpublic[$sortby] == 0 && $player[$sFlags] !~ /o/)
		{
			&NOTICE($cmdnick, "Cannot sort by that data for you. For available types, see !help best");
			return;
		}

		leaderboard($shownick, $sortby, $topcount);
		return;
	}

	if ($thecommand eq 'place')
	{
		if (!isreportokay()) { &NOTICE($cmdnick, "Please wait a few moments and try again."); return; }

		my $sortby = $nTimesWonSeason;
		my $shownick = '';
		my $searchnick = $cmdnick;

		if ($commandfields[1] ne '' && isplayer($commandfields[1]))
		{
			$searchnick = $commandfields[1];
			splice(@commandfields, 0, 1);
		}

		if ($commandfields[1] ne '')
		{
			if (int($commandfields[1]) > 0) { $sortby = int($commandfields[1]); }
			elsif (lc($commandfields[1]) eq 'season-wins') { $sortby = $nTimesWonSeason; }
			elsif (lc($commandfields[1]) eq 'wins') { $sortby = $nTimesWon; }
			elsif (lc($commandfields[1]) eq 'season-streak') { $sortby = $nBestStreakWonSeason; }
			elsif (lc($commandfields[1]) eq 'streak') { $sortby = $nBestStreakWon; }
			elsif (lc($commandfields[1]) eq 'added') { $sortby = $nSubmissions; }
			elsif (lc($commandfields[1]) eq 'met') { $sortby = $tWhenMet; }
			elsif (lc($commandfields[1]) =~ /bonus|buck/) { $sortby = $nBonusPoints; }
			elsif (lc($commandfields[1]) eq 'second') { $sortby = $nTimesFinishedSecond; }
			elsif (lc($commandfields[1]) eq 'mean-speed') { $sortby = $sMeanSpeedQueue; }
			elsif (lc($commandfields[1]) eq 'category') { $sortby = $tWhenLastCategory; }
			else
			{
				&NOTICE($cmdnick, "Unknown data type. For available types, see !help best");
				return;
			}
		}

		if ($player[$sFlags] =~ /o/)
		{
			if ($ispublic == 0 || $playerfieldpublic[$sortby] == 0) { $shownick = $cmdnick; }
		}

		if ($sortby < 0 || $sortby > $nPlayerPersistentInfo) { $sortby = $nTimesWonSeason; }

		if ($playerfieldpublic[$sortby] == 0 && $player[$sFlags] !~ /o/)
		{
			&NOTICE($cmdnick, "Cannot sort by that data for you. For available types, see !help best");
			return;
		}

		leaderboard($shownick, $sortby, 0, $searchnick);
		return;
	}

	#
	# category command -------------------------------------------------------------
	#
	if ($thecommand eq 'catinfo' && $player[$sFlags] =~ /o/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$rcommand =~ /$thecommand\s+(.+)$/;
		my $name = getcategoryname($1);
		DEBUGMSG("\'$name\'");
		if ($name eq '')
		{
			$name = $sCurrentTheme;
		}
		my $now = time();
		my $count = countcategoryquestions($name);
		my $locks = "\'" . $themelocks{$name} . "\'";
		if ($locks eq "\'\'") { $locks = "no special"; }
		&NOTICE($cmdnick, "Category $name: Played " . describetimespan($now - $themetimes{$name})) . " ago";
		&NOTICE($cmdnick, "Category has $count questions, $locks locks.");
	}
	if ($thecommand eq 'category')
	{
		&NOTICE($cmdnick, "Currently in $sCurrentTheme.\n");

		if ($sNextTheme ne '')
		{
			my $count = countcategoryquestions($sNextTheme);
			&NOTICE($cmdnick, "The next period has already been chosen, $sNextTheme, with $count questions.");
			return;
		}
		if ($player[$sFlags] =~ /f/ && $commandfields[1] eq '')
		{
			my @nom = (sort keys %themenominees);
			if ($#nom >= 0)
			{
				&NOTICE($cmdnick, "Nominated for next round, but not yet chosen: " . join(", ", @nom) . ".");
			}

			my $now = time();
			my $wait = $player[$tWhenLastCategory] + $nCategoryAllowance - $now;
			my $s = 's'; $s = '' if ($player[$nBonusPoints] == 1);
			if ($player[$nBonusPoints] <= 0)
			{
				&NOTICE($cmdnick, "You need to earn TriviaBucks before you can choose a category.");
				return;
			}
			if ($wait > 0)
			{
				&NOTICE($cmdnick, "You have " . describetimespan($wait) . " to go before you can choose a category.");
				return;
			}
			&NOTICE($cmdnick, "You have $player[$nBonusPoints] TriviaBuck$s; you can spend one on a category choice any time.");
			return;
		}
		if ($player[$sFlags] =~ /f/ && $commandfields[1] ne '')
		{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

			$rcommand =~ /$thecommand\s+(.+)$/;
			my $name = getcategoryname($1);
			my $now = time();

			if ($player[$sFlags] !~ /o/ && $bCategoryEnable == 0)
			{
				&NOTICE($cmdnick, "Sorry, !category is not available right now.");
				return;
			}
			if ($name eq '')
			{
				if ($commandfields[1] =~ /off|no|disable/i && $player[$sFlags] =~ /o/)
				{
					&NOTICE($cmdnick, "Category choosing is now off.");
					$bCategoryEnable = 0;
					return;
				}
				if ($commandfields[1] =~ /on|enable/i && $player[$sFlags] =~ /o/)
				{
					&NOTICE($cmdnick, "Category choosing is now on.");
					$bCategoryEnable = 1;
					return;
				}
				&NOTICE($cmdnick, "Sorry, cannot find that category.  Try !help categories");
				return;
			}
			if ($statesafes[$nCurrentState] == 0)
			{
				&NOTICE($cmdnick, "Sorry, can't choose a category while $botnick is between rounds; try choosing after the next round begins.");
				return;
			}
			if ($name eq $sCurrentTheme)
			{
				&NOTICE($cmdnick, "Sorry, can't choose the same category two consecutive periods.");
				return;
			}
			if (($themelocks{$name} =~ /\+/) || (lc($name) eq lc($sGeneralTheme)))
			{
				&NOTICE($cmdnick, "Sorry, cannot choose the $name category.");
				return;
			}
			if (($themetimes{$name} + $themespan) > $now)
			{
				&NOTICE($cmdnick, "Sorry, the $name category has been played too recently.");
				return;
			}
			if ((($player[$tWhenLastCategory] + $nCategoryAllowance) > $now) &&
			       ($player[$sFlags] !~ /x/))
			{
				&NOTICE($cmdnick, "You can only choose a category every " .
					describetimespan($nCategoryAllowance) .
					"; you have " .
					describetimespan($player[$tWhenLastCategory] + $nCategoryAllowance - $now) .
					" to go.");
				return;
			}
			if ($player[$nBonusPoints] <= 0)
			{
				&NOTICE($cmdnick, "You have no TriviaBucks to spend on category choices.");
				&NOTICE($cmdnick, "See " . irccolor("!help TriviaBucks",3) . " for the ways you can earn TriviaBucks.");
				return;
			}

			if ($themelocks{$name} =~ /\*/)
			{
				if ($themenominators{lc($cmdnick)})
				{
					&NOTICE($cmdnick, "You've already nominated a special category choice for next round.");
					&NOTICE($cmdnick, "You need to get someone else in the channel to agree by also choosing the category.");
					return;
				}
				if ($themenominees{$name} eq '')
				{
					&NOTICE($cmdnick, "You have nominated $name, a special category, for next round. Another player must also request it now.");
					&NOTICE($cmdnick, "If $name is NOT chosen, there's no charge.  If it's chosen, you will pay a TriviaBuck then.");
					$themenominators{lc($cmdnick)} = $name;
					$themenominees{$name} = lc($cmdnick);
					return;
				}
			}

			my $count = countcategoryquestions($name);
			if ($count > $quizperperiod)
			{
				#
				# Legal Category Choice.
				# Spend the TriviaBuck and mark the time.
				#
				$sNextTheme = $name;
				&CHANMSG(qwizcolor(" The next period will be in $sNextTheme, with $count questions. "));
				$player[$tWhenLastCategory] = $now;
				$player[$nBonusPoints]--;
				setplayer(@player);
				my $s = 's'; $s = '' if ($player[$nBonusPoints] == 1);
				&NOTICE($cmdnick, "You have $player[$nBonusPoints] TriviaBuck$s remaining.");

				if ($themenominees{$name} ne '')
				{
					@player = getplayer($themenominees{$name});
					if ($player[$nBonusPoints] > 0)
					{
						$player[$tWhenLastCategory] = $now;
						$player[$nBonusPoints]--;
						setplayer(@player);
						$s = 's'; $s = '' if ($player[$nBonusPoints] == 1);
						&NOTICE($player[$sName], "You have $player[$nBonusPoints] TriviaBuck$s remaining.");
					}
				}


				return;
			}
			&NOTICE($cmdnick, "Sorry, cannot choose that category.  Try !help categories");
			return;
		}
		if ($commandfields[1] ne '')
		{	
			&NOTICE($cmdnick, "Find a friend of the channel if you'd like to have a certain category selected.");
		}

		return;
	}
	if ($thecommand eq 'recat' && $player[$sFlags] =~ /c/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		&NOTICE($cmdnick, "Reloaded " . readpolls($pollfile) . " polls.");
		&NOTICE($cmdnick, "Reloaded " . readcategories($categoryfile) . " categories; worm will begin correcting questions.");
		return;
	}

	#
	# challenge command -----------------------------------------------------------
	#
	if ($thecommand eq 'challenge' && $player[$sFlags] =~ /o/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($bChallenge > 0)
		{
			&NOTICE($cmdnick, "Cannot prepare another challenge while one is in progress.");
			return;
		}

		my @names = ();

		@names = split(/\s+/, $rcommand);
		splice(@names, 0, 1);
		if ($fChallenge == 0 && !defined($names[0]))
		{
			&NOTICE($cmdnick, "Usage:  !challenge <contestantnick> <contestantnick>...");
			&NOTICE($cmdnick, "The next round will be a challenge letting only contestants answer.");
			&NOTICE($cmdnick, "You can !challenge again to add contestants before the round begins.");
			&NOTICE($cmdnick, "Each contestant must !enter the challenge round for $nChallengeFee TriviaBucks.");
			return;
		}

		foreach $nick (@names)
		{
			if (!defined($challengees{lc($nick)}) &&
				!defined($challengers{lc($nick)}))
			{
				$challengees{lc($nick)} = 1;
			}
		}

		if ($fChallenge == 0)
		{
			$nChallengePot = 0;
		}
		$fChallenge = 1;

		my $a;
		$a = join(' ', (sort keys %challengers));
		$a = '(nobody)' if ($a eq '');
		&NOTICE($cmdnick, "Accepted: " . $a);

		foreach $nick (keys %challengees)
		{
			if (isactive($nick))
			{
				&NOTICE($nick, "You're being challenged to enter a competition next round!");
				&NOTICE($nick, "It costs $nChallengeFee TriviaBucks to enter.  Type !enter to pay and join!");
			}
			else
			{
				&NOTICE($cmdnick, "No player \'$nick\' here now to enter the Challenge round.");
				delete $challengees{$nick};
			}
		}

		$a = join(' ', (sort keys %challengees));
		if ($a ne '')
		{
			&NOTICE($cmdnick, "Waiting: " . $a);
		}

		@names = ();
		push(@names, (keys %challengers));
		push(@names, (keys %challengees));
		if ($#names < 0)
		{
			&NOTICE($cmdnick, "No valid contestants; challenge is off.");
			$fChallenge = 0;
		}

		return;
	}
	if ($thecommand eq 'enter')
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($bChallenge > 0)
		{
			&NOTICE($cmdnick, "The Challenge Round is already underway!");
			if (defined($challengers{lc($cmdnick)}))
				{ &NOTICE(&cmdnick, "You're in the competition, so be prepared to answer."); }
			return;
		}
		if ($fChallenge == 0)
		{
			&NOTICE($cmdnick, "No challenge round has been called.");
			return;
		}
		if (defined($challengers{lc($cmdnick)}))
		{
			&NOTICE($cmdnick, "You're already registered to compete.");
			return;
		}
		if (!defined($challengees{lc($cmdnick)}))
		{
			&NOTICE($cmdnick, "You're not one of the contestants in the challenge.");
			&NOTICE($cmdnick, "Cheer on your friends during the Challenge Round!");
			return;
		}
		if ($player[$nBonusPoints] < $nChallengeFee)
		{
			&NOTICE($cmdnick, "It costs $nChallengeFee TriviaBucks to enter the competition.");
			return;
		}

		delete $challengees{lc($cmdnick)};
		$challengers{lc($cmdnick)} = 1;
		&CHANMSG(qwizcolor(" $cmdnick has entered the upcoming Challenge Round! "));

		$nChallengePot += $nChallengeFee;
		$player[$nBonusPoints] -= $nChallengeFee;
		my $s = 's'; $s = '' if ($player[$nBonusPoints] == 1);
		&NOTICE($cmdnick, "You have $player[$nBonusPoints] TriviaBuck$s remaining for other special purchases.");
		setplayer(@player);

		return;
	}

	if ($thecommand eq 'countermeasures' && $player[$sFlags] =~ /x/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if (defined($commandfields[1]))
		{
			$bCounterMeasures = 0;
			$bCounterMeasures = 1 if ($commandfields[1] =~ /on|yes|true|1/);
		}
		&NOTICE($cmdnick, "Script countermeasures are " . ($bCounterMeasures? "on" : "off") . ".");

		return;
	}

	#
	# fix (question) command -------------------------------------------------------------
	#
	if ($thecommand eq 'fix')
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }
		if ($commandfields[1] eq '') { &NOTICE($cmdnick, "You need to give a 5 word or less reason for fixing this question (ex: 12!fix please correct me)"); return; }

		my $index = $commandfields[1];
		if ($player[$sFlags] !~ /[ap]/ || !defined($index) || ($index == 0 && $index ne '0'))
			{ $index = $CurrentQuestion[$nIndex]; }
		else
			{ shift(@commandfields); }
		if (!isquestion($index))
			{ return; }

		if ($nFixCost != 0 && $player[$sFlags] !~ /[aop]/)
		{
			if ($player[$nBonusPoints] < $nFixCost)
			{
				my $s = ($nFixCost == 1)? '' : 's';
				&NOTICE($cmdnick, "Marking a question for a fix costs " . cardinal($nFixCost) . " TriviaBuck$s, which you don\'t have.");
				return;
			}
			$player[$nBonusPoints] -= $nFixCost;
			setplayer(@player);
		}

		$CurrentQuestion[$bFlaggedForEdit] = "FIX($cmdnick: $commandfields[1] $commandfields[2] $commandfields[3] $commandfields[4] $commandfields[5])";
		setquestion($CurrentQuestion);

		if ($player[$sFlags] !~ /[aop]/)
			{ &NOTICE($cmdnick, "Flagged previous question as needing a fix; thanks!"); }

		noticeplayersbyflag('a', '', "Question $CurrentQuestion[$nIndex] now flagged for correction.");

		return;
	}
	if ($thecommand eq 'fixcount' && $player[$sFlags] =~ /c/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my @e = ();
		my $c = 0;
		for $index (keys %questions)
		{
			my $questionline = $questions{$index};
			if ($questionline =~ /FIX/ && $questionline !~ /BURY/)
			{
				$c++; if ($#e < 6) { $e[++$#e] = $index; }
			}
		}
		&NOTICE($cmdnick, "There are $c flagged questions needing a fix.");
		if ($player[$sFlags] =~ /a/ && $#e >= 0)
			{ &NOTICE($cmdnick, "Marked for fixes: " . join(', ', @e)); }
		return;
	}
	if ($thecommand eq 'unfix' && $player[$sFlags] =~ /a/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my $index = $commandfields[1];
		if (!defined($index) || ($index == 0 && $index ne '0'))
		{
			&NOTICE($cmdnick, "Usage:  \!unfix <index#>");
			return;
		}
		if (!isquestion($index))
		{
			&NOTICE($cmdnick, "Question $index not found.");
			return;
		}
		if ($index eq $CurrentQuestion[$nIndex])
		{
			$CurrentQuestion[$bFlaggedForEdit] = 0;
		}
		else
		{
			my @question = getquestion($index);
			$question[$bFlaggedForEdit] = 0;
			setquestion(@question);
		}
		&NOTICE($cmdnick, "Question $index cleared of fix flags.");
		return;
	}
	if ($thecommand eq 'edit' && $player[$sFlags] =~ /[ap]/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my ($index,$find,$replace,$codes) = ($rcommand =~ /^$thecommand\s+(\d+)\s+\/(.*)\/(.*)\/(.*)$/);
		if (!defined($replace) ||
		    !defined($find) || $find eq '' ||
			!defined($index) || ($index == 0 && $index ne '0'))
		{
			&NOTICE($cmdnick, "Usage:  \!edit <index#> /find/replace/ [<q|a|h>]");
			return;
		}
		if (!isquestion($index))
		{
			&NOTICE($cmdnick, "Question $index not found.");
			return;
		}
		$codes = 'qah' if ($codes eq '');

		my $ffind = $find;
		if ($index eq $CurrentQuestion[$nIndex])
		{
			if ($codes =~ /q/i)
			{
				if ($ffind eq '*') { $find = $CurrentQuestion[$sQuestion]; }
				$CurrentQuestion[$sQuestion] =~ s/\Q$find\E/\Q$replace\E/gi;
				$CurrentQuestion[$sQuestion] =~ s/\\//g;
			}
			if ($codes =~ /a/i)
			{
				if ($ffind eq '*') { $find = $CurrentQuestion[$sAnswer1]; }
				$CurrentQuestion[$sAnswer1] =~ s/\Q$find\E/\Q$replace\E/gi;
				$CurrentQuestion[$sAnswer1] =~ s/\\//g;
			}
			if ($codes =~ /h/i)
			{
				if ($ffind eq '*') { $find = $CurrentQuestion[$sAnswer2]; }
				$CurrentQuestion[$sAnswer2] =~ s/\Q$find\E/\Q$replace\E/gi;
				$CurrentQuestion[$sAnswer2] =~ s/\\//g;
			}
			if ($codes =~ /b/i)
			{
				if ($ffind eq '*') { $find = $CurrentQuestion[$sNickSubmitted]; }
				$CurrentQuestion[$sNickSubmitted] =~ s/\Q$find\E/\Q$replace\E/gi;
				$CurrentQuestion[$sNickSubmitted] =~ s/\\//g;
			}
			if ($CurrentQuestion[$bFlaggedForEdit] =~ /FIX/)
				{ $CurrentQuestion[$bFlaggedForEdit] = 0; }
			$CurrentQuestion[$sCategories] = categorizequestion(@CurrentQuestion);
			showquestion($cmdnick, @CurrentQuestion);
		}
		else
		{
			my @question = getquestion($index);
			if ($codes =~ /q/i)
			{
				if ($ffind eq '*') { $find = $question[$sQuestion]; }
				$question[$sQuestion] =~ s/\Q$find\E/\Q$replace\E/gi;
				$question[$sQuestion] =~ s/\\//g;
			}
			if ($codes =~ /a/i)
			{
				if ($ffind eq '*') { $find = $question[$sAnswer1]; }
				$question[$sAnswer1] =~ s/\Q$find\E/\Q$replace\E/gi;
				$question[$sAnswer1] =~ s/\\//g;
			}
			if ($codes =~ /h/i)
			{
				if ($ffind eq '*') { $find = $question[$sAnswer2]; }
				$question[$sAnswer2] =~ s/\Q$find\E/\Q$replace\E/gi;
				$question[$sAnswer2] =~ s/\\//g;
			}
			if ($codes =~ /b/i)
			{
				if ($ffind eq '*') { $find = $question[$sNickSubmitted]; }
				$question[$sNickSubmitted] =~ s/\Q$find\E/\Q$replace\E/gi;
				$question[$sNickSubmitted] =~ s/\\//g;
			}
			if ($question[$bFlaggedForEdit] =~ /FIX/)
				{ $question[$bFlaggedForEdit] = 0; }
			$question[$sCategories] = categorizequestion(@question);
			showquestion($cmdnick, @question);
			setquestion(@question);
		}
		return;
	}

	#
	# hint command -------------------------------------------------------------
	#
	if ($thecommand eq 'hint')
	{
		if ($nCurrentState != 6)
		{
#			&NOTICE($cmdnick, "No question has been asked.");
			return;
		}
		if ($bHintsOkay == 0)
		{
			&NOTICE($cmdnick, "No hints are being given this round.");
			return;
		}
		if ($bHinting)
		{
#			&NOTICE($cmdnick, "Already giving hints for this question.");
			return;
		}
		if (($tWhenAnythingAsked + $nFirstHint) > time())
		{
			&NOTICE($cmdnick, "Think a moment first, before asking for a hint.");
			return;
		}

		$bHinting = 1;
		$bHintsGiven = 0;
		$tWhenLastHint = 0;
		&hint();
		return;
	}

	#
	# join (team) command -------------------------------------------------------------
	#
	if ($thecommand eq 'defect')
	{
		if ($bTeams == 0)
		{
			&NOTICE($cmdnick, "We're not playing on teams. Just answer questions and have fun!");
			return;
		}

		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($player[$nTeam] == 1)
		{
			&NOTICE($cmdnick, "You're not on a team.");
			return;
		}

		&CHANMSG(qwizcolor(" $player[$sNick] defects from") . teambanner(@player) . "\!");
		$player[$nTeam] = 1;
		setplayer(@player);
		return;
	}
	if ($thecommand eq 'join')
	{
		if ($bTeams == 0)
		{
			&NOTICE($cmdnick, "We're not playing on teams. Just answer questions and have fun!");
			return;
		}

		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my $now = time();

		if ($player[$sFlags] !~ /[ox]/ &&
		    ($player[$tWhenMet] + $nTeamAdjust) > $now)
		{
			&NOTICE($cmdnick,
				"You have not yet had time to get to know people. " .
				"Try !joining a team again in " .
				describetimespan($target[$tWhenMet] + $nTeamAdjust - $now) .
				".");
			return;
		}

		if ($nJoinCost != 0 && $player[$nBonusPoints] < $nJoinCost)
		{
			my $s = ($nJoinCost == 1)? '' : 's';
			&NOTICE($cmdnick, "Joining a team costs " . cardinal($nJoinCost) . " TriviaBuck$s, which you don\'t have.");
			return;
		}

		if (lc($commandfields[1]) eq 'team')
			{ $commandfields[1] = $commandfields[2]; }

		# find the team they're naming

		my $old = $player[$nTeam];
		for $n (0 .. $#teamname)
		{
			if ($teamopen[$n] == 0)
				{ next; }

			if ($commandfields[1] =~ /^$teamname[$n]$/i)
			{
				if ($old == $n)
				{
					&NOTICE($cmdnick, "You're already on the $teamname[$old].");
					return;
				}
				if (countteam($n) >= $nTeamCap)
				{
					&NOTICE($cmdnick, "That team has no more room for new members!");
					return;
				}

				$player[$nTeam] = $n;
				$player[$nBonusPoints] -= $nJoinCost;
				setplayer(@player);
				my $s = 's'; $s = '' if ($player[$nBonusPoints] == 1);
				&NOTICE($cmdnick, "You have $player[$nBonusPoints] TriviaBuck$s remaining for other purchases.");
				&CHANMSG(qwizcolor(" Announcing ") . teamcolor(@player) . "!");
				return;
			}
		}

		my @teams = ();
		for $n (0 .. $#teamname)
		{
			if ($teamopen[$n] > 0 && countteam($n) < $nTeamCap)
				{ push(@teams, qwizcolor($teamname[$n], $n)); }
		}
		&NOTICE($cmdnick, "Open teams: " . join(', ', @teams) . ". Try !join \<teamname\>");

		return;
	}

	#
	# mirror/catcall commands -------------------------------------------------------------
	#
	if ($thecommand eq 'mirror' && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$fMirrorQwiz = 1;
		&NOTICE($cmdnick, "The next question asked will be a Mirror Quiz.");
		return;
	}
	if ($thecommand eq 'catcall' && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$fCatCall = 1;
		&NOTICE($cmdnick, "The next question asked will be a Cat Call Quiz.");
		return;
	}
	if ($thecommand eq 'shotgun' && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$fShotgun = 1;
		&NOTICE($cmdnick, "The next question asked will be a Shotgun Quiz.");
		return;
	}
	if ($thecommand eq 'blackout' && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$fBlackOut = 1;
		&NOTICE($cmdnick, "The next question asked will be a Black-Out Quiz.");
		return;
	}
	if ($thecommand eq 'potato' && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$fPotatoQwiz = 1;
		&NOTICE($cmdnick, "The next question asked will be a Hot Potato Quiz.");
		return;
	}

	#
	# magic woyd command -------------------------------------------------------------
	#
	if ($thecommand eq 'woyd' && $ispublic == 0 && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		my $now = time();
		if ($commandfields[1] eq '')
		{
			if ($sMagicWoyd eq '')
				{ &NOTICE($cmdnick, "There is no current magic woyd."); }
			else
				{ &NOTICE($cmdnick, "$sNickSetWoyd chose \'$sMagicWoyd\' " . describetimespan($now - $tWhenSetWoyd) . " ago."); }

			if ($sOldMagicWoyd ne '')
			{
				&NOTICE($cmdnick, "The old woyd was \'$sOldMagicWoyd\' hit by $sNickHitWoyd " . describetimespan($now - $tWhenHitWoyd) . " ago.");
			}
			return;
		}

		($sMagicWoyd) = $commandfields[1];
		$sNickSetWoyd = $player[$sNick];
		$tWhenSetWoyd = $now;

		&NOTICE($cmdnick, "From now on, the magic woyd is \'$sMagicWoyd\'.");
		return;
	}

	#
	# next command -------------------------------------------------------------
	#
	if ($thecommand eq 'next' && $player[$sFlags] =~ /n/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$tWhenAdvance = 0;
		return;
	}

	#
	# peek private command -------------------------------------------------------------
	#
	if ($thecommand eq 'peek' && $ispublic == 0 && $player[$sFlags] =~ /p/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] ne '')
		{
			if (!isquestion($commandfields[1]))
			{
				&PRIVMSG($cmdnick, "No known question with index $commandfields[1].");
			}
			else
			{
				my @question = getquestion($commandfields[1]);
				showquestion($cmdnick, @question);
			}
		}
		else
		{
			if ($isexpress == 0)
				{ showquestion($cmdnick, @CurrentQuestion); }
			else
				{ &NOTICE($cmdnick, join('|', @CurrentQuestion)); }
			
			&PRIVMSG($cmdnick, "You will be ignored from answering for peeking at the question.");
			$mined{lc($player[$sNick])} = 0;
		}
		noticeplayersbyflag('o', '', "$cmdnick is peeking at this question.");
		return;
	}
	if ($thecommand eq 'findplayer' && $player[$sFlags] =~ /x/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] ne '')
		{
			my ($pat) = ($rcommand =~ /$thecommand\s+(.*)\s*$/i );
			my %finds = ();
			foreach $nick (keys %players)
			{
				if ($players{$nick} =~ /$pat/i)
				{
					$finds{$nick} = $players{$nick};
				}
			}
			my @fk = (keys %finds);
			my $ft = $#fk+1;
			if ($ft > 8)
			{
				&NOTICE($cmdnick, "Too many players found.  ($ft total)");
			}
			else
			{
				&NOTICE($cmdnick, "Matching players ($ft total)");
				foreach $nick (keys %finds)
				{
					&NOTICE($cmdnick, $finds{$nick});
				}
			}
		}
		return;
	}
	if ($thecommand eq 'findquestion' && $player[$sFlags] =~ /c/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] ne '')
		{
			my ($pat) = ($rcommand =~ /$thecommand\s+(.*)\s*$/i );
			my %finds = ();
			foreach $index (keys %questions)
			{
				if ($questions{$index} =~ /$pat/i)
				{
					$finds{$index} = $questions{$index};
				}
			}
			my @fk = (keys %finds);
			my $ft = $#fk+1;
			if ($ft > 8)
			{
				&NOTICE($cmdnick, "Too many questions found.  ($ft total)");
				&NOTICE($cmdnick, "Some examples: " . join(', ', splice(@fk, 0, 8)));
			}
			else
			{
				&NOTICE($cmdnick, "Matching questions ($ft total)");
				foreach $index (keys %finds)
				{
					&NOTICE($cmdnick, $finds{$index});
				}
			}
		}
		return;
	}

	#
	# question command -------------------------------------------------------------
	#
	if ($thecommand eq 'question' && $player[$sFlags] =~ /n/ && $commandfields[1] =~ /^\d+$/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if (isquestion(int($commandfields[1])))
		{
			$nNextIndex = int($commandfields[1]);
			&NOTICE($cmdnick, "Next question: $nNextIndex.");
		}
		else
		{
			&NOTICE($cmdnick, "There is no such question, '$commandfields[1]'.");
		}
		return;
	}

	#
	# repeat command -------------------------------------------------------------
	#
	if ($thecommand eq 'repeat')
	{
		if ($nShotgun > 0)
			{ return; }

		if ($nCurrentState == 6)
		{
			putquiz();
		}
		else
		{
#			&CHANMSG("No question has been asked!");
		}
		return;
	}

	#
	# round command -------------------------------------------------------------
	#
	if ($thecommand eq 'round' && $player[$sFlags] =~ /z/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$fEndRound = 1;
		&NOTICE($cmdnick, "Round will end after this question.");
		return;
	}

	#
	# rules command -------------------------------------------------------------
	#
	if ($thecommand eq 'rules')
	{
		&NOTICE($cmdnick, qwizcolor(" How to play: ", 12) . qwizcolor(" Read a question, type the answer first. ", 13));
		&NOTICE($cmdnick, qwizcolor(" Be polite, and you'll be just fine. ", 4));
#		&NOTICE($cmdnick, qwizcolor(" More specific rules can be found at $homeurl/rules.shtml ", 4));
		return;
	}

	#
	# stats command -------------------------------------------------------------
	#
	if ($thecommand eq 'stats')
	{
		if (!isreportokay()) { &NOTICE($cmdnick, "Please wait a few moments and try again."); return; }

		my $who = $commandfields[1];
		$who = $cmdnick if ($who eq '');
		if (isplayer($who))
		{
			my @target = getplayer($who);
			my $r = int($target[$nTimesWon] / $nWinsPerRank);
			if ($r > 0 && isactive($who) && isauthed($who))
				{ &VOICE($target[$sNick]); }

			my $op = 0;
			if ($player[$sFlags] =~ /[mo]/) { $op = 1; }
			&statsplayer($cmdnick, $op, @target);
		}
		elsif (lc($who) eq lc($botnick))
		{
			&NOTICE($cmdnick, "I ask the questions, not answer them.\n");
		}
		else
		{
			&NOTICE($cmdnick, "I have no record of a player named $who.\n");
		}
		return;
	}

	#
	# team command -------------------------------------------------------------
	#
	if ($thecommand eq 'team')
	{
		if ($bTeams == 0)
		{
			&NOTICE($cmdnick, "We're not playing on teams. Just answer questions and have fun!");
			return;
		}

		foreach $b (0 .. $#teamname)
		{
			if ($teamopen[$b] == 0)
				{ next; }
			if ($commandfields[1] !~ /^$teamname[$b]$/i)
				{ next; }

			my %members = ();

			foreach $a (keys %players)
			{
				my @player = getplayer($a);
				if ($player[$sFlags] =~ /[*d]/) { next; }

				if ($player[$nTeam] == $b)
					{ $members{$player[$sNick]} = 1; }
			}

			my @membership = (sort keys %members);
			reverse @membership;

			my $line = qwizcolor(" Team $teamname[$b]: ", $b);
			while ($#membership >= 0)
			{
				$line .= qwizcolor(join(' ', splice(@membership, 0, 5)));
				&CHANMSG($line);
				$line = qwizcolor('     ');
			}

			last;
		}

		return;
	}

	#
	# teams command -------------------------------------------------------------
	#
	if ($thecommand eq 'teams' && $player[$sFlags] =~ /o/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] =~ /off|no|disable/i && $player[$sFlags] =~ /t/)
		{
			&NOTICE($cmdnick, "Team play is now off.");
			$bTeams = 0;
		}
		elsif ($commandfields[1] =~ /on|enable/i && $player[$sFlags] =~ /t/)
		{
			&NOTICE($cmdnick, "Team play is now on.");
			$bTeams = 1;
		}
		else
		{
			if ($bTeams == 0)
			{
				&NOTICE($cmdnick, "We're not playing on teams. Just answer questions and have fun!");
				return;
			}

			if (!isreportokay()) { &NOTICE($cmdnick, "Please wait a few moments and try again."); return; }

			teamsummary();
		}
		return;
	}

	#
	# tips command -------------------------------------------------------------
	#
	if ($thecommand eq 'tips')
	{
		if (!isreportokay()) { &NOTICE($cmdnick, "Please wait a few moments and try again."); return; }

		&PRIVMSG($cmdnick, "Thank you for adding questions!  The more the better!");
		&PRIVMSG($cmdnick, "To add questions that can be accepted quickly, please:");
		&PRIVMSG($cmdnick, "   * Check your spelling and grammar.");
		&PRIVMSG($cmdnick, "   * Check your facts. Nobody likes a wrong answer.");
		&PRIVMSG($cmdnick, "   * If the answer is a person's name, provide first and last names.");
		&PRIVMSG($cmdnick, "   * When including a name or title, use proper capitalization.");
		&PRIVMSG($cmdnick, "   * If it's a state or city, include country or state in the question or answer.");
		&PRIVMSG($cmdnick, "The operators review every question, so your help is appreciated!");
		return;
	}

	#
	# topic command -------------------------------------------------------------
	#
	if ($thecommand eq 'topic' && $player[$sFlags] =~ /t/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($commandfields[1] eq '' || $commandfields[1] =~ /off|no|disable/i)
		{
			&NOTICE($cmdnick, "Forced topic is now off.");
			$sForceTopic = '';
			picktopic();
		}
		else
		{
			$rcommand =~ /topic\s+(.+)$/i;
			$sForceTopic = $1;
			picktopic();
		}
		return;
	}

	#
	# vote command -------------------------------------------------------------
	#
	if ($thecommand eq 'vote')
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($bTeams == 0)
		{
			&NOTICE($cmdnick, "We're not playing on teams. Just answer questions and have fun!");
			return;
		}
		if ($player[$nTeam] == 1)
		{
			&NOTICE($cmdnick, "You're not on a team.");
			return;
		}

		# who WAS supported?

		my @target;
		my ($t, $a) = ('', '');
		if ($player[$sSupportCaptain] =~ /=/)
		{
			($t, $a) = split(/=/, $player[$sSupportCaptain]);
		}
		if (isplayer($a))
			{ @target = getplayer($a); }
		if (isplayer($a) && $target[$nTeam] != $player[$nTeam])
		{
			$a = '';
			$player[$sSupportCaptain] = $newplayer[$sSupportCaptain];
			setplayer(@player);
		}

		# report current support or an unknown new vote

		if (!defined($commandfields[1]) && !isplayer($a))
		{
			&NOTICE($cmdnick, "You're not supporting anyone for $teamname[$player[$nTeam]] Captain.");
			return;
		}
		if (!defined($commandfields[1]))
		{
			&NOTICE($cmdnick, "You're supporting $target[$sNick] for $teamname[$player[$nTeam]] Captain.");
			return;
		}
		if (!isplayer($commandfields[1]))
		{
			&NOTICE($cmdnick, "Can't find the player for whom you are voting.");
			return;
		}

		# check for valid new vote

		my @target = getplayer($commandfields[1]);
		if ($target[$nTeam] != $player[$nTeam])
		{
			&NOTICE($cmdnick, "$target[$sNick] is not on the $teamname[$player[$nTeam]].");
			return;
		}
		if (lc($a) eq lc($target[$sNick]) && $t == $player[$nTeam])
		{
			&NOTICE($cmdnick, "You're already supporting $target[$sNick] for $teamname[$player[$nTeam]] Captain.");
			return;
		}

		# set up new valid vote

		$player[$sSupportCaptain] = join('=', ($player[$nTeam], $target[$sNick]));
		setplayer(@player);

		if (lc($player[$sNick]) eq lc($target[$sNick]))
		{
			&NOTICE($cmdnick, "You've cast your vote to support yourself for $teamname[$player[$nTeam]] Captain.");
		}
		else
		{
			if (isactive($commandfields[1]))
				{ &NOTICE($commandfields[1], "$cmdnick supports you for $teamname[$player[$nTeam]] Captain."); }
			&NOTICE($cmdnick, "You've cast your vote to support $target[$sNick] for $teamname[$player[$nTeam]] Captain.");
		}
		return;
	}

	#
	# vowel command -------------------------------------------------------------
	#
	if ($thecommand eq 'vowel')
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		if ($nCurrentState != 6)
		{
			&NOTICE($cmdnick, "No question has been asked.");
			return;
		}
		elsif ($bHintsOkay == 0)
		{
			&NOTICE($cmdnick, "No hints are being given this round.");
			return;
		}

		if (lc($commandfields[1]) !~ /^[aeiou]$/)
		{
			&NOTICE($cmdnick, "usage:    !vowel <letter A E I O or U>    (example: !vowel E)");
			&NOTICE($cmdnick, "This costs one TriviaBuck, and will fill in any of that vowel in the hints.");
			return;
		}

		if (length($CurrentQuestion[$sAnswer1]) < 15)
		{
			&NOTICE($cmdnick, "The answer to this question is too short to buy a vowel.");
			return;
		}

		$a = 15;
		if (($tWhenAnythingAsked + $a) > time())
		{
			&NOTICE($cmdnick, "You can't buy a vowel in the first " . describetimespan($a) . " of the question.");
			return;
		}

		if ($player[$nBonusPoints] <= 0)
		{
			&NOTICE($cmdnick, "You don't have any TriviaBucks to spend on vowels.");
			return;
		}

		if (defined($vowel{lc($commandfields[1])}))
		{
			&NOTICE($cmdnick, "The vowel \'$commandfields[1]\' was already bought by $vowel{lc($commandfields[1])}.");
			return;
		}

		$vowel{lc($commandfields[1])} = $cmdnick;
		&CHANMSG(qwizcolor(" $cmdnick has just bought the vowel \'" . uc($commandfields[1]) . "\'\! ", $kAlternate, ($bChallenge? $kAlternateBack : $kQuestionBack)));

		$player[$nBonusPoints]--;
		my $s = 's'; $s = '' if ($player[$nBonusPoints] == 1);
		&NOTICE($cmdnick, "You have $player[$nBonusPoints] TriviaBuck$s remaining for other special purchases.");
		setplayer(@player);

		$bHinting = 1;
		$tWhenLastHint = 0;
		&hint(1);

		if ($CurrentQuestion[$sAnswer1] !~ /$commandfields[1]/i)
		{
			&CHANMSG(
				qwizcolor(" BAD BUY ", $kCongratsBack, $kCongrats) .
				qwizcolor(" This answer has no \'" . uc($commandfields[1]) . "\' vowels\! ", $kAlternate, ($bChallenge? $kAlternateBack : $kQuestionBack)));
		}

		return;
	}

	#
	# worm command -------------------------------------------------------------
	#
	if ($thecommand eq 'billboard' && $player[$sFlags] =~ /w/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		billboard($commandfields[1], $commandfields[2]);
	}
	if ($thecommand eq 'worm' && $player[$sFlags] =~ /w/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		&NOTICE($cmdnick, "Worm on q# $nWorm of $nQuestions. $#gmails unread gmails. Countermeasures " . ($bCounterMeasures? "on" : "off") . ".");
		showplayerstatus($cmdnick);

		if ($bScanVocab)
		{
			my @vocab = (sort { $saidvocab{$b} <=> $saidvocab{$a} } keys %saidvocab);
			my $n = ($#vocab)+1;
			splice(@vocab, 20);
			foreach $i (0 .. $#vocab)
			{
				$vocab[$i] .= '=' . $saidvocab{$vocab[$i]};
			}
			&NOTICE($cmdnick, "ScanVocab($n) " . join(' ', @vocab));
		}

		return;
	}

	#
	# zero command -------------------------------------------------------------
	#
	if ($thecommand eq 'zero' && $player[$sFlags] =~ /z/)
	{
		if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

		$fEndSeason = 1;
		&NOTICE($cmdnick, "Season scores will be zeroed at the end of this period.");
		return;
	}
}

#----------------------------------------------------------------------------

sub readoptions
{
	local($filename) = @_;
	if (!open(INFO, $filename))
	{
		print "Cannot read $filename.\n";
		return 0;
	}
	do
	{
		$optionsline = <INFO>;
		$optionsline =~ s/\n//;
		$optionsline =~ s/\r//;

	} while (!eof(INFO) && $optionsline =~ /^\s*\#/);

	if ($optionsline =~ /^\s*\#/)
		{ return 0; }

	($tWhenAnythingAsked,$bHintsOkay,$sNickStreak,$nNickStreak,$bTeams,$tWhenLastBackup,$bCategoryEnabled,$sForceTopic) = split(/\:/, $optionsline);

	do
	{
		$optionsline = <INFO>;
		$optionsline =~ s/\n//;
		$optionsline =~ s/\r//;
	} while (!eof(INFO) && $optionsline =~ /^\s*\#/);
	@teamname = split(/\:/, $optionsline);

	do
	{
		$optionsline = <INFO>;
		$optionsline =~ s/\n//;
		$optionsline =~ s/\r//;
	} while (!eof(INFO) && $optionsline =~ /^\s*\#/);
	@teamwins = split(/\:/, $optionsline);
	@teamwins = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) if !defined($teamwins[15]);

	do
	{
		$optionsline = <INFO>;
		$optionsline =~ s/\n//;
		$optionsline =~ s/\r//;
	} while (!eof(INFO) && $optionsline =~ /^\s*\#/);
	@teamseas = split(/\:/, $optionsline);
	@teamseas = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0) if !defined($teamseas[15]);

	do
	{
		$optionsline = <INFO>;
		$optionsline =~ s/\n//;
		$optionsline =~ s/\r//;
	} while (!eof(INFO) && $optionsline =~ /^\s*\#/);
	@teamopen = split(/\:/, $optionsline);
	@teamopen = (0,0,1,0,1,0,0,1,1,1,0,0,1,1,0,0) if !defined($teamopen[15]);

	close(INFO);
	1;
}

sub writeoptions
{
	local($filename) = @_;
	if (!open(INFO, ">$filename"))
	{
		print "Cannot write $filename.\n";
		return 0;
	}
	my @options = ($tWhenAnythingAsked,$bHintsOkay,$sNickStreak,$nNickStreak,$bTeams,$tWhenLastBackup,$bCategoryEnabled,$sForceTopic);
	print INFO "# time last asked | hints allowed | last streaker | how long a streak | teams okay | backup | topic\n";
	print INFO join(':', @options) . "\n";
	print INFO "# team names\n";
	print INFO join(':', @teamname) . "\n";
	print INFO "# team wins\n";
	print INFO join(':', @teamwins) . "\n";
	print INFO "# team season wins\n";
	print INFO join(':', @teamseas) . "\n";
	print INFO "# teams open\n";
	print INFO join(':', @teamopen) . "\n";
	close(INFO);

	1;
}

#----------------------------------------------------------------------------

sub putquiz
{
	my $questline = " $CurrentQuestion[$sQuestion] ";

	my $nShots = $nShotgun;
	if ($nShots > 0)
	{
		while ($nShots-- > 0)
		{
			my $p = int(rand()*length($questline) - 1) + 1;
			substr($questline,$p,1) = '*';
		}
		$questline =~ s/\*/$__kolor\*$__kolor$kQuestion\,$kQuestionBack$__bold$__bold/g;
	}

	if ($bBlackOut)
	{
		my @w = split(/ /, $questline);
		my @capw = ();
		my @loww = ();
		foreach $ww (@w)
		{
			if ($ww =~ /^[A-Z][a-z]+$/)
				{ push(@capw, $ww); }
			elsif ($ww =~ /^[a-z]+$/)
				{ push(@loww, $ww); }
		}

		shift(@capw); # throw away first capitalized word

		my $ww = $sBlackOut;
		if ($ww eq '')
		{
			if ($#capw >= 0)
				{ $ww = $capw[int(rand()*($#capw+1))]; }
			elsif ($#loww >= 0)
				{ $ww = $loww[int(rand()*($#loww+1))]; }
		}

		if ($ww ne '')
		{
			$sBlackOut = $ww;
			$questline =~ s/ $ww / ${__kolor}0,1 BLACKOUT $__kolor$kQuestion\,$kQuestionBack /;
		}
	}

	if ($bCounterMeasures > 0)
	{
		if (1)
		{
			my @cms = ('a', 'e', 'i', 'o', 'u', 'l', 'n', 'r', 's', 't');
			my $cm = $cms[int(rand()*($#cms+1))];
		}
	}

	my $bg = $kQuestionBack;
	$bg = $kAlternateBack if ($bChallenge > 0);

	my $a = qwizcolor(" Question $nQuizThisPeriod of $quizperperiod: ", $kAlternate, $bg);
	if ($bMirrorQwiz > 0)
	{
		$questline = "MIRROR: " . reverseprose($questline);
	}

	$a = $a . qwizcolor($questline, $kQuestion, $bg);
	&CHANMSG($a);
}

sub leaderboard
{
	local($shownick, $sortby, $topcount, $searchnick) = @_;

	if ($sortby < 0 || $sortby > $nPlayerPersistentInfo)
	{
		$sortby = $nTimesWon;
	}

	my %scores = ();
	my %rankings = ();
	my @player = ();
	foreach $nick (keys %players)
	{
		@player = getplayer($nick);
		if ($player[$sFlags] =~ /[*d]/) { next; }

		if ($player[$sortby] eq $newplayer[$sortby] ||
		    ($playerfieldnumeric[$sortby] > 0 && $player[$sortby] == 0))
		{
			next;
		}

		my $t = $player[$sortby];
		if ($playerfieldmeanqueue[$sortby] > 0)
		{
			my @qu = split(/,/, $t);
			if (($#qu+1) < $nMeanQueueLength) { next; }

			$t = 0;
			if ($#qu >= 0)
			{
				foreach (0 .. $#qu) { $t += $qu[$_]; }
			}
			$t /= ($#qu + 1);
		}

		$scores{$player[$sName]} = $t;
		$rankings{$player[$sName]} = $player[$nRank];
	}

	my @sorted = ();
	if ($playerfieldnumeric[$sortby])
		{ @sorted = (sort { $scores{$b} <=> $scores{$a} } keys %scores); }
	else
		{ @sorted = (sort { $scores{$a} cmp $scores{$b} } keys %scores); }
	if ($playerfieldmeanqueue[$sortby] > 0)
		{ @sorted = reverse(@sorted); }

	if ($searchnick eq '' || !isplayer($searchnick))
	{
		my $a = "";
		if ($topcount < 0)
		{
			$a = " Lowest ";
			@sorted = reverse(@sorted);
			$topcount = -$topcount;
		}
		elsif ($topcount > 0)
		{
			$a = " Top ";
		}
		if ($topcount != 0)
		{
			splice(@sorted, $topcount);
			$a .= ucfirst(cardinal($topcount));
		}

		$a .= " \'" . $playerfieldnames[$sortby] . "\' ";
		if ($shownick eq '')
			{ &CHANMSG(qwizcolor($a)); }
		else
			{ &PRIVMSG($shownick, qwizcolor($a)); }

		foreach $nick (@sorted)
		{
			$a = "   $nick (" . findrankname($rankings{$nick}) . "): ";

			if ($playerfieldtime[$sortby] > 0)
				{ $a .= localtime($scores{$nick}); }
			elsif ($playerfieldtimespan[$sortby] > 0)
				{ $a .= describetimespan($scores{$nick}); }
			else
				{ $a .= $scores{$nick}; }


			if ($shownick eq '')
				{ &CHANMSG(qwizcolor($a)); }
			else
				{ &PRIVMSG($shownick, qwizcolor($a)); }
		}
	}
	else
	{
		my $t = 0;
		my $x = $#sorted;
		foreach $nick (@sorted)
		{
			$t++;
			if (lc($nick) ne lc($searchnick)) { next; }

			$a = "$nick (" . findrankname($rankings{$nick}) . ") \#$t $playerfieldnames[$sortby] out of $x: ";

			if ($playerfieldtime[$sortby] > 0)
				{ $a .= localtime($scores{$nick}); }
			elsif ($playerfieldtimespan[$sortby] > 0)
				{ $a .= describetimespan($scores{$nick}); }
			else
				{ $a .= $scores{$nick}; }

			if ($shownick eq '')
				{ &CHANMSG(qwizcolor($a)); }
			else
				{ &PRIVMSG($shownick, qwizcolor($a)); }

			return $nick;
		}
	}

	return $sorted[0];
}

sub teamsummary
{
	if ($bTeams == 0)
		{ return; }

	foreach $b (0 .. $#teamname)
	{
		if ($teamopen[$b] == 0)
			{ next; }

		my %members = ();

		foreach $a (keys %active)
		{
			my @player = getplayer($a);
			if ($player[$nTeam] == $b)
				{ $members{$player[$sNick]} = 1; }
		}

		my $c = $aCaptains[$b];
		if ($c ne '') { $c = " (Captain $c)"; }
		my $a = join(' ', (keys %members));
		if ($a eq '')
			{ $a = '--'; }
		$a = qwizcolor(" Team $teamname[$b] ", $b) . qwizcolor("($teamseas[$b] wins)$c: $a ");
		&CHANMSG($a);
	}
}

sub tallyvotes
{
	if ($bTeams == 0)
		{ return; }

	#
	# tally new votes
	#

	%hCaptains = ();
	foreach $nick (keys %players)
	{
		my @player = getplayer($nick);
		if ($player[$nTeam] == 1) { next; }
		if ($player[$sSupportCaptain] !~ /=/) { next; }
		if ($player[$sFlag] =~ /[*d]/) { next; }

		my ($t, $a) = split(/=/, $player[$sSupportCaptain]);
		$a = lc($a);
		if (defined($hCaptains{$a}))
		{
			$hCaptains{$a}++;
		}
		else
		{
			if (!isplayer($a)) { next; }
			my @target = getplayer($a);
			if ($target[$nTeam] != $player[$nTeam]) { next; }

			$hCaptains{$a}++;
		}
	}

	#
	# cull the losers
	# (if there's a tie, they all lose)
	#
	my @nCaptains = (undef) x 16;
	foreach $nick (sort { $hCaptains{$b} <=> $hCaptains{$a} } keys %hCaptains)
	{
		my @player = getplayer($nick);
		my $t = $player[$nTeam];
		if (defined($nCaptains[$t]))
		{
			my $o = $nCaptains[$t];
			if ($hCaptains{$o} == $hCaptains{$nick})
			{
				delete $hCaptains{$o};
			}
			delete $hCaptains{$nick};
			next;
		}
		$nCaptains[$t] = $nick;
	}

	#
	# see who is inaugurated or resigned as captain
	#

	my %oCaptains = ();
	foreach $nick (@aCaptains)
	{
		$nick = lc($nick);
		if (!isplayer($nick)) { next; }
		$oCaptains{$nick} = 1;
		if (!defined($hCaptains{$nick}))
		{
			my @player = getplayer($nick);
			&CHANMSG("$teamname[$player[$nTeam]] votes out $player[$sNick] as team captain.");
		}
	}
	@aCaptains = (undef) x 16;
	foreach $nick (keys %hCaptains)
	{
		$nick = lc($nick);
		my @player = getplayer($nick);
		$hCaptains{$nick} = $player[$nTeam];
		$aCaptains[$player[$nTeam]] = $player[$sNick];
		if (!defined($oCaptains{$nick}) && $bFirstRound == 0)
		{
			&CHANMSG(
				qwizcolor(" Team $teamname[$player[$nTeam]] ", $player[$nTeam]) .
				qwizcolor(" votes for Captain $player[$sNick]\! "));
		}
	}
}

#----------------------------------------------------------------------------

sub gameactivateplayer
{
	local($nick) = @_;

	if (defined($hCaptains{lc($nick)}))
	{
		my @player = getplayer($nick);
		&CHANMSG(qwizcolor(" Welcome, $teamname[$player[$nTeam]] Captain $player[$sNick]\! ", $player[$nTeam]));
	}
}

sub picktopic
{
	if ($bMysteryCat != 0)
	{
		&TOPIC(qwizcolor(" Now playing a MYSTERY category, where the topic of questions is a question too! ", $kCategory, $kCategoryBack));
	}
	elsif ($sForceTopic eq '')
	{
		my $a = '';
		my $pick = int(rand() * 4);
		SWITCH:
		{
			($pick == 0) && do
				{
					my @kk = (keys %themes);
					my $k = $#kk;
					$a = "$botnick has questions in " . cardinal($k) . " categories!";
				};
			($pick == 1) && do { $a = "$botnick has thousands of questions, do you have the answers?"; };
			($pick == 2) && do { $a = "Challenge your memory and your typing speed!"; };
			($pick == 3) && do { $a = "Now playing with questions out of our $sCurrentTheme category!"; };
			($a eq '') && do { $a = "Come and check us out!"; };
		}
		&TOPIC(qwizcolor(" $a ", $kCategory, $kCategoryBack));
	}
	else
	{
		&TOPIC($sForceTopic);
	}
}

#----------------------------------------------------------------------------

sub worm
{
	for (1 .. 5)
	{
		$nWorm++;
		if ($CurrentQuestion[$nIndex] == $nWorm) { next; }
		if ($nWorm > $nQuestions) { $nWorm = 0; }
		if (!isquestion($nWorm)) { next; }

		my @question = getquestion($nWorm);
		if ($question[$bFlaggedForEdit] =~ /REVIEW|BURY/) { next; }

		if (1)
		{
			my $cats = categorizequestion(@question);
			$question[$sCategories] = $cats;

			($question[$sAnswer1]) = ($question[$sAnswer1] =~ /^\s*(.*?)\s*$/);
			($question[$sAnswer2]) = ($question[$sAnswer2] =~ /^\s*(.*?)\s*$/);

			@question = autoeditquestion(@question);

			if ($nMaxAsked < $question[$nTimesAsked])
				{ $nMaxAsked = $question[$nTimesAsked]; }
		}

		setquestion(@question);
	}
}

#----------------------------------------------------------------------------

sub nextstate
{
	$nCurrentState++;
        &DEBUGMSG("Going to next state: ". $statenames[$ncurrentState]);
	if (!defined($statenames[$nCurrentState]))
	{
                &DEBUGMSG("No such state; resetting to ". $statenames[0]);
		$nCurrentState = 0;
	}
	$tWhenAdvance = time() + $statetimes[$nCurrentState];
	if ($sCurrentTheme eq 'Speedy')
	{
		if ($nCurrentState == 6 || $nCurrentState == 1 || $nCurrentState == 2 || $nCurrentState == 3)
			{ $tWhenAdvance = time() + ($statetimes[$nCurrentState] / 3); }
	}
	elsif ($bChallenge)
	{
		if ($nCurrentState == 6 || $nCurrentState == 1 || $nCurrentState == 2 || $nCurrentState == 3)
			{ $tWhenAdvance = time() + ($statetimes[$nCurrentState] / 2); }
	}

	SWITCH:
	{
		($nCurrentState == 0) && do { &preperiod(); last; };
		($nCurrentState == 1) && do { &prequiz(); last; };
		($nCurrentState == 2) && do { &billboard(); last; };
		($nCurrentState == 3) && do { &breather(); last; };
		($nCurrentState == 4) && do { &announce(); last; };
		($nCurrentState == 5) && do { &askquiz(); last; };
		($nCurrentState == 6) && do { &listen(); last; };
		($nCurrentState == 7) && do { &answerquiz(); last; };
		($nCurrentState == 8) && do { &housekeeping(); last; };
		($nCurrentState == 9) && do { &postperiod(); last; };
		($nCurrentState == 10) && do { &periodbreather(); last; };
		($nCurrentState == 11) && do { &polling(); last; };
		($nCurrentState == 12) && do { &postpolling(); last; };
	}
}

sub processstate
{
	#
	# any mid-state processing such as the hint timing while listening
	#

	if ($nCurrentState == 6) { &listencycle(); }
}

sub checkflip
{
	my $bWin = -1;
	my $a = ' ';

	if ($sCoinFlip eq 'unknown' && $sCoinCall eq 'unknown')
	{
		$bWin = 0;
		$a .= "Too late. You forfeit your ";
	}
	elsif ($sCoinFlip eq $sCoinCall)
	{
		$bWin = 1;
		$a .= "Good call. " . ucfirst($sCoinFlip) . ". You keep your ";
	}
	elsif ($sCoinFlip ne 'unknown' && $sCoinCall ne 'unknown')
	{
		$bWin = 0;
		$a .= "Bad call. I flipped " . ucfirst($sCoinFlip) . ". I'm breaking your ";
	}

	if ($bWin < 0)
		{ return; }

	$a .= cardinal($nNickStreak) . " win streak, $sNickStreak. ";
	if ($bWin == 0)
	{
		$sNickStreak = '(nobody)';
		$nNickStreak = 0;
	}
	&CHANMSG(qwizcolor($a, $kAlternate, $kAnnounceBack));

	$bFlippingCoin = 0;
	$sCoinFlip = 'unknown';
	$sCoinCall = 'unknown';
}

sub choosewoyd
{
	if ($sCurrentWoyd eq '')
		{ return; }

	my @vocab = (sort { $saidvocab{$b} <=> $saidvocab{$a} } keys %saidvocab);
	my $hi = $saidvocab{$vocab[0]};
	if ($hi < 10)
		{ return; }

	my $w = '';

	my $i = 0;
	while ($i < 10)
	{
		$i++;

		my $b = int(rand() * ($#vocab+1));
		$b = 0 if $vocab[$b] eq '';
		$w = $vocab[$b];

		my $n = $saidvocab{$w};
		if ($n =~ /:/)
			{ $n = $1; }

		# Pick a rare, nonnull, nonplayer woyd.
		#
		if ($n <= ($hi / 5) && $w ne '' && !isplayer($w)) { last; }
	}

	if ($w eq '')
		{ return; }

	$sMagicWoyd = $w;
	$sNickSetWoyd = $botnick;
	$tWhenSetWoyd = $now;

	&CHANACTION("has picked a new magic woyd. If you mention it, you earn a TriviaBuck.");
}

sub makepotatoqwiz
{
#	my $t = int(rnd() * 2) + 1;
#	SWITCH:
#	{
#	($t == 0) && do
#		{
#			$CurrentQuestion[$nIndex] = '-';
#			$CurrentQuestion[$sQuestion] =
#				"Which $botchan player has the highest streak record?";
#			return 1;
#		};
#	($t == 1) && do
#		{
#			$CurrentQuestion[$nIndex] = '-';
#			$CurrentQuestion[$sQuestion] =
#				"Which $botchan player last said the word ?";
#			return 1;
#		};
#	}

	return 0;
}

#----------------------------------------------------------------------------

sub preperiod
{
	#
	# clear any period stats from all players
	#
        &DEBUGMSG("Starting preperiod sub");
	$nQuizThisPeriod	=	0;
	$bListening			=	0;
	my @nicks = keys %players;
	foreach $nick (@nicks)
	{
		my @player = getplayer($nick);
		$player[$nTimesWonPeriod] = 0;
		$player[$nTimesAskedPeriod] = 0;
		$player[$sSpeedBestWonPeriod] = 99999;
		$player[$nBestStreakWonPeriod] = 0;
		setplayer(@player);
	}
	writeplayers();
	writemail($mailfile);

	%themenominators = ();
	%themenominees = ();
	choosewoyd();
        &DEBUGMSG("finished wirteplayers writemail and chosewoyd");

	#
	# choose a theme for period questions: category, easy, hard
	#
	my $bRequestedTheme = 0;
	if ($sNextTheme ne '')
	{
		$sCurrentTheme = $sNextTheme;
		$bRequestedTheme = 1;
	}
	else
	{
		$sCurrentTheme = pickcategory($sCurrentTheme, ($quizperperiod * 3), '*');
	}
	$sNextTheme = '';
	$themetimes{$sCurrentTheme} = time();

	#
	# tell the players that a new period is beginning
	#

        # this is done in the main loop.
	#refreshbot();

	if ($fChallenge > 0)
	{
		@names = (keys %challengers);
		if (($#names+1) <= 1)
		{
			$fChallenge = 0;
		}
	}
	if ($fChallenge > 0)
	{
		$bChallenge = 1;
		$fChallenge = 0;
		$bHintsOkay = 0;

		&CHANMSG(qwizcolor(" - - Let the CHALLENGE begin! - - ", $kCongrats, $kCongratsBack));
		picktopic();
		&CHANMSG(qwizcolor(" A CHALLENGE round of $quizperperiod Quiz Questions in: $sCurrentTheme\! ", $kCongrats, $kCongratsBack));
		&CHANMSG(qwizcolor(" The prize for this challenge is $nChallengePot TriviaBucks\! ", $kCongrats, $kCongratsBack));

		my $a = join(', ', (sort keys %challengers));
		&CHANMSG(qwizcolor(" (Cheer for the challengers: $a!) ", $kCongratsBack, $kCongrats));
	}
	elsif ($fMysteryCat)
	{
		$bMysteryCat = 1;

		&CHANMSG(qwizcolor(" - - Let the MYSTERY ROUND begin! - - ", 9, $kPeriodicBack));
		picktopic();
		&CHANMSG(qwizcolor(" A round of $quizperperiod Quiz Questions in a MYSTERY topic\! ", $kPeriodic, $kPeriodicBack));
	}
	else
	{
		$bHintsOkay = 1;

		&CHANMSG(qwizcolor(" - - Let the game begin! - - ", 9, $kPeriodicBack));
		picktopic();
		&CHANMSG(qwizcolor(" A round of $quizperperiod Quiz Questions in: $sCurrentTheme\! ", $kPeriodic, $kPeriodicBack));
	}

	if ($sCurrentTheme eq 'Speedy')
		{ &CHANMSG(qwizcolor("(Speedy rounds have short words for answers, and less time per question\!)", 7)); }
	if ($thememines{$sCurrentTheme} ne '')
		{ &CHANMSG(qwizcolor("(MINEFIELD\!  Don't go for the obvious answer unless you know it's right.)", 4)); }

	#
	# first question of the period is quick-start to get rolling
	#
	if ($bFirstRound == 0)
		{ $nCurrentState = 3; }

	$bFirstRound = 0;
	$tWhenLastRound = time();

	#
	# output some log statistics
	#

	print "## active: " . join(' ', (sort keys %active)) . "\n";
	open(LOGFILE, ">>$logfile") || return;
	{
		print LOGFILE $tWhenLastRound . "\t";
		print LOGFILE $sCurrentTheme . "\t";
		print LOGFILE ($bRequestedTheme? "requested" : "random") . "\t";
		print LOGFILE ($bChallenge? "challenge" : "regular") . "\t";
		print LOGFILE join(',', (sort keys %active)) . "\t";
		print LOGFILE $nQuestions . "\t";
		print LOGFILE $nPlayers . "\t";
		print LOGFILE "\n";
	}
	close(LOGFILE);
        &DEBUGMSG("Exiting the preperiod sub");
}

sub prequiz
{
	$bListening			=	0;

	worm();

	#
	# do housekeeping
	#

	foreach $nick (keys %mined)
	{
		if ($mined{$nick} <= 0)
			{ delete $mined{$nick}; }
		else
			{ $mined{$nick}--; }
	}
}

sub billboard
{
	my $arg = shift;

	worm();

	#
	# report any pending announcements or jokes or sneak-peaks
	#


	my $n = $arg;
	if ($n eq '')
	{
		if ((rand() * 100) < 85)
		{
			$tWhenAdvance = 0;
			return;
		}
		$n = int(rand() * 14);
		if ($n == $nLastBillboard)
		{
			$tWhenAdvance = 0;
			return;
		}
	}

	my $ax = '';
	my $bx = 0;
	SWITCH:
	{
	($n == 0) && do
		{
			my $count = countcategoryquestions($sCurrentTheme);
			if ($count > 0)
			{
				$ax = '[Stats you can ignore]: ';
				$ax = $ax . "I have $count questions in the current category, $sCurrentTheme. Always accepting more. Do !add for details.";
			}
			last SWITCH;
		};
	($n == 1) && do
		{
			$ax = '[Stats you can ignore]: ';
			$ax = $ax . "I have $nQuestions questions in the database. Always accepting more. Do !add for details.";
			last SWITCH;
		};
	($n == 2) && do
		{
			$ax = '[Stats you can ignore]: ';
			my @k = (keys %players);
			$bx = $#k + 1;
			$ax = $ax . "I have " . cardinal($bx) . " players on file. Introduce your friends to me and $botchan!";
			last SWITCH;
		};
	($n == 3) && do
		{
			$ax = '[Stats you can ignore]: ';
			my @k = (keys %themes);
			$bx = $#k + 1;
			$ax = $ax . "I have " . cardinal($bx) . " different categories on file, but often choose from the $sGeneralTheme!";
			last SWITCH;
		};
	($n == 4) && do
		{
			my $bestnick = '';
			my $beststreak = 0;
			foreach $nick (keys %players)
			{
				my @player = getplayer($nick);
				if ($player[$sFlags] =~ /[*d]/) { next; }
				if ($player[$nBestStreakWonSeason] > $beststreak)
					{ $bestnick = $player[$sNick]; $beststreak = $player[$nBestStreakWonSeason]; }
			}
			if ($beststreak > 0)
			{
				$ax = '[Stats you can ignore]: ';
				$ax = $ax . $bestnick . " is the season's best streaker, winning " . cardinal($beststreak) . " in a row! ";
			}
			last SWITCH;
		};
	($n == 5) && do
		{
			my $bestnick = '';
			my $beststreak = 0;
			foreach $nick (keys %players)
			{
				my @player = getplayer($nick);
				if ($player[$sFlags] =~ /[*d]/) { next; }
				if ($player[$nBestStreakWon] > $beststreak)
					{ $bestnick = $player[$sNick]; $beststreak = $player[$nBestStreakWon]; }
			}
			if ($beststreak > 0)
			{
				$ax = '[Stats you can ignore]: ';
				$ax = $ax . $bestnick . " is the all-time best streaker, winning " . cardinal($beststreak) . " in a row! ";
			}
			last SWITCH;
		};
	($n == 6) && do
		{
			my $bestnick = '';
			my $beststreak = 0;
			foreach $nick (keys %players)
			{
				my @player = getplayer($nick);
				if ($player[$sFlags] =~ /[*d]/) { next; }
				if ($player[$nSubmissions] > $beststreak)
					{ $bestnick = $player[$sNick]; $beststreak = $player[$nSubmissions]; }
			}
			if ($beststreak > 0)
			{
				$ax = '[Stats you can ignore]: ';
				$ax = $ax . $bestnick . " has submitted " . cardinal($beststreak) . " questions! You can, too. See !add for details. ";
			}
			last SWITCH;
		};
	($n == 7) && do
		{
			if ($bTeams != 0)
			{
				$ax = '[Keep the tip]: ';
				$ax = $ax . "Teams are optional. To join a team, try !join for details.";
			}
			last SWITCH;
		};
	($n == 8) && do
		{
			$ax = '[Keep the tip]: ';
			$ax = $ax . "Check out '#AfterNET' for chatting while you are Quizing. Muhahaha !";
			last SWITCH;
		};
	($n == 9) && do
		{
			$ax = '[Keep the tip]: ';
			$ax = $ax . "Check the $botchan homepage at $homeurl for more info!";
			last SWITCH;
		};
	($n == 10) && do
		{
			$ax = '[Keep the tip]: ';
			$ax = $ax . "Introduce yourself. Try !asl <yourage>/<yourgender>/<yourcity>";
			last SWITCH;
		};
	($n == 11) && do
		{
			$ax = '[Keep the tip]: ';
			$ax = $ax . "Got a webpage or email of your own?  Try !url <yoururl> or !url <youremail>";
			last SWITCH;
		};
	($n == 12) && do
		{
			$ax = '[Keep the tip]: ';
			$ax = $ax . "Between rounds, let the $botnick process the scores while you take a breather.";
			last SWITCH;
		};

	($n == 13) && do
		{
			if ($bScanVocab)
			{
				my $w = shift;
				if ($w eq '')
				{
					my @vocab = (sort { $saidvocab{$b} <=> $saidvocab{$a} } keys %saidvocab);
					my $b = int(rand() * ($#vocab+1) / 2);
					$b = 0 if $vocab[$b] eq '';
					$w = $vocab[$b];
				}
				my $n = $saidvocab{$w};
				if ($n =~ /:/)
					{ $n = 1; }
				my $s = '';
				$s = 's' if ($n != 1);
				$ax = '[Stats you can ignore]: ';
				$ax = $ax . "The word '$w' has been said by players at least $n time$s since $botnick powered-up.";
			}
			last SWITCH;
		};

	($n == 14) && do
		{
			my $who = shift;
			$who = $sLastRanked if ($who eq '');
			if ($who ne '')
			{
				my @player = getplayer($who);
				my $rname = &findrankname($player[$nRank]);
				my $age = time() - $player[$tWhenMet];
				$age /= (24*60*60);
				my $rank = $player[$nRank];
				$rank = 1 if ($rank == 0);
				my $daysperrank = (int(($age / $rank) * 100)) / 100;
				$ax = '[Stats you can ignore]: ';
				if ($who eq $sLastRanked)
					{ $ax .= "$sLastRanked was the most recent player to earn a new rank: "; }
				else
					{ $ax .= "$who is now rank: "; }
				$ax .= "$rname; ";
				$ax .= "averaging $daysperrank days per rank since their first win.";
			}
			last SWITCH;
		};
	}

	if ($ax eq '')
		{ return; }

	$nLastBillboard = $n;
	&CHANMSG(irccolor($ax, 14));
}

sub breather
{
	$bListening		=	0;

	worm();

#	idlecheck();

	my $acts = (keys %active);
	if ($#acts < 8)
	{
		$tWhenAdvance = 0;
		return;
	}
}

sub isgoodquestion
{
	# can't show if broken
	if ($CurrentQuestion[$sQuestion] eq '')
		{ return 0; }

	# can't show if unreviewed or buried
	if ($CurrentQuestion[$bFlaggedForEdit] =~ /REVIEW|BURY/)
		{ return 0; }

	# can't ask too soon
	if (($CurrentQuestion[$tWhenLastAsked] + $nDontRepeat) > time())
		{ return 0; }

	# can't ask big number answers or huge answers when hints unavailable
	if (($bHintsOkay == 0) && ($CurrentQuestion[$sAnswer1] =~ /^\d+$/))
		{ return 0; }
	if (($bHintsOkay == 0) && (length($CurrentQuestion[$sAnswer1]) > 20))
		{ return 0; }

	# catcalls must have exactly one category
	if (($fCatCall > 0) && (($CurrentQuestion[$sCategories] =~ /\+/) || ($CurrentQuestion[$sCategories] eq '')))
		{ return 0; }

	# shotguns or blackouts have to be longer questions
	if ((($fShotgun > 0) || ($fBlackOut > 0)) && (length($CurrentQuestion[$sQuestion]) < 50))
		{ return 0; }

	# can show if category matches theme
	if ($sCurrentTheme eq $sGeneralTheme)
		{ return 1; }
	if ($CurrentQuestion[$sCategories] ne '' &&
	    $CurrentQuestion[$sCategories] =~ /$sCurrentTheme/)
	{
		return 1;
	}

	# can't show otherwise
	0;
}

sub announce
{
	$bListening		=	0;

	$sCoinFlip = 'unknown';
	$sCoinCall = 'unknown';
	if ($bFlippingCoin > 0)
		{ checkflip(); }

	#
	# perhaps there's some last-minute marking that needs to get saved
	#
	setquestion(@CurrentQuestion);

	#
	# choose the next appropriate question to be asked
	#
	if ($nNextIndex >= 0 && isquestion($nNextIndex))
	{
		@CurrentQuestion = getquestion($nNextIndex);
		$nNextIndex = -1;
	}
	else
	{
		my $tries = 0;
		my @k = keys %questions;
		do
		{
			my $pick = int(rand() * ($#k + 1));
			@CurrentQuestion = getquestion($k[$pick]);
			$tries++;
		} while (isgoodquestion() == 0 && $tries < 1000);
	}

	if (isgoodquestion() == 0)
	{
		# too bad, going with the last lousy pick
		print "failed to find a question in theme\n";
	}

	#
	# prepare players for upcoming question
	#
	my $a = " Quiz Time! ";

	if ($CurrentQuestion[$nTimesAsked] == 0)
		{ $a .= "This one's never been asked... "; }
	elsif ($CurrentQuestion[$nTimesHit] == 0)
		{ $a .= "This one's never been answered... "; }
	elsif ($CurrentQuestion[$sNickLastHit] eq '')
		{ $a .= "Nobody got this one last time... "; }
	elsif ($CurrentQuestion[$nTimesHit] < ($CurrentQuestion[$nTimesAsked]/2))
		{ $a .= "This one's a toughy... "; }
	elsif ($CurrentQuestion[$nTimesHit] > ($nMaxAsked*3/4))
		{ $a .= "This one's a favorite... "; }
	else
		{ $a .= "Get ready... "; }

	&CHANMSG(qwizcolor($a, $kAnnounce, $kAnnounceBack));

	if (isactive($CurrentQuestion[$sNickSubmitted]))
		{ &NOTICE($CurrentQuestion[$sNickSubmitted], "Thanks for submitting this one!"); }

	#
	# pick special rules
	# prepare players for any special rules
	#
	$nShotgun = 0;
	$bBlackOut = 0;
	$bCatCall = 0;
	$nBounty = 0;
	$bMirrorQwiz = 0;
	if ($bChallenge)
	{
		&CHANMSG(qwizcolor(
			"(CHALLENGE\! Cheer for " . join(', ', (sort keys %challengers)) . "\!)",
			$kAnnounce, $kAnnounceBack));
	}
	elsif ($nNickStreak > 5)
	{
		my $s = '';
		$nBounty = int(($nNickStreak - 5) / 3) + 1;
		if ($nBounty < 1)
			{ $nBounty = 1; }
		if ($nBounty != 1)
			{ $s = 's'; }
		&CHANMSG(qwizcolor(
			"(BOUNTY\! $sNickStreak is too good. " .
			"Break the streak, and get $nBounty TriviaBuck$s!)",
			$kAnnounce, $kAnnounceBack));
	}
	elsif ($fMirrorQwiz > 0 ||
	    ((rand() * 100) < $nChanceMirrorQwiz))
	{
		if ($fMirrorQwiz > 0 ||
		    ($CurrentQuestion[$sCategories] =~ /Speedy/ && $sCurrentTheme ne 'Speedy'))
		{
			$bMirrorQwiz = 1;
			&CHANMSG(qwizcolor(
				'(MIRROR QUIZ! Question is backwards. ' .
				'Answer gets a TriviaBuck, answer BACKWARDS for two!)',
				$kAnnounce, $kAnnounceBack));
			$fMirrorQwiz = 0;
		}
	}
	elsif ($fCatCall > 0 ||
		(($sCurrentTheme eq $sGeneralTheme) &&
		($CurrentQuestion[$sCategories] !~ /\+/) &&
		($CurrentQuestion[$sCategories] ne '') &&
		((rand() * 100) < $nChanceMirrorQwiz)))
	{
		$bCatCall = 1;
		%catscalled = ();
		&CHANMSG(qwizcolor(
			'(CATCALL! This question belongs to only one category. ' .
			'Name the category before someone gives the answer, get a TriviaBuck.)',
			$kAnnounce, $kAnnounceBack));
		$fCatCall = 0;
	}
	elsif ($fShotgun > 0 ||
		((rand() * 100) < $nChanceMirrorQwiz))
	{
		$nShotgun = int(length($CurrentQuestion[$sQuestion]) / 4) + 1;
		&CHANMSG(qwizcolor(
			'(SHOTGUN! This question is the victim of a shotgun blast. ' .
			'If you can answer it, you get a TriviaBuck.  Note!  No repeats.)',
			$kAnnounce, $kAnnounceBack));
		$fShotgun = 0;
	}
	elsif ($fBlackOut > 0 ||
		((rand() * 100) < $nChanceMirrorQwiz))
	{
		$bBlackOut = 1;
		%catscalled = ();
		$sBlackOut = '';
		&CHANMSG(qwizcolor(
			'(BLACKOUT! This question has something missing. ' .
			'Fill in the blackout before someone gives the answer, get a TriviaBuck.)',
			$kAnnounce, $kAnnounceBack));
		$fBlackOut = 0;
	}
	elsif ($fPotatoQwiz > 0 ||
		(($sCurrentTheme ne $sGeneralTheme) &&
		((rand() * 100) < $nChanceMirrorQwiz)))
	{
		if (makepotatoqwiz())
		{
			$bPotatoQwiz = 1;
			&CHANMSG(qwizcolor(
				"(QUIZ POTATO\! This question is about $botchan itself! " .
				'Answer this, and get a TriviaBuck.)',
				$kAnnounce, $kAnnounceBack));
		}
		$fPotatoQwiz = 0;
	}
	# elsif here

	#

	if ($CurrentQuestion[$bFlaggedForEdit] =~ /FIX\((.*)\)$/)
	{
		noticeplayersbyflag('a', '', "This is question $CurrentQuestion[$nIndex], with a flag for fix ($1).");
	}
	noticeplayersbyflag('g', '', "Question $CurrentQuestion[$nIndex]; answer $CurrentQuestion[$sAnswer1].");
}

sub askquiz
{
	$bHinting		=	0;
	$nHintsGiven	=	0;
	$tWhenLastHint	=	0;
	$nWinPlaceShow	=	0;
	$bTimeIsUp		=	0;
	@sNickFinish	=	('(nobody)', '(nobody)', '(nobody)');
	%hNickFinish	=	();
	%vowel			=	();

	#
	# ask the question
	#

	$nQuizThisPeriod++;
	putquiz();

	$tWhenAnythingAsked = time();
	$CurrentQuestion[$nTimesAsked]++;
	$CurrentQuestion[$tWhenLastAsked] = $tWhenAnythingAsked;
	setquestion(@CurrentQuestion);
	$bListening = 1;
	$bMineHit = 0;
	$tWhenAdvance = 0;
}

sub listen
{
	worm();

	#
	# nothing to do to get the listening state going
	#
}

sub hint
{
	my ($bForce) = @_;
	$bForce = 0 if !defined($bForce);

	#
	# if hints requested, is it time for one?
	#

	if ($bHintsOkay == 0 || $bHinting == 0)
		{ return; }

	if (time() < $tWhenLastHint + $nHintsRate)
		{ return; }

#	idlecheck();

	if ($bForce == 0 && $nHintsGiven >= $nMaxHints)
		{ return; }

	$nHintsGiven++;

        &DEBUGMSG("Giving next hint");
	my $answer = $CurrentQuestion[$sAnswer1];

	# example:  "Dr. Zhivago" -> "--. -------"
	#
	my $clue = $answer;
	$clue =~ tr/[a-zA-Z0-9]/-/;

	# add any purchased vowels
	# example:  "Dr. Zhivago" (bought A) -> "--. ----a--"
	#
	my $n = length($answer);
	for $i (1 .. $n)
	{
		if (!defined($vowel{lc(substr($answer,$i,1))}))
			{ next; }
		substr($clue,$i,1) = substr($answer,$i,1);
	}

	# add some letters
	# example:  "Dr. Zhivago" (hint 4) -> "Dr. Zh-----"
	#
	my $n = $nHintsGiven-1;
	$j = 0;
	for $i (1 .. $n)
	{

# Old section of hint routine
#		while ($j < length($clue) && (substr($clue,$j,1) ne '-' || substr($answer,$j,1) eq '-'))
#			{ $j++; }
#		substr($clue,$j,1) = substr($answer,$j,1);

#Start of new section of hint routine

         my $l = length($answer); #$l is length of the answer
         my @clue_parts;          #Points to different parts of answer seperated by spaces
         $clue_parts[0] = 0;      #First part always points to beginning of the answer
         my $current_part = 1;    #Index of which part of answer $clue_parts is at.

         #This loop sets up @clue_parts
         for $j (1 .. $l)
         {
            #If current point in answer is a space
            if (substr($answer, $j, 1) eq ' ')
            {
               #Find the next point in answer that is either a number or a letter
               while ((substr($answer, $j + 1, 1) =~ /\W/)&&($j + 1 <= $l))
               {
                  $j++;
               }
            
               #Test to make sure the while loop did not exceed the answer string
               if ($j + 1 <= $l)
               {
                  #Set clue_parts to this point, in go to next point and next part
                  $clue_parts[$current_part] = $j + 1;
                  $j = $j + 2;
                  $current_part++;
               }
            }
         }

         my $nParts = $current_part;     #Number of different parts to the answer
         my $clue_location = -1;         #Points to the spot in the answer to give as next hint

         #While no clue location is given
         while ($clue_location == -1)   
         {
            #For each part of the clue
            for ($j = 0; $j < $nParts; $j++)
            { 
               #if the current location of clue is a digit or is a letter
               if (substr($clue, $clue_parts[$j], 1) =~ /\w/)
               {
                  #Set clue parts to next character, provided it is still within the answer
                  if ($clue_parts[$j] + 1 <= $l)
                  {
                     $clue_parts[$j]++;
                  }
               }
               #Else, this is the spot for the next hint, set clue location and exit
               else
               {
                 $clue_location = $clue_parts[$j];
                  $j = $nParts + 1;
               }
            }
         }
         substr($clue, $clue_location, 1) = substr($answer, $clue_location, 1);
# End of new section of hint routine
	}

	&CHANMSG($__kolor . '14' . "Hint: " . $clue);

	$tWhenLastHint = time();
}

sub listencycle
{
	&hint();
}

sub checkanswer
{
	local($said,@player) = @_;

	#
	# can we ignore this player?
	#

	if ($bListening == 0)
		{ return; }

	if ($bIgnoreMined != 0)
	{
		if (defined($mined{lc($player[$sNick])}))
			{ return; }
	}

	if ($bChallenge)
	{
		if ($nChallengeRank > 0)
		{
			if ($player[$nRank] < $nChallengeRank)
			{
				return;
			}
		}
		else
		{
			if (!defined($challengers{lc($player[$sNick])}))
			{
				return;
			}
		}
	}

	#
	# did this player answer right?
	#

	my $hit = 0;
	my $bAnsweredMirror = 0;

	my $a1 = $CurrentQuestion[$sAnswer1];
	my $a2 = $CurrentQuestion[$sAnswer2];
	($said) = ($said =~ /^\s*(.*?)\s*$/);

	if (!$bPotatoQwiz && $a1 !~ /[0-9]/ && $a2 !~ /[0-9]/)
	{
		$a1 =~ tr/a-zA-Z0-9 //cd;
		$a2 =~ tr/a-zA-Z0-9 //cd;
		$said =~ tr/a-zA-Z0-9 //cd;
	}

# &DEBUGMSG("\'$said\' vs \'$a1\' or \'$a2\'");

	if (lc($said) eq lc($a1))
		{ $hit = 1; }
	elsif (lc($said) eq lc($a2))
		{ $hit = 1; }
	elsif ($bMirrorQwiz > 0)
	{
		if (lc($said) eq reverseprose(lc($a1)))
			{ $hit = 1; $bAnsweredMirror = 1; }
		elsif (lc($said) eq reverseprose(lc($a2)))
			{ $hit = 1; $bAnsweredMirror = 1; }
	}

	if ($bCatCall > 0 &&
		(!defined($catscalled{$player[$sNick]})) &&
		(lc($said) eq lc($CurrentQuestion[$sCategories])))
	{
		$catscalled{$player[$sNick]} = 1;
		$player[$nBonusPoints]++;
		setplayer(@player);
		&NOTICE($player[$sNick], "You earned a TriviaBuck for answering the Cat Call!");
		return;
	}

	if ($bBlackOut > 0 && $sBlackOut ne '' &&
		(!defined($catscalled{$player[$sNick]})) &&
		(lc($said) eq lc($sBlackOut)))
	{
		$catscalled{$player[$sNick]} = 1;
		$player[$nBonusPoints]++;
		setplayer(@player);
		&NOTICE($player[$sNick], "You earned a TriviaBuck for seeing through the Black Out!");
		return;
	}

	if (($hit == 0) && ($thememines{$sCurrentTheme} ne ''))
	{
		my $mine = lc($thememines{$sCurrentTheme});
		if (lc($said) =~ /$mine/)
		{
			if ($bMineHit == 0)
			{
				&CHANMSG(irccolor(">BOOM\!<",4));
				$bMineHit = 1;
			}
			if ($player[$nBonusPoints] > 0)
			{
				&NOTICE($player[$sNick], irccolor(">BOOM\!<",4) . " Answering '$mine' in this $sCurrentTheme MINEFIELD cost one TriviaBuck, and $botnick ignores you for this question.");
				$mined{lc($player[$sNick])} = 0;

				if (!isauthed($player[$sNick]))
				{
					qwizban($player[$sNick], $cmdhost, $botnick, "Unauthorized!", 15);
					&PRIVMSG($player[$sNick], "You need to show authorization before playing.  Next time, try !help auth");
					return;
				}

				$player[$nBonusPoints]--;
				setplayer(@player);
			}
			elsif ($player[$tWhenMet] + (7*24*60*60) > time())
			{
				&NOTICE($player[$sNick], irccolor(">BOOM\!<",4) . " Answering '$mine' in this $sCurrentTheme MINEFIELD would cause $botnick to ignore you for this question, but since you're new, you get a break.");
				$mined{lc($player[$sNick])} = 0;
			}
			else
			{
				&NOTICE($player[$sNick], irccolor(">BOOM\!<",4) . " Answering '$mine' in this $sCurrentTheme MINEFIELD causes $botnick to ignore you for this question.");
				$mined{lc($player[$sNick])} = 0;
			}
		}
	}

	if ($hit == 0 || defined($hNickFinish{$player[$sNick]}))
		{ return; }

	#
	# a winner! or something
	#

	$bCatCall = 0;
	$hNickFinish{$player[$sNick]} = $nWinPlaceShow;
	$sNickFinish[$nWinPlaceShow] = $player[$sNick];

	my $speed = time() - $tWhenAnythingAsked;
	my $wps = " takes the Quiz!   (" . describetimespan($speed) . ") ";
	if ($nWinPlaceShow == 1)
	{
		$wps = " comes in second! ";

		my $r = int($player[$nTimesFinishedSecond] / $nWinsPerRank);
		$player[$nTimesFinishedSecond]++;

		if ($r < int($player[$nTimesFinishedSecond] / $nWinsPerRank))
		{
			&NOTICE($player[$sNick], "You earned a TriviaBuck for another " . cardinal($nWinsPerRank) . " close calls!");
			$player[$nBonusPoints]++;
		}
		&setplayer(@player);
	}
	elsif ($nWinPlaceShow == 2)
	{
		$wps = " finishes third! ";
	}

	my $a = qwizcolor(" ") . teamcolor(@player) . qwizcolor($wps);

	&CHANMSG($a);

	#
	#
	if ($nWinPlaceShow == 0)
	{
		my $best = '';

		if ($bTeams != 0)
		{
			$teamwins[$player[$nTeam]]++;
			$teamseas[$player[$nTeam]]++;
		}

		$player[$nTimesWon]++;
		$player[$tWhenLastWon] = time();
		if ($speed < $player[$sSpeedBestWon])
		{
			$player[$sSpeedBestWon] = $speed;
			$best = ' (a personal best speed!)';
		}

		$player[$nTimesWonPeriod]++;
		if ($speed < $player[$sSpeedBestWonPeriod])
			{ $player[$sSpeedBestWonPeriod] = $speed; }

		$player[$nTimesWonSeason]++;
		if ($speed < $player[$sSpeedBestWonSeason])
		{
			$player[$sSpeedBestWonSeason] = $speed;
			if ($best eq '') { $best = ' (a personal best speed this season!)'; }
		}

		my @qu = split(/,/, $player[$sMeanSpeedQueue]);
		push(@qu, $speed);
		if ($#qu >= $nMeanQueueLength)
			{ splice(@qu, 0, $nMeanQueueLength - $#qu + 1); }
		$player[$sMeanSpeedQueue] = join(',', @qu);

		# bonuses

		if ($bHintsOkay > 0 && $nHintsGiven == 0 && length($said) > 20)
		{
			$player[$nBonusPoints]++;
			&NOTICE($player[$sNick], "You earned a TriviaBuck for typing a long answer BLIND!");
		}

		if ($bMirrorQwiz)
		{
			$player[$nBonusPoints]++;
			&NOTICE($player[$sNick], "You earned a TriviaBuck for answering a MIRROR quiz!");

			if ($bAnsweredMirror)
			{
				$player[$nBonusPoints]++;
				&NOTICE($player[$sNick], "You earned a TriviaBuck for answering a Mirror Quiz BACKWARDS. Awesome!");
			}
		}
		if ($nShotgun > 0)
		{
			$player[$nBonusPoints]++;
			&NOTICE($player[$sNick], "You earned a TriviaBuck for answering a SHOTGUN quiz!");
		}

		# if nearing end of nontrivial round,
		if (($quizperperiod > 4) && ($nQuizThisPeriod >= ($quizperperiod-1)))
		{
			# and leading team has a WIPEOUT chance,
			my @sorted = (sort { $teamscores{$b} <=> $teamscores{$a} } keys %teamscores);
			my $b = $sorted[0];
			if (defined($b) && ($b != 1) && ($teamscores{$b} == ($nQuizThisPeriod-1)))
			{
				# and answer is hit by non-teammember,
				if ($player[$nTeam] != $b)
				{
					$player[$nBonusPoints]++;
					&NOTICE($player[$sNick], "You earned a TriviaBuck for SABOTAGE!");
					&CHANMSG($player[$sNick], "$player[$sNick] destroys Team $teamname{$b}'s WIPEOUT hopes!");
				}
			}
		}

		# streaking

		if ($player[$sNick] ne $sNickStreak)
		{
			if ($nNickStreak > 1)
			{
				my @defeated = getplayer($sNickStreak);
				$a = qwizcolor(" ") . teamcolor(@player) . qwizcolor(" ended ") . teamcolor(@defeated);
				$a = $a . qwizcolor("'s streak of " . cardinal($nNickStreak) . " wins! ");
				&CHANMSG($a);
			}
			$sNickStreak = $player[$sNick];
			$nNickStreak = 1;

			if ($nBounty > 0)
			{
				my $s = '';
				if ($nBounty != 1)
					{ $s = 's'; }
				$player[$nBonusPoints] += $nBounty;
				&NOTICE($player[$sNick], "Bounty prize of $nBounty TriviaBuck$s for breaking the streak!");
			}
		}
		else
		{
			$nNickStreak++;
			if ($nNickStreak > $player[$nBestStreakWon])
			{
				$player[$nBestStreakWon] = $nNickStreak;
				$best = $best . ' (a personal best streak!)';
			}
			if ($nNickStreak > $player[$nBestStreakWonPeriod])
			{
				$player[$nBestStreakWonPeriod] = $nNickStreak;
			}
			if ($nNickStreak > $player[$nBestStreakWonSeason])
			{
				$player[$nBestStreakWonSeason] = $nNickStreak;
				if ($best eq '') { $best = ' (a personal best streak this season!)'; }
			}
			if ($nNickStreak > 1)
			{
				$a =
					qwizcolor(" ") .
					teamcolor(@player) .
					qwizcolor(" is streaking! " .
						ucfirst(cardinal($nNickStreak)) . " wins in a row and counting! ");
				&CHANMSG($a);
			}
		}

		$nBounty = 0;

		# gratuitous credits

		if ($player[$sNick] eq $CurrentQuestion[$sNickLastHit])
		{
			&CHANMSG(qwizcolor(" Hey! $player[$sNick] answered this question last time it came up, too! ", 7));
		}

		if ($best ne '')
			{ &NOTICE($player[$sNick], $best); }

		my $r = int($player[$nTimesWon] / $nWinsPerRank);
		if ($player[$nTimesWon] == 1)
		{
			&CHANMSG(qwizcolor("*** $player[$sNick] has just answered their first question! Welcome to $botchan! ***", $kCongrats, $kCongratsBack));
			$player[$nBonusPoints]++;
			&NOTICE($player[$sNick], "You've been given one TriviaBuck for special purchases.");
		}
		elsif ($r > $player[$nRank])
		{
			$player[$nRank] = $r;
			my $rname = &findrankname($r);
			&CHANMSG(qwizcolor("*** $player[$sNick] has just advanced to rank " . cardinal($player[$nRank]) . ": $rname! ***", $kCongrats, $kCongratsBack));
			$sLastRanked = $player[$sNick];
			if (isauthed($player[$sNick]))
				{ &VOICE($player[$sNick]); }
		}
		else
		{
			$r++;
			my $rname = findrankname($r);
			my $goal = $nWinsPerRank - ($player[$nTimesWon] % $nWinsPerRank);
			my $s = ($goal == 1)? '' : 's';
			&NOTICE($player[$sNick], " ($goal more win$s to $rname)");
			#if ($player[$nRank] > 0 && isauthed($player[$sNick]))
			#	{ &VOICE($player[$sNick]); }
		}

		# record stats for player and question

		&setplayer(@player);

		$CurrentQuestion[$nTimesHit]++;
		$CurrentQuestion[$tWhenLastHit] = time();
		$CurrentQuestion[$sNickLastHit] = $player[$sNick];
		setquestion(@CurrentQuestion);

	}

	$nWinPlaceShow++;
	if ($nWinPlaceShow >= 3)
	{
		$bListening = 0;
	}

	if (($nCurrentState == 5) || ($nCurrentState == 6))
	{
		$nCurrentState = 6;
		$tWhenAdvance = 0;
	}
}

sub answerquiz
{
	#
	# either someone answered it properly, or time expired
	# if time expired, tell the players too bad
	# if not, then someone won and others may still place or show
	#

	$bHinting		=	0;
	$nHintsGiven	=	0;

	if ($nWinPlaceShow == 0)
	{
		$bListening	=	0;
		&CHANMSG(
			qwizcolor(" No winners. ", $kAlternate, ($bChallenge? $kAlternateBack : $kQuestionBack)) .
			qwizcolor(" Time is up! ", $kQuestion, ($bChallenge? $kAlternateBack : $kQuestionBack)));
		if ($bChallenge)
		{
			my $a = qwizcolor(" The answer: ", $kAlternate, ($bChallenge? $kAlternateBack : $kQuestionBack));
			$a = $a . qwizcolor(" $CurrentQuestion[$sAnswer1] ", $kQuestion, ($bChallenge? $kAlternateBack : $kQuestionBack));
			&CHANMSG($a);
		}

		$CurrentQuestion[$sNickLastHit] = '';
		setquestion(@CurrentQuestion);

		if ($nNickStreak > 0 && isactive($sNickStreak) == 0)
		{
			$sNickStreak = '(nobody)';
			$nNickStreak = 0;
		}

		if ($nNickStreak >= 2 && isactive($sNickStreak) > 0)
		{
			if ($bChallenge > 0)
			{
				$sNickStreak = '(nobody)';
				$nNickStreak = 0;
				&CHANMSG(
					qwizcolor(" $sNickStreak\'s streak of " . cardinal($nNickStreak) . " is broken\! ", $kAlternate, $kAnnounceBack));
			}
			else
			{
				$sCoinFlip = 'unknown';
				$sCoinCall = 'unknown';
				$bFlippingCoin = 1;
				&CHANMSG(
					qwizcolor(" $sNickStreak, heads or tails, to keep your streak? ", $kAlternate, $kAnnounceBack));
			}
		}
	}
	else
	{
		# we have a winner, we may still get people to post and show

		$bListening	=	1;

		if (($bMirrorQwiz > 0) || ($nShotgun > 0) || ($bBlackOut > 0))
		{
			$bMirrorQwiz = 0;
			$nShotgun = 0;
			$bBlackOut = 0;
			putquiz();
		}
		my $a = qwizcolor(" The answer: ", $kAlternate, ($bChallenge? $kAlternateBack : $kQuestionBack));
		$a = $a . qwizcolor(" $CurrentQuestion[$sAnswer1] ", $kQuestion, ($bChallenge? $kAlternateBack : $kQuestionBack));
		&CHANMSG($a);
	}
}

sub housekeeping
{
	worm();

	#
	# paranoid about saving stats
	#

	$CurrentQuestion[$sCategories] = categorizequestion(@CurrentQuestion);
	setquestion(@CurrentQuestion);
	&writeplayers();

	#
	# flip the coin
	#
	if ($bFlippingCoin > 0)
	{
		$sCoinFlip = 'heads';
		if ((rand() * 100) < 50) { $sCoinFlip = 'tails'; }

		&CHANACTION("flips a coin, and peeks.");

		checkflip();
	}


	#
	# if we want another question, we should jump to the billboard state now
	#

	if (($nQuizThisPeriod < $quizperperiod) && ($fEndRound == 0))
	{
		# go for another question
		$bListening = 0;
		$nCurrentState = 0;
		$tWhenAdvance = 0;
		return;
	}
	if ($bChallenge > 0)
	{
		# check for a tie

		my %scores = ();
		my @player = ();
		foreach $nick (keys %challengers)
		{
			@player = getplayer($nick);
			$scores{$player[$sName]} = $player[$nTimesWonPeriod];
		}

		my @sorted = (sort { $scores{$b} <=> $scores{$a} } keys %scores);
		for $i (1 .. $#sorted)
		{
			if ($scores{$sorted[$i]} < $scores{$sorted[0]})
			{
				&NOTICE($challengers{lc($sorted[$i])}, "Thanks for taking the CHALLENGE!");
				delete $challengers{lc($sorted[$i])};
			}
		}

		if (($scores{$sorted[0]} == $scores{$sorted[1]}))
		{
			&CHANMSG(" CHALLENGE ROUND SUDDEN DEATH\! ", $kCongrats, $kCongratsBack);
			&CHANMSG(" These challengers are tied for the win: " . join(', ', (sort keys %challengers)) . " ", $kCongrats, $kCongratsBack);
			$bListening = 0;
			$nCurrentState = 0;
			$tWhenAdvance = 0;
			return;
		}
	}
}

sub postperiod
{
	#
	# tell the players that the period is over
	#

	$fEndRound = 0;
	$bListening = 0;

	if ($bChallenge)
	{
		&CHANMSG(qwizcolor(" - - End of the $sCurrentTheme CHALLENGE! - - ", $kCongrats, $kCongratsBack));
	}
	else
	{
		&CHANMSG(qwizcolor(" - - End of this $sCurrentTheme period! - - ", 9, $kPeriodicBack));
	}

	#
	# collect and report team and personal bests
	#

	my $count = 0;
	my %teamscores = ();
	foreach $nick (keys %players)
	{
		my @player = getplayer($nick);
		my $t = $player[$nTeam];
		if ($bTeams == 0)
			{ $t = 1; }
		if (!defined($teamscores{$t}))
			{ $teamscores{$t} = 0; }
		$teamscores{$t} += $player[$nTimesWonPeriod];
	}

	my @sorted = (sort { $teamscores{$b} <=> $teamscores{$a} } keys %teamscores);
	splice(@sorted, 3);
	foreach $b (@sorted)
	{
		if ($teamscores{$b} == 0)
			{ next; }
		if ($b == 1 && $bTeams == 0)
			{ next; }

		my $a = " Team $teamname[$b] had ";
		if ($b == 1)
		{
			if ($bTeams == 0) { $a = " Everyone had "; } else { $a = " Everyone else had "; }
		}
		$a = $a . " $teamscores{$b} total wins in the past round! ";
		$a = qwizcolor($a, $b);
		&CHANMSG($a);

		# WIPEOUT?
		if ($teamscores{$b} >= $quizperperiod)
		{
			foreach $nick (keys %active)
			{
				my @player = getplayer($nick);
				if ($player[$nTeam] != $b) { next; }
				$player[$nBonusPoints]++;
				setplayer(@player);
				&NOTICE($nick, "You get a TriviaBuck for your team's WIPEOUT round!");
			}
		}
	}

	leaderboard('', $nTimesWonPeriod, 3);

	&writequestions($questionfile);
	&writeoptions($optionsfile);

	if ($bChallenge > 0)
	{
		my @names = (keys %challengers);
		if ($#names == 0) # (if only one challenger remains standing)
		{
			my @player = getplayer($names[0]);
			$player[$nBonusPoints] += $nChallengePot;
			&CHANMSG(qwizcolor(" $player[$sNick] has won the CHALLENGE ROUND! ", $kCongrats, $kCongratsBack));
			setplayer(@player);
		}

		$bChallenge = 0;
		%challengers = ();
		%challengees = ();
	}

	if ($bRoundDie)
	{
		quitbot();
	}
}

sub periodbreather
{
	worm();

	#
	#
	#

	$bListening = 0;

	foreach $i (0 .. $#teamname)
	{
		if ($i == 1) { next; }
		if ($teamseas[$i] >= $nSeasonScore)
		{
			$fEndSeason = 1;
			&CHANMSG(qwizcolor(" Team $teamname[$i] has won the $nSeasonScore season! ", $kCongrats, $kCongratsBack));
		}
	}

	if ($fEndSeason > 0)
	{
		$fEndSeason = 0;

		my @player = ();
		foreach $nick (keys %players)
		{
			@player = getplayer($nick);

			$player[$nTimesWonSeason] = 0;
			$player[$nTimesAskedSeason] = 0;
			$player[$sSpeedBestWonSeason] = 99999;
			$player[$nBestStreakWonSeason] = 0;
			setplayer(@player);
		}
		&writeplayers();

		if (open(SEASON, ">$seasonfile"))
		{
			my %teamsort = ();
			foreach $i (0 .. $#teamname)
			{
				if ($i == 1) { next; }
				if ($teamopen[$i] == 0) { next; }
				$teamsort{$teamname[$i]} = $teamseas[$i];
			}
			foreach (sort { $teamsort{$b} <=> $teamsort{$a} } keys %teamsort)
			{
				print SEASON "Team $_ got $teamsort{$_} wins.\n";
			}
			close(SEASON);
		}

		@teamseas = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
		&writeoptions();

		&CHANMSG(qwizcolor("* A whole new season starts now!! *", $kCategory, $kCategoryBack));
		$nCurrentState = 0;
	}

	tallyvotes();
}

sub showplayerstatus
{
	my ($cmdnick) = @_;

	my %p = ();
	foreach $nick (keys %present) { $p{$nick} = 1; }
	foreach $nick (keys %active) { $p{$nick} = 2; }
	foreach $nick (keys %authed) { $p{$nick} = 3; }
	delete $p{lc($botnick)};

	my $pp = '';
	my @dl = ('*', '!', '?', ' ');
	my @pl = (13, 4, 8, 3);
	my @cl = (0, 0, 0, 0);
	foreach $nick (keys %p)
	{
		my @player = getplayer($nick);
		if ($player[$sFlags] =~ /d/) { next; }
		$cl[$p{$nick}]++;
		$pp .= qwizcolor(' ' . $dl[$p{$nick}] . $nick, $pl[$p{$nick}], 15);
	}

	my $a = '';
	if (($cl[2] > 0) || ($cl[1] > 0))
	{ $a = qwizcolor(" Player status: $pp ", 0, 15);
	  noticeplayersbyflag('o', '', $a) if ($cmdnick eq '');
	  &NOTICE($cmdnick, $a) if ($cmdnick ne '');
	}
	if ($cl[2] > 0)
	{ $a = qwizcolor(" $dl[2] Player is not auth'd. ", $pl[2], 15);
	  noticeplayersbyflag('o', '', $a) if ($cmdnick eq '');
	  &NOTICE($cmdnick, $a) if ($cmdnick ne '');
	}
	if ($cl[1] > 0)
	{ $a = qwizcolor(" $dl[1] Player may be stuck. ", $pl[1], 15);
	  noticeplayersbyflag('o', '', $a) if ($cmdnick eq '');
	  &NOTICE($cmdnick, $a) if ($cmdnick ne '');
	}
}

sub polling
{
	worm();

	#
	#
	#

	if ($bFirstRound > 0)
		{ return; }

	# showplayerstatus();

	$sPollKey = pickpoll();
	if ($sPollKey eq '')
	{
		teamsummary();
		return;
	}

	my $a = qwizcolor(" Quick Poll: ", $kAlternate, $kPollsterBack);
	my $ans = join(', ', (keys %hPollAnswers));
	$a .= qwizcolor(" $sPollQuestion $ans ", $kPollster, $kPollsterBack);
	&CHANMSG($a);
}

sub postpolling
{
	worm();

	#
	#
	#

	if ($sPollKey eq '')
	{
		$tWhenAdvance = 0;
		return;
	}

	if ($bFirstRound > 0)
		{ return; }

	my $l = qwizcolor(" Results: ", $kAlternate, $kPollsterBack);

	my $nTotal = 0;
	foreach $ans (keys %hPollAnswers) { $nTotal += $hPollAnswers{$ans}; }

	my $res = 'no votes';
	if ($nTotal > 0)
	{
		my @results = ();
		foreach $ans (sort { $hPollAnswers{$b} <=> $hPollAnswers{$a} } keys %hPollAnswers)
		{
			if ($hPollAnswers{$ans} == 0) { next; }
			my $percent = int(($hPollAnswers{$ans} * 100 / $nTotal) + 0.5);
			$results[++$#results] = "$ans ($hPollAnswers{$ans}=$percent\%)";
		}
		$res = join(', ', @results);
	}

	$l .= qwizcolor(" $res ", $kPollster, $kPollsterBack);
	&CHANMSG($l);

	setpoll($sPollKey);
	writepolls($pollfile);
}

1;
