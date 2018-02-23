#!/usr/local/bin/perl5
#=--------------------------------------=
#  Quizbot - prose.pm
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

@cardinalscore =
	qw(zero one two three four five six seven eight nine ten eleven twelve
	   thirteen fourteen fifteen sixteen seventeen eighteen nineteen);
@ordinalscore =
	qw(zeroth first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth
	   thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth);
@cardinaldecade =
	qw(zero ten twenty thirty forty fifty sixty seventy eighty ninety hundred);
@ordinaldecade =
	qw(zero tenth twentieth thirtieth fortieth fiftieth sixtieth seventieth eightieth ninetieth hundredth);
@cardinalgroup =
	qw(zero thousand million billion trillion);
@cardinalgroupvalue =
	(1,
	 1000,
	 1000000,
	 1000000000,
	 1000000000000);

sub cardinal
{
	local ($number) = @_;

	my $name = '';
	if ($number < 0)
	{
		$name .= "negative ";
		$number = -$number;
	}
	elsif ($number == 0)
	{
		return $cardinalscore[0];
	}

	my $comma = 0;
	foreach $group (reverse (1 .. $#cardinalgroup))
	{
		if ($number >= $cardinalgroupvalue[$group])
		{
			my $multigroup = int($number / $cardinalgroupvalue[$group]);
			$name .= cardinal($multigroup) . " " . $cardinalgroup[$group];
			$number %= $cardinalgroupvalue[$group];
			if ($number > 0)
				{ $name .= ", "; }
		}
	}

	if ($number >= 100)
	{
		$name .= cardinal(int($number / 100)) . " " . $cardinaldecade[10];
		$number %= 100;
		if ($number > 0)
			{ $name .= " "; }
	}

	if ($number >= 20)
	{
		$name .= $cardinaldecade[int($number / 10)];
		$number %= 10;
		if ($number > 0)
			{ $name .= "-"; }
	}

	if ($number > 0)
	{
		$name .= $cardinalscore[$number];
	}

	return $name;
}

sub ordinal
{
	local ($number) = @_;

	my $name = '';
	if ($number < 0)
	{
		$name .= "negative ";
		$number = -$number;
	}
	elsif ($number == 0)
	{
		return $ordinalscore[0];
	}

	if ($number >= 100)
	{
		$name = cardinal($number - ($number % 100));
		if (($number % 1000) > 0 && (($number % 1000) - ($number % 100)) == 0)
			{ $name .= ","; }
		$number %= 100;
		if ($number > 0)
			{ $name .= " "; }
	}

	if ($number == 0)
	{
		return $name . "th";
	}

	if ($number >= 20)
	{
		my $spare = $number % 10;

		if ($spare == 0)
			{ $name .= $ordinaldecade[int($number / 10)]; }
		else
			{ $name .= $cardinaldecade[int($number / 10)] . "-"; }
		
		$number = $spare;
	}

	if ($number > 0)
	{
		$name .= $ordinalscore[$number];
	}

	return $name;
}

sub testcardinalandordinal
{
	foreach $v
		(-5, 0, 5, 10, 15, 20, 25, 30,
		 100, 125, 200, 225, 999,
		 1000, 1001, 1010, 1011, 1035, 2000, 2345,
		 1000000, 1001001,
		 123000789, 123456789)
	{
		print "'" . cardinal($v) . "' == $v\n";
		print "'" . ordinal($v) . "' == $v th\n";
	}
}
# testcardinalandordinal();

#----------------------------------------------------------------------------

sub describetime
{
	local($t) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
		localtime($t);

	my $a = localtime($t);

	return $a;
}

sub describetimespan
{
	local($t) = @_;

	my $x = 0;
	my $d = 0;
	my $a = '';

	$d = (60*60*24*365);
	if ($t >= $d)
	{
		$x = int($t / $d);
		$a .= "$x year";
		if ($x > 1) { $a .= "s"; }
		$t %= $d;
	}

	$d = (60*60*24*7);
	if ($t >= $d)
	{
		$x = int($t / $d);
		if ($a ne '') { $a .= ", "; }
		$a .= "$x week";
		if ($x > 1) { $a .= "s"; }
		$t %= $d;
	}

	$d = (60*60*24);
	if ($t >= $d)
	{
		$x = int($t / $d);
		if ($a ne '') { $a .= ", "; }
		$a .= "$x day";
		if ($x > 1) { $a .= "s"; }
		$t %= $d;
	}

	$d = (60*60);
	if ($t >= $d)
	{
		$x = int($t / $d);
		if ($a ne '') { $a .= ", "; }
		$a .= "$x hour";
		if ($x > 1) { $a .= "s"; }
		$t %= $d;
	}

	$d = (60);
	if ($t >= $d)
	{
		$x = int($t / $d);
		if ($a ne '') { $a .= ", "; }
		$a .= "$x minute";
		if ($x > 1) { $a .= "s"; }
		$t %= $d;
	}

	if ($t >= 1)
	{
		$x = $t;
		if ($a ne '') { $a .= ", "; }
		$a .= "$x second";
		if ($x > 1) { $a .= "s"; }
	}

	return $a;
}

sub testtimeandtimespan
{
	foreach $v
		(0, 5, 10, 15, 20, 25, 30,
		 60, 125, 200, 225, 999,
		 1000, 1001, 1010, 1011, 1035, 3600, 3630,
		 1000000, 1001001,
		 123000789, 123456789)
	{
		print "'" . describetimespan($v) . "' == $v\n";
	}
}
# testtimeandtimespan();

#----------------------------------------------------------------------------

%defaultFuzzy =
	(0			=>	'no',
	 1			=>	'one',
	 2			=>	'a couple',
	 3			=>	'a few',
	 6			=>	'half a dozen',
	 12			=>	'a dozen',
	 20			=>	'a score of',
	 100		=>	'a hundred',
	 200		=>	'*hundreds of',
	 2000		=>	'*thousands of',
	 10000		=>	'ten thousand',
	 20000		=>	'*tens of thousands of',
	 20000		=>	'*countless'
	);
$defaultFuzzyCompensate =
	(0			=>	'more than',
	 1			=>	'well over',
	 2			=>	'nearly'
	);

sub __dfh { local($vn) = @_; $vn =~ s/^\*//g; $vn; }

sub describefuzzy
{
	local($number, %fuzzy, %compensate) = @_;
	#RUBIN - %fuzzy = %defaultFuzzy if !defined(%fuzzy);
	%fuzzy = %defaultFuzzy if !%fuzzy;
	#RUBIN %compensate = %defaultFuzzyCompensate if !defined(%compensate);
	%compensate = %defaultFuzzyCompensate if !%compensate;

	my @values = (sort {$a <=> $b} keys %fuzzy);
	my $above = $values[$#values];
	my $below = $values[0];

	for $value (@values)
	{
		if ($number > $value && $value > $fuzzy{$below})
		{
			$below = $value;
		}
		elsif ($number < $value && $value < $fuzzy{$above})
		{
			$above = $value;
		}
		elsif ($number == $value)
		{
			$above = $value;
			$below = $value;
			last;
		}
	}

	my $fabove = $fuzzy{$above};
	my $fbelow = $fuzzy{$below};
print "$fbelow - $fabove ";

	# exact value, or empty compensate map, gets the exact fuzzy name
	#
	my $bins = (sort keys %compensate);
	if ($above == $below || $bins == 0)
	{
		return __dfh($fabove);
	}

	# between two fuzzy names; figure out which compensator gets it
	#
	my $span = $values[$above] - $values[$below];
	my $bin = int($span / ($#bins+1));

	if (__dfh($fabove) eq $fabove)
	{
		# the above fuzzy name supports compensation
		# we want to find the compensator with the lowest negative value
		my $bestcomp = 0;
		foreach $comp (keys %compensate)
		{
			if ($comp < $bestcomp && ($comp + $#bins + 1) >= $bin)
				{ $bestcomp = $comp; }
		}

		if ($bestcomp < 0)
		{
			return "$compensate{$bestcomp} $fabove";
		}
	}

};
sub testfuzzy
{
	foreach $v
		(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)
	{
		print "'" . describefuzzy($v) . "' == $v\n";
	}
}
#testfuzzy();

#----------------------------------------------------------------------------

sub reverseprose
{
	local($prose) = @_;

	return join('', reverse(split(//, $prose)));

	my @words = split(/\b/, $prose);

	# reverses spelling of words, and puts words in reverse order
	# does not reverse punctuation and spacing ("test, but" -> "tub, tset")
	# to do: try to reverse word capitalization ("Smith" -> "Htims")
	# to do: try to reverse sentence capitalization, and restore sentence terminus

	foreach $i (0 .. $#words)
	{
		if ($words[$i] =~ /\w/)
		{
			my $drow = join('', reverse(split(//, $words[$i])));
			$words[$i] = $drow;
		}
	}

	my $tilpsesorp = join('', reverse(@words));

	return $tilpsesorp;
}
#print reverseprose("This isn't the only test, but is it a good test?") . "\n";

#----------------------------------------------------------------------------

1;
