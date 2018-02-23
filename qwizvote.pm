#!/usr/local/bin/perl5
#=--------------------------------------=
#  Quizbot - qwizvote.pm
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

%polls = ();
	$tWhenPollFirstAsked	= 0;
	$tWhenPollLastAsked		= 0;
	$sPollQuestion			= 0;
	%hPollAnswers			= ();
	%hPollPeople			= ();
	$tWhenLastPollAsked		= 0;

$nSamePollSpan = (60*60*8);
$nAnyPollSpan = (60*60);

#----------------------------------------------------------------------------

sub readpolls
{
	local($filename) = @_;

	if (!open(INFO, $filename))
	{
		print "Cannot read $filename.\n";
		return 0;
	}
	my @polllist = <INFO>;
	close(INFO);

	my $newp = 0;
	foreach $pollline (@polllist)
	{
		$pollline =~ s/\n//;
		$pollline =~ s/\r//;
		if ($pollline eq '') { next; }
		if ($pollline =~ /^\s*#/) { next; }

		my($key,$whenfirstasked,$whenlastasked,$question,$answers,$answered) = split(/\º/, $pollline);

		$polls{$key} = $pollline;
		$newp++;
	}

	return $newp;
}

sub writepolls
{
	local($filename) = @_;

	if (!open(INFO, ">$filename"))
	{
		print "Cannot write $filename.\n";
		return 0;
	}

	my $wrote = 0;
	my $now = time();
	foreach $key (keys %polls)
	{
		my $pollline = $polls{$key};
		print INFO $pollline . "\n";
		$wrote++;
	}

	close(INFO);
	return $wrote;
}

#----------------------------------------------------------------------------

sub checkpoll
{
	local($nick, $said) = @_;

	foreach $ans (keys %hPollAnswers)
	{
		if (lc($said) eq lc($ans))
		{
			if (defined($hPollPeople{lc($nick)}))
			{
				&NOTICE($nick, "You've already submitted an answer to this poll. Thanks!");
				return;
			}

			$hPollAnswers{$ans}++;
			$hPollPeople{lc($nick)}++;
			&NOTICE($nick, "Your vote of $ans has been accepted. Thanks!");

			return;
		}
	}

	return;
}

sub pickpoll
{
	my $now = time();

	if ($tWhenLastPollAsked + $nAnyPollSpan > $now) { return ''; }

	my $tries = 0;
	do
	{
		$tries++;

		# pick a key
		my @ks = (keys %polls);
		my $key = $ks[int(rand()*($#ks+1))];

		# open the poll
		my $pollline = $polls{$key};
		if (!defined($pollline)) { next; }
		my($dummy,$whenfirstasked,$whenlastasked,$question,$answers,$answered) = split(/\º/, $pollline);

		# if it's been asked too recently, don't pick it
		if ($whenlastasked + $nSamePollSpan > $now) { next; }

		# long check, if 

		# it's picked! prepare it
		my @t = ();

		$sPollQuestion = $question;
		$tWhenPollFirstAsked = $whenfirstasked;
		$tWhenPollFirstAsked = $now if ($tWhenPollFirstAsked == 0);
		$tWhenPollLastAsked = $now;

		# answers packed "answer1=5,answer2=6,answer3=0"
		@t = split(/,/, $answers);
		%hPollAnswers = ();
		foreach $a (@t)
		{
			my ($ans,$ct) = split(/=/, $a);
			$hPollAnswers{$ans} = int($ct);
		}

		# answered people packed "nick1,nick2,nick3"
		@t = split(/,/, $answered);
		%hPollPeople = ();
		if ($answered ne '(nobody)') { foreach $nick (@t) { $hPollPeople{lc($nick)}++; } }

		$tWhenLastPollAsked = $now;
		return $key;

	} while ($tries < 5);

	return '';
}

sub resetpoll
{
	%hPollPeople = ();
	foreach $ans (keys %hPollAnswers)
	{
		$hPollAnswers{$ans} = 0;
	}

	return;
}

sub setpoll
{
	local($key) = @_;

	my @t = ();
	foreach $ans (keys %hPollAnswers) { $t[++$#t] = "$ans=$hPollAnswers{$ans}"; }
	my $answers = join(',', @t);

	my $answered = join(',', (keys %hPollPeople));
	$answered = '(nobody' if ($answered eq '');

	my $pollline = join("\º",
		($key,
			$tWhenPollFirstAsked,$tWhenPollLastAsked,$sPollQuestion,
			$answers,$answered
		));

	$polls{$key} = $pollline;
}

#----------------------------------------------------------------------------

1;
