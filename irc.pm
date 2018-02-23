#!/usr/local/bin/perl5

#=--------------------------------------=
#  Quizbot - irc.pm
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

# CTCP Customizable Responses

	$ctcpfingerinfo = "$botnick (\@) idle 1 seconds";
	$ctcpuserinfo = "$botnick (\@) idle 1 seconds";
	$ctcpclientinfo = 'ACTION CLIENTINFO DCC FINGER PING TIME SOUND USERINFO VERSION';

# Colors and other messages that are configurable
	$__ctcp = chr(1);
	$__bold = chr(2);
	$__kolor = chr(3);
	$__ubar = chr(30);
	$version = '0.9';
	$kickmsg = 'because';
	$quitmsg = 'because';

#----------------------------------------------------------------------------

# Data

	$nonblocking = 0;
	$selecting = 0;
	$tLastOther = 0;
	%pings = ();
	%present = ();
	%mentions = ();

#----------------------------------------------------------------------------

sub ircreadline
{
	local($handle, $block) = @_;
	my $line = '';

	if ($block) {
		$line = <$handle>;
	}
	else {
		$line = nonblocking_read($handle);
	}
        #chomp $line;

        if(!defined($line)) {
           # print "DEBUG: line is undef\n";
            return undef;
        }
        elsif($line eq EOF) {
           # print "DEBUG: line is EOF\n";
            return EOF;
        }
        else {
           # print "DEBUG: returning :$line\n";
            &DEBUGMSG("DEBUG: <-- $line");
            return $line;
        }
}

sub ircsendline
{
    local($handle, $line) = @_;

    # delay for non-flood out
    if(!defined($send_timer{$handle})) {
        $send_timer{$handle} = time();
        #print "DEBUG: initalizing send_timer to ". $send_timer{$handle}. ".\n";
    }
    if($send_timer{$handle} > time() + 10) {
        #print "DEBUG: send timer is ". $send_timer{$handle} - time() . " seconds ahead. sleeping 2 to avoid flood.\n";
        sleep(2);
    }
    if($send_timer{$handle} < time()) {
        $send_timer{$handle} = time();
    }

    # Send the line to the socket:
    print $handle "$line\n";

    #incriment delay counter by 2.
    $send_timer{$handle} += 2;
    &DEBUGMSG("DEBUG: --> $line");
}


$nonblocking_buf = '';
sub nonblocking_read
{
	local($handle) = @_;

        my $old_flags = fcntl($handle, F_GETFL, 0) or die "can't get flags: $!";
        fcntl($handle, F_SETFL, $old_flags | O_NONBLOCK) or die "can't set non blocking: $!";
	#select($handle); $| = 1;

	my $rin = "";
	vec($rin, fileno($handle), 1) = 1;
	#print STDOUT "rin = '" . unpack("b*", $rin) . "'\n";

	($nfound, $timeleft) = select($rin, undef, undef, 1.0);
	#print STDOUT "nfound = $nfound\n";

        # Read whatever is there:
        my $bytes = 999999;
	while ($bytes > 0) {
		my $localbuf = "";
		$bytes = sysread($handle, $localbuf, 1000);
		if ($bytes > 0) {
			$nonblocking_buf .= $localbuf;
                        if($localbuf =~ /\n/) {
                            last; # quit at end of line
                        }
		}
                elsif((!defined($bytes)) && $! == EAGAIN) {
                    #print STDOUT "DEBUG: sysread would block.\n";
                }
                else{
                    print STDOUT "DEBUG: sysread error: $!\n";
                    return EOF;
                }
	}
        # here we have $nonblocking_buf with 'xxxxx\nyyyyy'
        if($nonblocking_buf =~ /^([^\n]*\n)(.*)\Z/s) {
            $line = $1;
            $nonblocking_buf = $2;
        }else{
            return undef;
        }

	#print STDOUT "nonblocking_buf = '$nonblocking_buf'\n";

	#$nonblocking_buf =~ /\A([^\n]*\n)(.*)\Z/s;
	#if ($1 ne '')
        #    { $nonblocking_buf = $2; }

	#select(STDOUT);
        # return to blocking mode
        fcntl($handle, F_SETFL, $old_flags) or die "can't restore fctl: $!";
        #
        # send line back to be processed
	return $line;
}

#----------------------------------------------------------------------------

sub QUIT
{
	local($reason) = @_;
	$reason = $quitmsg if !defined($reason);
	ircsendline(S, "QUIT :$reason");
}

sub OPER #($args)
{
	if ($bDebug == 0) { return; }
	local($args) = @_;
	ircsendline(S, "OPER $message");
}

sub DEBUGMSG #($message)
{
	if ($bDebug == 0) { return; }
	local($message, $inchan) = @_;
        if($inchan == 1) {
            # This is kinda a bad idea, so not used anywhere currently..
	    ircsendline(S, "PRIVMSG $botchan :${__kolor}14\[$message\]");
        }
        if($bDebug > 0) {
	   print "***DEBUG: $message\n";
        }
}

sub CHANMSG #($message)
{
	local($message) = @_;
	ircsendline(S, "PRIVMSG $botchan :$message");
}

sub CHANACTION #($message)
{
	local($message) = @_;
	ircsendline(S, "PRIVMSG $botchan :${__ctcp}ACTION $message${__ctcp}");
}

sub PRIVMSG #($nick,$message)
{
	local($nick,$message) = @_;
	ircsendline(S, "PRIVMSG $nick :$message");
}

sub CTCPREPLY #($nick,$message)
{
	local($nick,$message) = @_;
	ircsendline(S, "NOTICE $nick :$__ctcp$message$__ctcp");
}

sub CTCPQUERY #($nick,$message)
{
	local($nick,$message) = @_;
	ircsendline(S, "PRIVMSG $nick :$__ctcp$message$__ctcp");
}

sub PING #($nick)
{
	local($nick) = @_;
	my $now = time() if !defined($now);
	$pings{$nick} = $now;
	&CTCPQUERY($nick, "PING $now");
}

sub NOTICE #($nick,$message)
{
	local($nick,$message) = @_;
	print "/notice $nick $message\n" if $bDebug;
	ircsendline(S, "NOTICE $nick :$message");
}

sub WHOIS #($nick)
{
	local($nick) = @_;
	print "/whois $nick\n" if $bDebug;
	ircsendline(S, "WHOIS $nick");
}

sub USERHOST #($nick)
{
	local($nick) = @_;
	print "/userhost $nick\n" if $bDebug;
	ircsendline(S,  "USERHOST $nick");
}

sub REQUEST_OPS
{
#	&PRIVMSG("SaSp1998", "op");
}

sub TOPIC
{
	local($topic) = @_;
	ircsendline(S, "TOPIC $botchan :$topic");
}

sub CHANMODES
{
	local($modes) = @_;
	ircsendline(S, "MODE $botchan $modes");
}

sub OPS
{
	local($nick) = @_;
	print "/mode +o $botchan $nick\n" if $bDebug;
	ircsendline(S, "MODE $botchan +o $nick");
}

sub DEOPS
{
	local($nick) = @_;
	print "/mode -o $botchan $nick\n" if $bDebug;
	ircsendline(S, "MODE $botchan -o $nick");
}

sub VOICE
{
	local($nick) = @_;
	print "/mode +v $botchan $nick\n" if $bDebug;
	ircsendline(S, "MODE $botchan +v $nick");
}

sub DEVOICE
{
	local($nick) = @_;
	print "/mode -v $botchan $nick\n" if $bDebug;
	ircsendline(S, "MODE $botchan -v $nick");
}

sub KICK
{
	local($nick, $reason) = @_;
	ircsendline(S, "KICK $botchan $nick :$reason");
}

sub BAN
{
	local($nick, $mask, $reason) = @_;
	ircsendline(S, "MODE $botchan +b *\!$mask");
	ircsendline(S, "KICK $botchan $nick :$reason");
}

sub UNBAN
{
	local($mask) = @_;
	ircsendline(S, "MODE $botchan -b $mask");
}

#----------------------------------------------------------------------------

sub ircispresent
{
	if (defined($present{lc($_[0])})) { return 1; }
	return 0;
}

sub ircmention
{
	local($nick,$host) = @_;
	my $now = time();
	my $who = lc($nick . "\!" . $host);

	if (defined($present{lc($nick)}))
	{
		$present{lc($nick)} = $host;
	}

	if (!defined($present{lc($nick)}) && !defined($mentions{$who}))
	{
		$mentions{$who} = time();
	}
}

#----------------------------------------------------------------------------

# return pong for keepalive
sub r_pong
{
	local($fromhost) = @_[0];
	ircsendline(S, "PONG $fromhost");
	#TODO figure out why it does this and do it another way
        ##     ircsendline(S,ircsendline(S, "WHO **\n";
}

sub r_ctcpquery
{
	local($nick,$host,$type) = @_;

	ircmention($nick, $host);

	if ($type eq 'VERSION')
		{ &CTCPREPLY($nick, "VERSION quiz"); }
	elsif ($type eq 'FINGER')
		{ &CTCPREPLY($nick, "FINGER $ctcpfingerinfo"); }
	elsif ($type eq 'USERINFO')
		{ &CTCPREPLY($nick, "USERINFO $ctcpuserinfo"); }
	elsif ($type eq 'CLIENTINFO')
		{ &CTCPREPLY($nick, "CLIENTINFO $ctcpclientinfo"); }
	elsif ($type =~ /SOUND/)
		{ &PRIVMSG($botnick, ""); }
	elsif ($type =~ /ACTION/)
		{ &PRIVMSG($botnick, ""); }
	elsif ($type =~ /DCC/)
		{ &PRIVMSG($nick, "DCC is not supported by $botnick"); }
	elsif ($type eq TIME)
		{ &PRIVMSG($nick, "TIME is not supported by $botnick"); }
	elsif ($type =~ /PING/)
		{ &CTCPREPLY($nick, "$type"); }
	else
	{
		&PRIVMSG($nick, "unknown CTCP command");
	}
}

sub r_ctcpreply
{
	local($nick,$host,$type) = @_;

	ircmention($nick, $host);

	if ($type =~ /PING/)
	{
		my $d = (time() - $pings{$nick});
		delete $pings{$nick};

		my $a = '';
		SWITCH:
		{
			($d <= 1)   && do { $a = irccolor("[",5) . irccolor("*",3) . "-------" . irccolor("]",5); last; };
			($d <= 2)   && do { $a = irccolor("[",5) . irccolor("**",3) . "------" . irccolor("]",5); last; };
			($d <= 4)   && do { $a = irccolor("[",5) . irccolor("***",3) . "-----" . irccolor("]",5); last; };
			($d <= 6)   && do { $a = irccolor("[",5) . irccolor("***",3) . irccolor("*",8) . "----" . irccolor("]",5); last; };
			($d <= 8)   && do { $a = irccolor("[",5) . irccolor("***",3) . irccolor("**",8) . "---" . irccolor("]",5); last; };
			($d <= 10)  && do { $a = irccolor("[",5) . irccolor("***",3) . irccolor("***",8) . "--" . irccolor("]",5); last; };
			($d <= 20)  && do { $a = irccolor("[",5) . irccolor("***",3) . irccolor("***",8) . irccolor("*",4) . "-" . irccolor("]",5); last; };
			($d <= 30)  && do { $a = irccolor("[",5) . irccolor("***",3) . irccolor("***",8) . irccolor("**",4) . irccolor("]",5); last; };
			do { $a = irccolor("[",5) . irccolor("***",3) . irccolor("***",8) . irccolor("**",4) . irccolor("]",5) . irccolor("*",4); last; };
		};

		my $s = 's';
		$s = '' if ($d == 1);
		&NOTICE($nick, "[$botnick PING $a $d second$s.]");
	}
	else
	{
		;
	}
}

#----------------------------------------------------------------------------

sub ircmaskfromhost
{
	local($host) = @_;

	my $mask = $host;
	if ($mask =~ /^?(\S+)\@(\d+)\.(\d+)\.(\d+)\.(\d+)$/)
		{ $mask = "*$1\@$2.$3.$4.*"; }
	elsif ($mask =~ /^?(\S+)\@(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)$/)
		{ $mask = "*$1\@*.$3.$4.$5.$6.$7.$8.$9"; }
	elsif ($mask =~ /^?(\S+)\@(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)$/)
		{ $mask = "*$1\@*.$3.$4.$5.$6.$7.$8"; }
	elsif ($mask =~ /^?(\S+)\@(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)$/)
		{ $mask = "*$1\@*.$3.$4.$5.$6.$7"; }
	elsif ($mask =~ /^?(\S+)\@(\S+)\.(\S+)\.(\S+)\.(\S+)\.(\S+)$/)
		{ $mask = "*$1\@*.$3.$4.$5.$6"; }
	elsif ($mask =~ /^?(\S+)\@(\S+)\.(\S+)\.(\S+)\.(\S+)$/)
		{ $mask = "*$1\@*.$3.$4.$5"; }
	elsif ($mask =~ /^?(\S+)\@(\S+)\.(\S+)\.(\S+)$/)
		{ $mask = "*$1\@*.$3.$4"; }
	elsif ($mask =~ /^?(\S+)\@(\S+)\.(\S+)$/)
		{ $mask = "*$1\@*.$3"; }

	return $mask;
}

sub irchostinmask
{
	local($host, $mask) = @_;

	# turn irc-style mask to a regular expression
	#   *foo@*.blah.net   -->   [^.]*foo@[^.]*\.blah\.net
	#
	$mask =~ s/([^a-zA-Z0-9*.])/\\$1/g;
	$mask =~ s/\./\\./g;
	$mask =~ s/\*/\[^\.\]\*/g;

	if ($host =~ /^$mask$/i)
		{ return 1; }
	0;
}

#----------------------------------------------------------------------------

sub irccolor #($string,$fg,$bg)
{
	local($string, $fg, $bg) = @_;
	$fg = 1 if !defined($fg);

	# IRC color codes are [^K]digits or [^K]digits,digits
	# If $string starts with digits, we insert two [^B] bold toggles.
	# This should have no visual impact on most IRC clients.

	my $bgs = '';
	$bgs = ",$bg" if defined($bg);

	if (substr($string,0,1) =~ /[0-9]/)
		{ return $__kolor . "$fg$bgs" . $__bold . $__bold . $string . $__kolor; }

	return $__kolor . "$fg$bgs" . $string . $__kolor;
}

#----------------------------------------------------------------------------

1;
