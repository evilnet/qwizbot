#!/usr/local/bin/perl5
#=--------------------------------------=
#  Quizbot - qwizquestion.pm
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
#----------------------------------------------------------------------------

%themes					=	( );
%thememines				=	( );
%themecounts			=	( );
%themelocks				=	( );
%themefails				=	( );
	$sGeneralTheme		=	"Grab Bag o\' Doom";
	$sCurrentTheme		=	$sGeneralTheme;
	$sNextTheme			=	'';

#----------------------------------------------------------------------------

%questions				=	();
	$nQuestions			=	0;
	$nNewQuestions		=	0;
	$nFixQuestions		=	0;
	$nHitQuestions		=	0;
	$nAskedQuestions	=	0;

# a question consists of:
	$nIndex				=	0;
	$sCategories		=	1;
	$sQuestion			=	2;
	$sAnswer1			=	3;
	$sAnswer2			=	4;
	$nTimesHit			=	5;
	$nTimesAsked		=	6;
	$tWhenLastHit		=	7;
	$tWhenLastAsked		=	8;
	$sSpeedLastHit		=	9;
	$sSpeedBestHit		=	10;
	$sNickLastHit		=	11;
	$sNickSubmitted		=	12;
	$bFlaggedForEdit	=	13;
	$nQuestionInfo		=	13;##

#----------------------------------------------------------------------------

sub isquestion
{
	local($index) = @_;
	if (defined($questions{$index}))
		{ return 1; }
	0;
}

sub getquestion
{
	local($index) = @_;
	$index = int($index);
	split(/\º/, $questions{$index});
}

sub setquestion
{
	local(@question) = @_;
	my $index = $question[$nIndex];

	if ($index eq '' || $index eq '-')
	{
		return -1;
	}

	#
	# new unique index number
	#
	if ($index eq '*')
	{
		$index = $nQuestions;
		while (defined($questions{$index}))
			{ $index++; }
		$question[$nIndex] = $index;
		$nNewQuestions++;

		my @player = getplayer($question[$sNickSubmitted]);
		$player[$nSubmissions]++;
		setplayer(@player);
	}

	if (!defined($questions{$index}))
	{
		$nQuestions++;
		if (($nQuestions % 1000) == 0)
		{
			print "...$nQuestions added\n";
		}

		if ($question[$nTimesAsked] > 0)
			{ $nAskedQuestions++; }
		if ($question[$nTimesHit] > 0)
			{ $nHitQuestions++; }
	}
	else
	{
		#print "Replacing question: " . $questions{$index} . "\n";
		#print "              with: " . join('º', @question) . "\n";
	}

	$questions{$index} = join('º', @question);

	return $index;
}

#----------------------------------------------------------------------------

sub categorizequestion
{
	local(@question) = @_;

	#
	# categorize the question with keywords
	# two scans:  first general categories, then specialized categories
	# a themelock of ! indicates specialized category
	#
	my %categories = ();
	foreach $bLock (0, 1)
	{
		foreach $theme (keys %themes)
		{
			if (($bLock && ($themelocks{$theme} !~ /\!/)) ||
			    ((!$bLock) && ($themelocks{$theme} =~ /\!/)))
			{
				next;
			}

			my $criteria = $themes{$theme};
			if ($criteria eq '') { next; }
			if (($question[$sQuestion] =~ /$criteria/) ||
			    ($question[$sAnswer1] =~ /$criteria/) ||
				($question[$sAnswer2] =~ /$criteria/))
			{
				if ($bLock)
				{
					%categories = ();
					$categories{$theme} = 1;
					last;
				}

				$categories{$theme} = 1;

				my $criteria = $themefails{$theme};
				if ($criteria eq '' || $criteria eq '.') { next; }
				if (($question[$sQuestion] =~ /$criteria/) ||
					($question[$sAnswer1] =~ /$criteria/) ||
					($question[$sAnswer2] =~ /$criteria/))
				{
					delete $categories{$theme};
				}

			}
		}
	}

	my $catline = join('+', (keys %categories));

	return $catline;
}

sub autoeditquestion
{
	local(@question) = @_;

	$question[$sAnswer1] =~ s/^(movies|movie) (by|of|with|for|starring|about|on|in) (.+)$/$3 movies/;
	$question[$sAnswer1] =~ s/^(songs|song) (by|of|with|for|starring|about|on|in|sung by) (.+)$/$3 songs/;
	$question[$sAnswer1] =~ s/^(books|book) (by|of|with|for|starring|about|on|in) (.+)$/$3 books/;

	if ($question[$sAnswer2] eq '' || $question[$sAnswer2] eq $question[$sAnswer1])
	{
		$question[$sAnswer2] = $question[$sAnswer1];

		$question[$sAnswer2] =~ s/^a (.+)/$1/i;				# "a thing" -> "thing"
		$question[$sAnswer2] =~ s/^an (.+)/$1/i;			# "an example" -> "example"
		$question[$sAnswer2] =~ s/^the (.+)/$1/i;			# "the title" -> "title"
		$question[$sAnswer2] =~ s/^famous (.+)$/$1/i;			# "famous people" -> "people"
		$question[$sAnswer2] =~ s/^types of (.+)$/$1/i;			# "types of things" -> "things"
		$question[$sAnswer2] =~ s/^(.+) and (.+)$/$2 and $1/i;		# "red and blue" -> "blue and red"
		$question[$sAnswer2] =~ s/^(.+) shows$/$1/i;			# "kate jackson shows" -> "kate jackson"
		$question[$sAnswer2] =~ s/^(.+) songs$/$1/i;			# "goofy songs" -> "goofy"
		$question[$sAnswer2] =~ s/^(.+) actors$/$1/i;			# "honeymooners actors" -> "honeymooners"
		$question[$sAnswer2] =~ s/^(.+) albums$/$1/i;			# "al jolsen albums" -> "al jolsen"
		$question[$sAnswer2] =~ s/^(.+) movies$/$1/i;			# "woody allen movies" -> "woody allen"
		$question[$sAnswer2] =~ s/^(.+) characters$/$1/i;		# "little rascals characters" -> "little rascals"
	}

	return @question;
}

#----------------------------------------------------------------------------

sub addquestion
{
	local($nick,$tabbedline) = @_;

	$tabbedline =~ s/\|/\º/g;
	$tabbedline =~ s/\t/\º/g;

	my $b = 0;
	if ($tabbedline =~ /\º/) { $b = 1; }

	my @tabbed = split(/ *\º */, $tabbedline, 3);

	($tabbed[0]) = ($tabbed[0] =~ /^\s*(.*?)\s*$/); $tabbed[0] = ucfirst($tabbed[0]);
	($tabbed[1]) = ($tabbed[1] =~ /^\s*(.*?)\s*$/); $tabbed[1] = ucfirst($tabbed[1]);
	($tabbed[2]) = ($tabbed[2] =~ /^\s*(.*?)\s*$/); $tabbed[2] = ucfirst($tabbed[2]);

	if ($b == 0 || $tabbed[0] eq '' || $tabbed[1] eq '' || $tabbed[0] eq $tabbed[1])
	{
		if ($nick ne '')
		{
			&PRIVMSG($nick, "Question did not appear in the right form.");
			&PRIVMSG($nick, "I need: " . qwizcolor("Question\?\|Answer", 2, 11) . " to add your question.");
		}
		return;
	}
	if ($nick ne '')
	{
		my $warn = 0;
		if ($tabbed[0] =~ /\b(for|in|of|from|at|with|under|on|through)[?.!]/)
		{
			&PRIVMSG($nick, "Grammar warning: " . qwizcolor(" Question appears to end in a preposition. ", 2, 11));
			$warn = 1;
		}

		if ($warn > 0) { &PRIVMSG($nick, "You may want to reword and resubmit the question."); }
	}

	#
	# convert to qwiz format
	#
	my @question = ('*', "", "", "", "", 0, 0, 0, 0, 99999, 99999, "(nobody)", "(nobody)", "0");
	if ($nick ne '' && isplayer($nick))
	{
		$question[$sNickSubmitted] = $nick;
	}

	#
	# copy the question itself
	#
	$question[$sQuestion] = $tabbed[0];
	$question[$sAnswer1] = $tabbed[1];
	$question[$sAnswer2] = $tabbed[2];

	@question = autoeditquestion(@question);

	$question[$sCategories] = categorizequestion(@question);
	@question;
}

sub showquestion
{
	local($nick,@question) = @_;

	if ($nick ne '')
	{
		&PRIVMSG($nick, "Question $question[$nIndex]: " . qwizcolor($question[$sQuestion], 6));
		my $a = "Answers: " . qwizcolor($question[$sAnswer1], 6);
		if ($question[$sAnswer2] ne $question[$sAnswer1])
			{ $a .= " or " . qwizcolor($question[$sAnswer2], 6); }
		&PRIVMSG($nick, $a);
		&PRIVMSG($nick, "Categories: " . qwizcolor($question[$sCategories]));

		if ($question[$nTimesAsked] == 0)
		{
			# &PRIVMSG($nick, "Stats: Never asked.");
		}
		else
		{
			&PRIVMSG($nick, "Stats: asked $question[$nTimesAsked], hit $question[$nTimesHit]");
		}

		my @player = getplayer($nick);
		if ($player[$sFlags] =~ /[ap]/)
		{
			$a = "Flags: $question[$bFlaggedForEdit] Submitted by $question[$sNickSubmitted]";
			&PRIVMSG($nick, irccolor($a, 3));
		}
	}
}

sub writequestions
{
	local($filename) = @_;

	if (!open(INFO, ">$filename.new"))
	{
		print "Cannot write new $filename.\n";
		return 0;
	}

	my $now = localtime();
	print INFO "# saved $now\n";

	my $wrote = 0;
	my $buried = 0;
	foreach $index (sort { $a <=> $b } keys %questions)
	{
		if (!defined($questions{$index}) || $questions{$index} eq '') { next; }
		if ($questions{$index} =~ /BURY/) { $buried++; next; }
		print INFO $questions{$index} . "\n";
		$wrote++;
	}

	close(INFO);

	unlink("$filename.bak");
	rename("$filename", "$filename.bak");
	rename("$filename.new", "$filename");

	$wrote;
}

sub readquestions
{
	local($filename, $bCategorize, $honor) = @_;

	if (!open(INFO, $filename))
	{
		print "Cannot read $filename.\n";
		return 0;
	}
	my @questionlist = <INFO>;
	close(INFO);

	my $errors = 0;
	my $newq = 0;
	foreach $questionline (@questionlist)
	{
		$questionline =~ s/\n//;
		$questionline =~ s/\r//;
		if ($questionline eq '') { next; }
		if ($questionline =~ /^\s*#/) { next; }

		my @question = ();
                # TODO replace this funky char with \x186 decimal or \x272 octal?
		@question = split(/\º/, $questionline);
		if (defined($question[$nQuestionInfo-1]))
		{
			if ($question[$nTimesAsked] < $question[$nTimesHit])
				{ $question[$nTimesAsked] = $question[$nTimesHit]; }
			if ($bCategorize) # || ($question[$sCategories] eq ''))
			{
				@question = autoeditquestion(@question);
				$question[$sCategories] = categorizequestion(@question);
			}
		}
		else
		{
			@question = addquestion($honor, $questionline);
			if (!defined($question[$nQuestionInfo]))
			{
				$errors++;
				next;
			}
		}
		if ($question[$bFlaggedForEdit] eq '')
		{
			$question[$bFlaggedForEdit] = '0';
		}
		if ($bCategorize == 2)
		{
			$question[$bFlaggedForEdit] = 'REVIEW';
		}

		setquestion(@question);
		$newq++;
	}

	if ($errors > 0)
	{
		&DEBUGMSG("$errors errors reading questions in $filename");
	}
        if($newq < 1) {
            &DEBUGMSG("No questions loaded. Make sure question file is correct");
            die
        }

	$newq;
}

#----------------------------------------------------------------------------

sub getcategoryname
{
	local($name) = @_;

	foreach $t (keys %themes)
	{
		if (lc($name) eq lc($t)) { return $t; }
	}

	return '';
};

sub iscategory
{
	local($name) = @_;
	$name = getcategoryname($name);

	if ($name eq '') { return 0; }
	return 1;
};

sub getcategoryexpression
{
	local($name) = @_;
	$name = getcategoryname($name);

	return $theme{$name};
};

sub writecategories
{
	local($filename) = @_;

	if (!open(INFO, ">$filename"))
	{
		print "Cannot write new $filename.\n";
		return 0;
	}

	my $wrote = 0;
	foreach $name (sort keys %themes)
	{
		my $mine = $thememines{$name};
		$mine = '.' if !defined($mine);
		print INFO "$themelocks{$name}$name\t$mine\t$themes{$name}\t$themefails{$name}\n";
		$wrote++;
	}

	close(INFO);

	return $wrote;
};

sub readcategories
{
	local($filename) = @_;

	my $newthemes = 0;

	if (!open(INFO, $filename))
	{
		print "Cannot read $filename.\n";
		return 0;
	}
	my @themelist = <INFO>;
	close(INFO);

	foreach $themeline (@themelist)
	{
		$themeline =~ s/\n//;
		$themeline =~ s/\r//;
		if ($themeline eq '') { next; }
		if ($themeline =~ /^\s*#/) { next; }

		my @theme = split(/\t/, $themeline);
		if ($theme[0] eq '') { next; }
		if ($theme[2] eq '') { next; }

		my ($locks,$name) = ($theme[0] =~ /^\s*([^a-zA-Z]*)\s*(\S+.*)$/);

		if ($locks eq '')
			{ delete $themelocks{$name}; }
		else
			{ $themelocks{$name} = $locks; }

		if ($theme[1] eq '.')
			{ delete $thememines{$name}; }
		else
			{ $thememines{$name} = $theme[1]; }

		$themes{$name} = $theme[2];
		$themefails{$name} = $theme[3];

		if ($themelocks{$name})
		{
			DEBUGMSG("Theme $name has lock $themelocks{$name}.");
		}

		$newthemes++;
	}

	return $newthemes;
};

#----------------------------------------------------------------------------

sub countcategoryquestions
{
	local($cat) = @_;

	if (defined($themes{$cat}) && $themecounts{$cat} == 0)
	{
		my $count = 0;
		foreach $index (keys %questions)
		{
			my @question = getquestion($index);
			if (($cat eq $sGeneralTheme) ||
				($question[$sCategories] =~ /$cat/))
			{
				$count++;
			}
		}
		$themecounts{$cat} = $count;
	}

	return $themecounts{$cat};
}

sub pickcategory
{
	local($except, $atleast, $exceptlocks) = @_;

	my $count = 0;
	my $locks;
	my @themenames = (keys %themes);
	my $sLastTheme = $sCurrentTheme;
	my $sPickedTheme;
	do
	{
		if (int(rand() * 100) < 45)
		{
			$sPickedTheme = $sGeneralTheme;
			$count = $nQuestions;
                        last; #play general regardless of excepts and locks and counts..
		}
		else
		{
			$sPickedTheme = $themenames[int(rand() * ($#themenames + 1))];
			$count = countcategoryquestions($sPickedTheme);
		}

		$locks = $themelocks{$sPickedTheme};
                &DEBUGMSG("Contimplating theme $sPickedTheme with $count questions");

	} while ($sPickedTheme eq $except || ($count < $atleast) || ($exceptlocks ne '' && $locks =~ /\Q$exceptlocks\E/));

	return $sPickedTheme;
}

#----------------------------------------------------------------------------

1;
