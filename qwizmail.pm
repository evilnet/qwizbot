#!/usr/local/bin/perl5
#=--------------------------------------=
#  Quizbot - qwizmail.pm
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

@gmails = ();

#----------------------------------------------------------------------------

sub readmail
{
	local($filename) = @_;

	if (!open(INFO, $filename))
	{
		print "Cannot read $filename.\n";
		return 0;
	}
	my @gmaillist = <INFO>;
	close(INFO);

	my $newg = 0;
	foreach $gmailline (@gmaillist)
	{
		$gmailline =~ s/\n//;
		$gmailline =~ s/\r//;
		if ($gmailline eq '') { next; }
		if ($gmailline =~ /^\s*#/) { next; }

		my($to,$from,$when,$message) = split(/\º/, $gmailline);

		$gmails[++$#gmail] = $gmailline;
		$newg++;
	}

	return $newg;
}

sub writemail
{
	local($filename) = @_;

	if (!open(INFO, ">$filename"))
	{
		print "Cannot write $filename.\n";
		return 0;
	}

	my $wrote = 0;
	my $now = time();
	foreach $gmail (@gmails)
	{
		my($to,$from,$when,$message) = split(/\º/, $gmail);
		if (!isplayer($to)) { next; }
		if (($when + (60*60*24*14)) < $now) { next; }

		print INFO $gmail . "\n";
		$wrote++;
	}

	close(INFO);
	return $wrote;
}

#----------------------------------------------------------------------------

sub isgmailwaiting
{
	local($nick) = @_;

	foreach $gmail (@gmails)
	{
		my($to,$from,$when,$message) = split(/\º/, $gmail);
		if (lc($to) eq lc($nick))
			{ return 1; }
	}

	return 0;
}

sub delivergmail
{
	local($nick,$limit) = @_;
	$limit = 5 if !defined($limit);

	my $now = time();
	my $read = 0;

	foreach $imail (0 .. $#gmails)
	{
		my $gmail = $gmails[$imail];
		my($to,$from,$when,$message) = split(/\º/, $gmail);
		if (lc($to) eq lc($nick))
		{
			my $ago = describetimespan($now - $when);
			my $age = "${__kolor}3";
			if (($now - $when) >= (60*60)) { $age = "${__kolor}7"; }
			if (($now - $when) >= (60*60*24)) { $age = "${__kolor}4"; }
			$age .= $__bold . $__bold;
			&NOTICE($to, "from ${__kolor}3$from$__kolor/$age$ago ago$__kolor/$message");

			$read++;
			splice(@gmails, $imail, 1);

			$limit--;
			if ($limit <= 0)
			{
				&NOTICE($to, "(more messages; wait a few moments and !gmail again to read more)");
				last;
			}

			if ($#gmails >= $imail) { redo; }
		}
	}
}

sub postgmail
{
	local($to,$from,$message) = @_;

	my $when = time();
	if ($to eq '*')
	{
		$message = '4Mass Gmail: '.$message;
		foreach $nick (keys %players)
		{
			postgmail($nick,$from,$message);
		}
	}
	if ($to eq '@')
	{
		$message = '4Mass Op Message: '.$message;
		foreach $nick (keys %players)
		{
			my @player = getplayer($nick);
			if ($player[$sFlags] !~ /o/) { next; }
			postgmail($nick,$from,$message);
		}
	}
	elsif (isplayer($to))
	{
		$gmails[++$#gmail] = join("\º", $to, $from, $when, $message);
		if (ircispresent($to))
		{
			&NOTICE($to, "New gmail from $from. Use !gmail to read your waiting gmail.");
		}
	}
}

#----------------------------------------------------------------------------

1;
