#!/usr/bin/perl

#=--------------------------------------=
#  Quizbot - QuizBot.pl
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

# Configuration Section; Change the following
# variables to suit you.

# This is the bots default nickname, and how it refers to itself online.
# Change it to what you want your bots nick to be.
$botname = 'Trubia';

# actually the irc username sent to the server (ident
# depends on your identd install). set to $botname by
# default.
$ident = $botname;

# This is the bots 'real name' shown in /whois on IRC.
$realname = 'Trivia Bot';

# These are the usermodes the bot sets on itself.
# +i-d is a good default.
$botusermode = '+i-d';

# This password is used for nickserv/authserv login
# currently this is under construction.
#$sPassword  = 'xyzpasswordpdq';

# This is the channel the bot will join and play trivia in
$botchan = '#afternet';

# The modes the bot will set in the channel.
# (TODO currently does not work, need to check when
#      we get ops to do this)
$botchanmode = '+nt';

# The bot will respond to commands in channel that begin with this character
$cmdchar = '!';

# The bot will occationally tell people to visit here
# for information about your channel.
$homeurl = 'http://afternet.org/';

# The bot will kickban anyone who says anything matching the following
# regex:
$sCurses = '\b(bitch|cunt)';

# End of the configuration section. Edit code below
# only if you are making code modifications.

#----------------------------------------------------------------------------

$botnick = $botname;
$oldbotnick = '';
$botwantnick = $botnick;

if ($ARGV[0] eq 'test') { 
        $botchan .= $botchan.'-test'; 
        &DEBUGMSG("Test BOT using $botchan."); 
}

$serverfile = lc($botname . '.servers.txt');
$playerfile = lc($botname . '.players.txt');
$suggestionfile = lc($botname . '.suggestions.txt');

$nBackupSpan = (60*60*24*1);

# Thes arnt used anymore, see botname.servers.txt
$ircserver = '';
$ircport = '';
@servers = (
        'irc.afternet.org:6667',
        );

#----------------------------------------------------------------------------

require irc;
require prose;

require qwizgame;
require qwizplayer;
require qwizmail;
require qwizvote;

use POSIX;

#----------------------------------------------------------------------------

# channel police:

        $bDebug = 1;
        $bDebug = 1 if ($botchan =~ /test/i);

        $bKickComics = 1;
        $bKickGuests = 1;
        $bKickCurses = 1;

        $nTimeIdleWarning = (60*10);
        $nTimeIdleKick = (60*25);

        $joinsseen = 0;
        $userjoins = 0;
        $bankicks = 0;
        $kicksseen = 0;

        $tWhenLastReported      =       0;
        $nAntiFloodReport       =       10;

        $tCurseProbation = (60*60);

#----------------------------------------------------------------------------

# channel status;

        $bQuit                  =       0;
        $sForceTopic            =       '';
        $bX2                    =       0;
        $bNickServ              =       0;
        $bChanServ              =       1;
        $bIRCop                 =       0;
        $bServerOverride        =       0;
        $bNickChange    =       1;

        @modequeue              =       ();

#----------------------------------------------------------------------------
        %send_timer = ();
        $connected = 0;


sub initializebot()
{
        &DEBUGMSG("Initializing bot.");

        &DEBUGMSG(readservers($serverfile) . " servers on file");

        initializegame();

        &DEBUGMSG(readplayers() . " players on file");
        %send_timer = ();
}

sub savebot
{
        savegame();
        &writeplayers();
}

$irc_housekeeping = 0;
sub initbot
{
    ircsendline(S, "MODE $botnick $botusermode");
    ircsendline(S, "JOIN $botchan");

    $irc_housekeeping = time();
    
    # uh. cant do this unless we have ops, so
    # lets do it WHEN we get ops maybe?
    #ircsendline(S, "MODE $botchan $botchanmode");

    # these are things we might want to do after connecting..
    #if ($bIRCop) { &OPER("$botnick $sPassword"); }
    #if ($bX2) { &PRIVMSG('authserv', "$botchan LOGIN $botnick $sPassword"); }
    #if ($bX2) { &PRIVMSG('x3', "up #core"); }
    #if ($bNickServ) { &PRIVMSG('nickserv', "IDENTIFY $sPassword"); }
    #if ($bNickServ) { &PRIVMSG('x3', "IDENTIFY $botchan $sPassword"); }
    #if ($bChanServ) { &PRIVMSG('authserv', "auth $botnick $sPassword"); }
}


sub refreshbot
{
        if($irc_housekeeping + 30 < time()) {
            &DEBUGMSG("DEBUG: Running refreshbot housekeeping");
            if($botnick ne $botwantnick) {
                #$botnick = $botwantnick;
                ircsendline(S, "NICK $botwantnick");
            }
            $irc_housekeeping = time();
        }
}

sub quitbot
{
        foreach $nick (keys %active)
        {
                &deactivateplayer($nick);
        }
        &QUIT();
        $bQuit = 1;
}

#sub checknick
#{
#       if ($botnick = $botname)
#       {
#               $bNickChange = 1;
#       }
#       else {$bNickChange = 0;}
#}

sub terminatebot
{
        savebot();
        &DEBUGMSG("Terminated bot.");
}

#----------------------------------------------------------------------------

sub readservers
{
        local($filename) = @_;
        if (!open(INFO, $filename))
        {
                &DEBUGMSG("Cannot read $filename.");
                return 0;
        }

        @servers = ();
        my $count = 0;

        while (!eof(INFO))
        {
                $serversline = <INFO>;
                $serversline =~ s/\n//;
                $serversline =~ s/\r//;

                if ($serversline =~ /^\s*\#/)
                        { next; }

                push(@servers, $serversline);
                $count++;
        } 

        close(INFO);
        $count;
}

#----------------------------------------------------------------------------

#
# main loop
#

sub main
{
        if ($bDebug != 0)
        {
                &DEBUGMSG("(----DEBUGGING DIAGNOSTICS ENABLED----)");
        }

        initializebot();

        $retrytime = 0;
        SERVERLOOP: while (!$bQuit)
        {
                savebot();

                $retrytime += 1;

                # pick $ircserver from a list, retry another server if fails to connect
                # this can be overridden with a /msg bot /server command,
                # but the bot still falls back to the list if that server fails
                #
                if (($retrytime % 3) == 0)
                {
                        my ($head) = splice(@servers, 0, 1);
                        push(@servers, $head);
                        $bServerOverride = 0;
                        $retrytime = 0;
                }
                if ($bServerOverride == 0)
                {
                        ($ircserver, $ircport) = split(/:/, $servers[0]);
                        $bServerOverride = 0;
                }

                my $l = localtime();
                &DEBUGMSG("Trying $ircserver... ($l)");

                %active = ();
                %authed = ();
                %present = ();

                # bind socket, connect.
                {
                        $sockaddr = 'S n a4 x8';
                        ($name, $aliases, $proto) = getprotobyname('tcp');
                        ($name, $aliases, $port) = getservbyname('6667', 'tcp');
                        ($name, $aliases, $type, $len, $thataddr) = gethostbyname($ircserver);
                        $this = pack($sockaddr, 2, 0, $thisaddr);
                        $that = pack($sockaddr, 2, $ircport, $thataddr);
                        socket(S, 2, 1, $proto) || do { &DEBUGMSG("$! at socket() - retrying"); sleep(20); next SERVERLOOP; };
                        bind(S, $this) || do { &DEBUGMSG("$! at bind() - retrying"); sleep(20); next SERVERLOOP; };
                        &DEBUGMSG("Connecting to $ircserver...");
                        connect(S, $that) || do { &DEBUGMSG("$! at connect() - retrying"); sleep(20); next SERVERLOOP; };
                        &DEBUGMSG("Connected.");
                        $f = fileno(S);
                        # turn on output autoflushing:
                        select(S); $| = 1; select(STDOUT);
                        $connected = 1;
                }

                $conntime = time();

                # establish IRC session
                {
                        $botnick = $botwantnick;
                        ircsendline(S, "NICK $botnick");
                    # login on connect stuff.
                        ircsendline(S, "PASS /".$botnick."/".$sPassword);
                        ircsendline(S, "USER $ident zero zero :$realname");

                        while ($connected)
                        {
                                $_ = ircreadline(S, 1);
                                if(!defined($_) ) {
                                    #TODO read timed out - check if we should give up
                                    next;
                                }
                                if($_ eq EOF)
                                {
                                    &DEBUGMSG("Error from socket, terminating reg loop");
                                    $connected = 0;
                                    last;
                                }
                                elsif ($_ eq '') { 
                                    # empty line, ignore
                                    next; 
                                }
                                elsif (/^PING (\S+)/i) { 
                                    &r_pong($1); next; 
                                }
                                elsif (/:(\S+)\s+001\s+/) { # :Welcome to network.
                                        if (lc($1) ne lc($ircserver)) {
                                                &DEBUGMSG("Server name shift: $ircserver -> $1");
                                                $ircserver = $1;
                                        }
                                }

                                #:SVC-EU.AfterNET.Services 433 * triviabot :Nickname is already in use.
                                elsif (/:(\S+)\s+433\s+\S+\s+(\S+)/) {# :Nickname is already in use.
                                        $botnick = $2 . "_";
                                        ircsendline(S, "NICK $botnick");

                                        #if ($botnick ne $botwantnick)
                                        #{
                                        #        my @r = ('A', 'B', 'C', 'D', 'E', 'F');
                                        #        my $t = $r[int(rand()*($#r+1))];
                                        #        $botnick = $botwantnick . $t;
                                        #        ircsendline(S,"NICK $botnick");
                                        #}
                                        #else
                                        #{
                                        #    $botnick .= '_';
                                        #    ircsendline(S, "NICK $botnick");
                                        #}
                                }
                                elsif (/:(\S+)\s+376\s+/) { 
                                    last; 
                                } # :End of MOTD
                        }
                        if($connected) {
                           &DEBUGMSG("Connected to $ircserver.");
                        }
                }
                if(!$connected) {
                    last;
                }

                $retrytime = 0;

                # get back into the channel
                {
                        initbot();
                        #&CHANACTION("is connecting from $ircserver:$ircport.");
                        # need to sleep while x3 gives us permission
                        #sleep 4;
                }

                $chantime = time();

                &nextstate();

                # server loop
                #{
                        while (1)
                        {
                                $_ = ircreadline(S, 0);
                                if(!defined($_)) {
                                    next;
                                }
                                elsif($_ eq EOF) {
                                    &DEBUGMSG("DEBUG: Error from socket, exiting loop.");
                                    $connected = 0;
                                    last;
                                }
                                elsif ($_ eq '') { 
                                    next; 
                                }
                                elsif ($_ =~ /\000/) { 
                                    &DEBUGMSG("-------------null on line\!"); 
                                    next; 
                                }

                                elsif (/^PING (\S+)/i) {
                                    &r_pong($1);
                                    next;
                                }

                                elsif (/^:(\S+)\!(\S+) PRIVMSG (\#\S+) :$cmdchar(.+)/i) { 
                                    &r_command($1,$2,$4,1); next; 
                                }
                                elsif (/^:(\S+)\!(\S+) PRIVMSG $botnick :[$cmdchar]?(.+)/i) { 
                                    &r_command($1,$2,$3,0); next; 
                                }

                                elsif (/^:(\S+)\!(\S+) PRIVMSG (\#\S+) :(.+)/i) { 
                                    &r_say($1,$2,$4); next; 
                                }

                                elsif (/^:(\S+)\!(\S+) PRIVMSG $botnick :$__ctcp(.+)$__ctcp/i) { 
                                    &r_ctcpquery($1,$2,$3); next; 
                                }
                                elsif (/^:(\S+)\!(\S+) PRIVMSG (\#\S+) :$__ctcp(.+)$__ctcp/i) { 
                                    &r_ctcpquery($1,$2,$4); next; 
                                }
                                elsif (/^:(\S+)\!(\S+) NOTICE $botnick :$__ctcp(.+)$__ctcp/i) { 
                                    &r_ctcpreply($1,$2,$3); next; 
                                }

                                elsif (/^:(\S+)\!(\S+) JOIN :(\S+)/i) { 
                                    &r_join($1,$2); next; 
                                }
                                elsif (/^:(\S+) 353 [^:]*:(.+)$/i) {# 353 RPL_NAMREPLY
                                    &r_names($2); next; 
                                }
                                elsif (/^:(\S+) 302 (\S+) :(.+?)\=(\+|\-)?(\S+)$/i) {# 302 RPL_USERHOST
                                    &r_join($3,$5); next; 
                                }
                                elsif (/^:(\S+) (\S+) (\S+) :(\S+)\=(\+|\-)(\S+)/i) { 
                                    &r_join($4,$6); next; 
                                }

                                elsif (/^:(\S+)\!(\S+) NICK :(\S+)/i) { 
                                    if (lc($1) ne lc($3)) { 
                                        #If Its me. upbate my botnick
                                        if(lc($1) eq lc($botnick)) {
                                            $botnick = $3;
                                        }
                                        else {
                                            # shouldn't we just follow them??
                                            &r_part($1); 
                                            &DEVOICE($3); 
                                            &r_join($3,$2); 
                                        }
                                    } 
                                    next; 
                                }
                                elsif (/^:(\S+)\!(\S+) PART (\S+)/i) { 
                                    &r_part($1); next; 
                                }
                                elsif (/^:(\S+)\!(\S+) KICK (\S+) (\S+)/i) { 
                                    &r_part($4); next; 
                                }
                                elsif (/^:(\S+)\!(\S+) QUIT/i) { 
                                    &r_part($1); next; 
                                }

                                elsif (/:(\S+) 433 (\S+) (\S+)/) {# :Nickname is already in use.
                                        # Nick change failed. Were back where we were.
                                        $botnick = $2;

                                        #if ($botnick ne $botwantnick)
                                        #{
                                        #        my @r = ('A', 'B', 'C', 'D', 'E', 'F');
                                        #        my $t = $r[int(rand()*($#r+1))];
                                        #        $botnick = $botwantnick . $t;
                                        #        ircsendline(S, "NICK $botnick");
                                        #}
                                        next;
                                }

                                elsif (/^:\S+ TOPIC/i) { 
                                    next; 
                                }
                                elsif (/^:\S+ MODE/i) { 
                                    next; 
                                }
                                elsif (/^:\S+ 482/) {# 482 ERR_CHANOPRIVSNEEDED
                                    next; 
                                }

                                # Server notices (user notices caught above)
                                if (/^:\S+ NOTICE/i) { 
                                    next; 
                                }
                                &DEBUGMSG("Line didn't match a rule, ignoring");
                        }
                        continue
                        {
                                #
                                # check the queue of bans to free
                                #

                                my $now = time();

                                # do basic housekeeping such as
                                # fixing wanted channels and nicks
                                refreshbot();

                                while (defined($bans[0]))
                                {
                                        my @ban = split(/:/, $bans[0]);
                                        if ($ban[0] > $now) { last; }

                                        &DEBUGMSG("unbanning ($ban[1])");
                                        &UNBAN($ban[1]);
                                        splice(@bans, 0, 1);
                                }

                                #
                                # run the game
                                #

                                pumpgame();
                        }
                #}
                if(!$connected) { 
                    last;
                }
        }

        terminatebot();
}

#----------------------------------------------------------------------------

sub isauthed
{
        local($nick) = @_;
        $nick = lc($nick);
        if (defined($authed{$nick}))
                { return 1; }
        my @player = getplayer($nick);
        if ($player[$sAuthPassword] eq '')
                { return 1; }
        return 0;
}

sub isreportokay
{
        my $now = time();

        if ($tWhenLastReported + $nAntiFloodReport > $now) { return 0; }

        $tWhenLastReported = $now;
        return 1;
}

sub qwizkick
{
        local($nick, $by, $reason) = @_;

        &KICK($nick, $reason);
        &DEBUGMSG("** Kicked $nick out, $by ($reason)");

        $player[$nTimesKicked]++;
        setplayer(@player);
        deactivateplayer($player[$sNick]);
}

sub qwizban
{
        local($nick, $host, $by, $reason, $duration) = @_;

        $duration = 5*60*60 if (!defined($duration));

        &DEBUGMSG("** Ban+Kicked $nick!$host out, $by ($reason)");

        my $found = 0;
        my $added = 0;
        my $expires = $duration + time();
        foreach $b (0 .. $#bans)
        {
                my @ban = split(/:/, $bans[$b]);
                if ($ban[1] =~ /\Q$host\E/)
                {
                        &DEBUGMSG("** $host already in ban queue");
                        $found = 1;
                        last;
                }
                if ($ban[0] >= $duration)
                {
                        splice(@bans, $b, 0, "$expires:*\!$host");
                        $added = 1;
                        last;
                }
        }
        if (!$found)
                { &BAN($nick, $host, "$reason (" . describetimespan($duration) . " ban)"); }
        if (!$added)
                { push(@bans, "$expires:*\!$host"); }

        deactivateplayer($nick);
}

sub idlecheck
{
        foreach $nick (keys %active)
        {
                my @player = getplayer($nick);
                if ($player[$sFlags] =~ /[dio]/) { next; }

                my $a = (time() - $player[$tWhenMet]);
                my $t = (time() - $player[$tWhenLastSaid]);
                my $klimit = $nTimeIdleKick;
                my $wlimit = $nTimeIdleWarning;
                if ($a < ($klimit * 2) || ($player[$sFlags] !~ /f/))
                {
                        $klimit = $klimit / 3;
                        $wlimit = $wlimit / 3;
                }

                # decreasing order of warning: kick, second warning, first warning
                # (ensures you don't get lagged out and all three happen at once)
                #
                if ($t >= $klimit)
                {
                        &DEBUGMSG("banning ($nick, $present{lc($nick)}, $botnick, \"Play, or chat, or leave, but don\'t idle in $botchan; thanks.\", 15)");
                        &qwizban($nick, $present{lc($nick)}, $botnick, "Play, or chat, or leave, but don't idle in $botchan; thanks.", 15);
                }
                elsif ($t >= (($wlimit+$klimit)/2) && ($warned{lc($nick)} < 2))
                {
                        &DEBUGMSG("warning ($nick, \"$botchan does not allow idling; please participate in the channel, or leave it.\")");
                        $warned{lc($nick)} = 2;
                        &NOTICE($nick, "$botchan does not allow idling; please participate in the channel, or leave it.");
                        # noticeplayersbyflag('o', '', "Player $nick was just given their first idle warning.");
                }
                elsif ($t >= $wlimit && !defined($warned{lc($nick)}))
                {
                        &DEBUGMSG("warning ($nick, \"$botnick and your fellow players would like you to contribute in $botchan.\")");
                        $warned{lc($nick)} = 1;
                        &NOTICE($nick, "$botnick and your fellow players would like you to contribute in $botchan.");
                        noticeplayersbyflag('o', '', "Player $nick was just given their second idle warning.");
                }
        }
}

#----------------------------------------------------------------------------

sub r_join
{
        local($nick, $host) = @_;

        if ($nick eq '' || $host eq '')
        {
                return;
        }

        $joinsseen = $joinsseen + 1;
        $lastjoin = $nick;

        $present{lc($nick)} = $host;

        &activateplayer($nick, $host);

        if (isactive($nick))
        {
                my @player = getplayer($nick);
                $player[$tWhenLastSaid] = time();
                setplayer(@player);

                if (isgmailwaiting($nick))
                {
                        &NOTICE($nick, "You have game mail waiting.  Use !gmail to read it.");
                }
        }
}

sub r_names
{
        local($nicklist) = @_;

        my @nicks = split(/\s/, $nicklist);
        my @users = ();
        foreach $i (0 .. $#nicks)
        {
                my $nick = $nicks[$i];
                if($nick =~ /^[+@]*([][A-Za-z0-9|^{}`_-]+)$/) {
                    my $user = $1;
                    if(lc($user) eq lc($botnick)) {
                        next; # ignore ourselves
                    }
                    #my ($user) = ($nick =~ /^[@+-]?(\S+)/);
                    #if ($user eq '') { 
                    #    next; 
                    #}
                    &DEBUGMSG("Found user $nick = $user in names reply");
                    push (@users, $user);
                }
                else {
                    &DEBUGMSG("'$nick' didn't match names parser");
                }
        }

        while ($#users >= 0)
        {
                my $a = shift(@users);
                my @player = getplayer($a);
                r_join($a, 'unknownhost');
                if ($player[$sFlags] =~ /[ox]/)
                {
#                       &USERHOST($a);
                }
        }
}

sub r_part
{
        local($nick) = @_;

        &deactivateplayer($nick);

        delete $present{lc($nick)};
        delete $active{lc($nick)};
        delete $authed{lc($nick)};

        if ($bX2 && lc($nick) eq 'X2')
        {
                foreach $p (keys %authed)
                {
                        my @player = getplayer($p);
                        if ($player[$sFlags] =~ /o/) { &OPS($p); }
                }
        }
}

sub r_say
{
        local($cmdnick,$cmdhost,$said) = @_;

        if ($said eq '+') { return; }

        ircmention($cmdnick,$cmdhost);

        if ($cmdchan eq $botnick)
                { $cmdchan = $cmdnick; }

        $said =~ s/\n//;
        $said =~ s/\r//;

        if (!isactive($cmdnick))
        {
                &DEBUGMSG("in r_say() activating $cmdnick ($cmdhost)"); 
                activateplayer($cmdnick, $cmdhost);
                if (!isactive($cmdnick)) { 
                    &DEBUGMSG("$cmdnick still not active though!!"); 
                    return; 
                }
        }

        my @player = getplayer($cmdnick);

        if ($player[$sFlags] =~ /[*d]/)
                { return; }

        #
        # recognize game answers
        #

        my $now = time();

        if ($bKickComics)
        {
                if (($said =~ /^\# Appears as /) || ($said =~ /^\(#/))
                {
                        &PRIVMSG($cmdnick,
                                "Comic Chat will not work with $botnick. Switch to Text Mode, and come back to $botchan. " .
                                "To use Text Mode, look under the View menu for Plain Text.  Or, click the button on your toolbar labeled Text View.");
                        &PRIVMSG($cmdnick,
                                "The operators of $botchan suggest using mIRC instead of MSCHAT.  See www.mirc.com for that shareware product.");
                        &KICK($cmdnick, " Come back in Text Mode. (See your private message to learn how.) ");
                        return;
                }
        }

        if ($bKickGuests)
        {
                if ($cmdnick =~ /^Guest\d+/i)
                {
                        &PRIVMSG($cmdnick,
                                "Guest nicknames will not work with $botnick. Choose a unique nickname, and come back to $botchan. " .
                                "To set a nickname, try typing /nick newname, or see your IRC program's online help about nicks.");
                        &KICK($cmdnick, " Come back with a personal nickname. (See your private message to learn how.) ");
                        return;
                }
        }

        if ($bKickCurses)
        {
                #if (($player[$tWhenMet] + $tCurseProbation) > $now)
                #{
                        if (($said =~ /$sCurses/i) ||
                            ($cmdnick =~ /$sCurses/i) ||
                                ($cmdhost =~ /$sCurses/i))
                        {
                                qwizban($cmdnick, $cmdhost, $botnick, "No profanity in #quiztime please.", 60);
                                deactivateplayer($cmdnick);
                                return;
                        }
                #}
        }

        gamesaid($cmdnick, $said, @player);

        #
        # all game processing of what they said is done; we can mangle $said now
        #

        @player = getplayer($cmdnick); # again!

        $said =~ s/\://g;
        $said =~ s/\t//g;
        $said =~ s/\º//g;
        $said =~ s/\|//g;
        $said =~ s/[^\x20-\x7F]/\-/g;
        my $t = ($now - $player[$tWhenLastSaid]);
        if ($said eq $player[$sLastSaid] && $t < 10)
        {
                $player[$nTimesSaid]++;
        }
        else
        {
                $player[$nTimesSaid] = 1;
        }
        $player[$sLastSaid] = $said;
        $player[$tWhenLastSaid] = time();
        setplayer(@player);

        if ($player[$sFlags] =~ /[fo]/)
                { return; }

        if ($player[$nTimesSaid] > 2)
        {
                &NOTICE($player[$sNick], "You talk too much, and you're not being very entertaining.");
        }
        if ($player[$nTimesSaid] > 3)
        {
                qwizkick($cmdnick, $botnick, "I warned you, dumbass.");
                deactivateplayer($player[$sNick]);
        }
        if ($player[$nTimesSaid] > 4)
        {
                qwizban($player[$sNick], $player[$sMask], $botnick, "Stop spamming now.");
                deactivateplayer($player[$sNick]);
        }
}

sub r_command
{
        local($cmdnick,$cmdhost,$rcommand,$ispublic) = @_;

        ircmention($cmdnick,$cmdhost);

        if ($cmdchan eq $botnick)
                { $cmdchan = $cmdnick; }

        $rcommand =~ s/\n//;
        $rcommand =~ s/\r//;

        @commandfields = split (/ /, $rcommand);
        $thecommand = lc($commandfields[0]);
        
        &DEBUGMSG("thecommand: $thecommand");
        &DEBUGMSG("$cmdnick  isactive:" . isactive($cmdnick) ." present: " . ircispresent($cmdnick));
        #if (!isactive($cmdnick) && ircispresent($cmdnick) && $thecommand ne 'mask' && $thecommand ne 'help')
        if (!isactive($cmdnick) && $thecommand ne 'mask' && $thecommand ne 'help')

        {
             &DEBUGMSG("Activating PLAYER in activate!");
                activateplayer($cmdnick, $cmdhost);
                if (!isactive($cmdnick)) { 
                    &DEBUGMSG("Tried to activiate $cmdnick ($cmdhost) but it still isnt, so cant do command $thecommand");
                    return; 
                }
        }

        my @player = getplayer($cmdnick);

        my $isop = (($player[$sFlags] =~ /[ox]/)? 1 : 0);

        #
        # non-ops can't whisper commands
        #
        if ($isop == 0 && $ispublic == 0 && $thecommand !~ /^(add|gmail|auth|setpass)$/) { 
            &DEBUGMSG("Non-op $cmdnick tried to do $thecommand, but they can't (because they arnt an op).");
            return; 
        }

        #
        # until the bot is stable, no commands from non-ops
        #
        my $now = time();
        if ($chantime + (60) > $now && $isop == 0) { 
            &DEBUGMSG("Channel not yet stable... now = $now chantime = $chantime : commands not allowed"); 
            return; 
        }

        #
        # blacklisted folks and bots have NO commands
        #
        if ($player[$sFlags] =~ /[*d]/)
                { return; }

        #
        # auth command -------------------------------------------------------------
        #
        if ($thecommand eq 'auth')
        {
                &DEBUGMSG("In the authbit!!!");
                #if (!ircispresent($cmdnick))
                #       { return; }
                if ($ispublic != 0 || $commandfields[1] eq '')
                {
                        &NOTICE($cmdnick, "To enter your password for authorization, you need to /msg $botnick auth <yourpassword>");
                        &NOTICE($cmdnick, "Do NOT type your password in the channel where others may see it. See !help auth");
                        return;
                }

                my $pw = $commandfields[1];
                $pw =~ tr/a-zA-Z0-9_\\\`\|\^\[\]\{\}\-//cd;

                if ($pw ne $player[$sAuthPassword])
                {
                        &NOTICE($cmdnick, "That is not the correct password.  Authorization failed.");
                        &DEBUGMSG("!! nick $cmdnick failed AUTH!");
                        $authfails{lc($cmdnick)}++;
                        if ($authfails{lc($cmdnick)} >= 3)
                        {
                                qwizban($cmdnick, $cmdhost, $botnick, "Authorization failed.", 15);
                                return;
                        }
                        &NOTICE($cmdnick, "Do NOT type your password in the channel where others may see it. See !help auth");
                        return;
                }

                &NOTICE($cmdnick, "Authorization successful.");
                &DEBUGMSG("!! $cmdnick AUTHed successfully!");

                delete $authfails{lc($cmdnick)};
                $authed{lc($cmdnick)} = $cmdhost;

                authplayer($cmdnick);

                return;
        }
        if ($thecommand eq 'setpass')
        {
                #if (!ircispresent($cmdnick))
                #       { return; }
                if ($ispublic != 0 || $commandfields[1] eq '')
                {
                        &NOTICE($cmdnick, "To set your password, you need to /msg $botnick setpass <yourpassword>");
                        &NOTICE($cmdnick, "Do NOT type your password in the channel where others may see it. See !help auth");
                        return;
                }

                if (!isauthed($cmdnick))
                {
                        &NOTICE($cmdnick, "You are not authorized to set your password.  You must first enter your old password.");
                        &NOTICE($cmdnick, "Do NOT type your password in the channel where others may see it. See !help auth");
                        return;
                }

                my $pw = $commandfields[1];
                $pw =~ tr/a-zA-Z0-9_\\\`\|\^\[\]\{\}\-//cd;

                if (length($pw) < 3 || lc($pw) eq lc($cmdnick))
                {
                        &NOTICE($cmdnick, "That password is not secure enough. Use more letters or digits, or pick another word.");
                        &NOTICE($cmdnick, "Do NOT type your password in the channel where others may see it. See !help auth");
                        return;
                }

                &NOTICE($cmdnick, "Your password has been updated to <$pw>.");
                &NOTICE($cmdnick, "Do NOT type your password in the channel where others may see it. See !help auth");
                &DEBUGMSG("!! $cmdnick SETPASSed successfully!");

                $player[$sAuthPassword] = $pw;
                setplayer(@player);
                $authed{lc($cmdnick)} = $cmdhost;

                authplayer($cmdnick);

                return;
        }
        if ($thecommand eq 'zappass' && isplayer($commandfields[1]) && $player[$sFlags] =~ /x/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                my $nick = $commandfields[1];
                @player = getplayer($nick);
                delete $authed{lc($nick)};
                $player[$sAuthPassword] = $newplayer[$sAuthPassword];
                setplayer(@player);

                &NOTICE($cmdnick, "$nick has had their password zapped.");

                return;
        }

        #
        # asl command -------------------------------------------------------------
        #
        if (($thecommand eq 'asl') || ($thecommand eq 'a/s/l'))
        {
                if ($commandfields[2] eq '' && isplayer($commandfields[1]))
                {
                        @target = getplayer($commandfields[1]);
                        if ($target[$sPersonalStats] eq $newplayer[$sPersonalStats])
                                { &NOTICE($cmdnick, "$target[$sNick] has not recorded age/sex/location."); }
                        else
                                { &NOTICE($cmdnick, "$target[$sNick] has $target[$sPersonalStats] saved."); }
                        return;
                }

                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                my ($age,$sex,$loc) = ($rcommand =~ /asl\s+(\S*)\s*[\/\|\\]+\s*(\S*)\s*[\/\|\\]+\s*(.*)\s*$/i );
                if (!defined($loc))
                {
                        &NOTICE($cmdnick, "Please see !help website for details on how to use !asl.");
                        return;
                }

                if (($age < 7 || $age > 77) && ($age ne '-'))
                {
                        &NOTICE($cmdnick, "$botnick suspects your age ($age) is not accurate.");
                        &NOTICE($cmdnick, "Please see !help website for details on how to use !asl.");
                        &NOTICE($cmdnick, "See an operator if you think this message is in error.");
                        return;
                }

                if ($sex =~ /female|f|she|g|w/i) { $sex = 'F'; }
                if ($sex =~ /male|m|he|b/i) { $sex = 'M'; }
                if ($sex ne 'F' && $sex ne 'M' && $sex ne '-')
                {
                        &NOTICE($cmdnick, "$botnick suspects your sexual gender ($sex) is not accurate.");
                        &NOTICE($cmdnick, "Please see !help website for details on how to use !asl.");
                        &NOTICE($cmdnick, "See an operator if you think this message is in error.");
                        return;
                }
                $sex = lc($sex);

                if ($loc ne '-' && $loc !~ /^[a-zA-Z,'. ]+$/)
                {
                        &NOTICE($cmdnick, "$botnick suspects your location ($loc) is not accurate.");
                        &NOTICE($cmdnick, "Please see !help website for details on how to use !asl.");
                        &NOTICE($cmdnick, "See an operator if you think this message is in error.");
                        return;
                }

                if ($age eq '-' && $sex eq '-' && $loc eq '-')
                {
                        $player[$sPersonalStats] = $newplayer[$sPersonalStats];
                        setplayer(@player);
                        &NOTICE($cmdnick, "Your personal stats have been cleared.");
                        return;
                }

                $player[$sPersonalStats] = "($age/$sex/$loc)";
                $player[$sNick] = $cmdnick;
                setplayer(@player);
                &NOTICE($cmdnick, "Your personal stats are saved as $player[$sPersonalStats].");
                return;
        }
        if ($thecommand eq 'url')
        {
                if (isplayer($commandfields[1]))
                {
                        @target = getplayer($commandfields[1]);
                        if ($target[$sPersonalURL] eq $newplayer[$sPersonalURL])
                        {
                                &NOTICE($cmdnick, "$target[$sNick] has not recorded a network address.");
                        }
                        else
                        {
                                my ($first,$sep,$last) = ($target[$sPersonalURL] =~ m{^([a-z0-9_.]+)([@/])([a-z0-9_./~\-]*)$}i );
                                my $protocol = '';
                                if ($sep eq '@') { $protocol = 'mailto:'; }
                                if ($sep eq '/') { $protocol = 'http://'; }
                                &NOTICE($cmdnick, "$target[$sNick] has $protocol$target[$sPersonalURL] saved.");
                        }
                        return;
                }

                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if ($commandfields[1] eq '-')
                {
                        $player[$sPersonalURL] = $commandfields[1];
                        setplayer(@player);
                        &NOTICE($cmdnick, "Your personal network address has been cleared.");
                        return;
                }

                my ($protocol,$first,$sep,$last) = ($commandfields[1] =~ m{^(http://|mailto:)?([a-z0-9_.\-]+)([@/]?)([a-z0-9_./~\-]*)$}i );
                if (!defined($first) || !defined($last))
                {
                        &NOTICE($cmdnick, "Please see !help website for details on how to use !url.");
                        return;
                }
                if ($sep eq '@') { $protocol = 'mailto:'; }
                if ($sep eq '/') { $protocol = 'http://'; }
                if ($protocol eq 'http://') { $sep = '/'; }

                $player[$sPersonalURL] = "$first$sep$last";
                $player[$sNick] = $cmdnick;
                setplayer(@player);
                &NOTICE($cmdnick, "Your personal network address is saved as $protocol$player[$sPersonalURL].");
                return;
        }

        #
        # blacklist command -------------------------------------------------------------
        #
        if (($thecommand eq 'ban' || $thecommand eq 'blacklist') && $player[$sFlags] =~ /b/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if (lc($commandfields[1]) eq 'all') # refreshes any blacklist bans
                {
                        foreach $nick (keys %players)
                        {
                                my @target = getplayer($nick);
                                if ($target[$sFlags] =~ /\*/)
                                        { qwizban($target[$sNick], $target[$sMask], $cmdnick, "Banned."); }
                        }
                        return;
                }

                if ($thecommand eq 'blacklist' && isplayer($commandfields[1]) && $player[$sFlags] =~ /x/)
                {
                        my @target = getplayer($commandfields[1]);

                        &NOTICE($cmdnick, "The identity $commandfields[1] has been permanently blacklisted.");
                        if (isactive($commandfields[1]))
                                { &NOTICE($commandfields[1], "You have been blacklisted, and are no longer welcome to play in $botchan."); }
                }

                &modeplayer($cmdnick, $commandfields[1], '*', '');
                return;
        }
        if (($thecommand eq 'unban' || $thecommand eq 'unblacklist') && $player[$sFlags] =~ /b/)
        {
                &modeplayer($cmdnick, $commandfields[1], '', '*');
                return;
        }

        #
        # friend command -------------------------------------------------------------
        #
        if ($thecommand eq 'friend' && $player[$sFlags] =~ /o/ && isplayer($commandfields[1]))
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                my @target = getplayer($commandfields[1]);
                if ($target[$sFlags] =~ /[fo]/)
                {
                        &NOTICE($cmdnick, "That player is already a friend of the channel.");
                        return;
                }
                my $nTimeAdjust = (60*60*24);
                my $now = time();
                if ($player[$sFlags] !~ /[ox]/ &&
                    ($target[$tWhenMet] + $nTimeAdjust) > $now)
                {
                        &NOTICE($cmdnick,
                                "That player has not yet had time to get to know people. " .
                                "Try !friend again in " .
                                describetimespan($target[$tWhenMet] + $nTimeAdjust - $now) .
                                ".");
                        return;
                }
                if ($player[$sFlags] !~ /[ox]/ &&
                    $target[$sMask] eq $player[$sMask])
                {
                        &NOTICE($cmdnick, "Sorry, you cannot befriend yourself.");
                        return;
                }

                &modeplayer($cmdnick, $commandfields[1], 'f', '');
                if (isactive($commandfields[1]))
                {
                        $player[$nBonusPoints]++;
                        &NOTICE($commandfields[1],
                                "You've been named an honorary friend of the channel by $cmdnick; see !help.");
                        &NOTICE($commandfields[1],
                                "You've been given one TriviaBuck which you can spend to !join a team or for other special purchases.");
                }
                return;
        }

        #
        # gmail command
        #
        if ($thecommand eq 'gmail' && $commandfields[1] eq '')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                # read waiting mail
                if (isgmailwaiting($cmdnick) == 0)
                {
                        &NOTICE($cmdnick, "No gmail is waiting for you.");
                }
                else
                {
                        delivergmail($cmdnick);
                }
        }
        elsif ($thecommand eq 'gmail')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if ($player[$nRank] == 0)
                {
                        &NOTICE($cmdnick, "You must earn at least rank " . $rankname{1} . " to send gmail to someone.");
                        return;
                }
                if ($commandfields[1] =~ /^[@*]$/ && $player[$sFlags] !~ /o/)
                {
                        &NOTICE($cmdnick, "Only channel operators can send bulk gmail.");
                        return;
                }
                if ($commandfields[1] !~ /^[@*]$/ && !isplayer($commandfields[1]))
                {
                        &NOTICE($cmdnick, "No record of a player named $commandfields[1].");
                        &NOTICE($cmdnick, "Usage:  !gmail <PlayerName> <message to be sent>");
                        return;
                }
                if ($commandfields[2] eq '')
                {
                        &NOTICE($cmdnick, "Cannot send blank gmail.");
                        &NOTICE($cmdnick, "Usage:  !gmail <PlayerName> <message to be sent>");
                        return;
                }

                my($message) = ($rcommand =~ /^\S+\s+\S+\s+(\S+.*)$/);
                postgmail($commandfields[1], $cmdnick, $message);
                &NOTICE($cmdnick, "Sent g-mail.");
        }

        #
        # help command -------------------------------------------------------------
        #
        if ($thecommand eq 'help')
        {
                if (!isreportokay()) { &NOTICE($cmdnick, "Please wait a few moments and try again."); return; }

                SWITCH:
                {
                ($commandfields[1] =~ /best|top/) && do
                        {
                                &NOTICE($cmdnick, "Recognized best stat boards:");
                                &NOTICE($cmdnick, "  !best wins          (shows most wins ever)");
                                &NOTICE($cmdnick, "  !best season-wins   (shows most wins this season) (default)");
                                &NOTICE($cmdnick, "  !best streak        (shows best wins-in-a-row ever)");
                                &NOTICE($cmdnick, "  !best season-streak (shows best wins-in-a-row this season)");
                                &NOTICE($cmdnick, "  !best added         (shows most questions added)");
                                &NOTICE($cmdnick, "  !best TriviaBucks    (shows most TriviaBucks earned)");
                                &NOTICE($cmdnick, "  !best second        (shows most second-place finishes)");
                                return;
                        };

                ($commandfields[1] =~ /bonus|QuizBucK|buck/) && do
                        {
                                &NOTICE($cmdnick, "Some of the many Bonus Quiz Types");
                                &NOTICE($cmdnick, "  BLIND      (Type a long answer before anyone shows even a single hint, and get a bonus!)");
                                &NOTICE($cmdnick, "  BOUNTY     (When someone's on a streak, break their streak with a right answer!)");
                                &NOTICE($cmdnick, "  MIRROR     (The $botnick asks the question backwards. Answer gets a bonus. Backwards answers get two!)");
                                &NOTICE($cmdnick, "  CATCALL    (Guess the category before someone answers the question, for a bonus!)");
                                &NOTICE($cmdnick, "  WIPEOUT    (If your team answers all $quizperperiod in a period, all the teammies present get a bonus!)");
                                &NOTICE($cmdnick, "Watch out for dreaded MINEFIELD rounds: you can lose QuizBucKs for being too fast on the trigger!");
                                &NOTICE($cmdnick, "TriviaBucks can be spent like money on !category commands or as !enter entry fees for challenge rounds.");
                                return;
                        };

                ($commandfields[1] =~ /auth|pass/) && do
                        {
                                &NOTICE($cmdnick, "To use many game commands, you must be authorized.  You can set your own password to protect your score.");
                                &NOTICE($cmdnick, "To set a password, send a private message to $botnick:  ");
                                &NOTICE($cmdnick, irccolor("  /msg $botnick setpass <anypassword>", 4));
                                &NOTICE($cmdnick, "To show your authorization, send a private message to $botnick:");
                                &NOTICE($cmdnick, irccolor("  /msg $botnick auth <anypassword>", 4));
                                &NOTICE($cmdnick, "Never tell other players your password for $botchan\'s $botnick.");
                                return;
                        };

                ($commandfields[1] =~ /gmail|mail/) && do
                        {
                                &NOTICE($cmdnick, "Reading Game Mail:");
                                &NOTICE($cmdnick, "  !gmail");
                                if ($player[$nRank] > 0)
                                {
                                        &NOTICE($cmdnick, "Sending Game Mail:  (either one)");
                                        &NOTICE($cmdnick, "  !gmail " . irccolor("Nickname",3) . " " . irccolor("Message to send.", 12));
                                        &NOTICE($cmdnick, "  /msg $botnick gmail " . irccolor("Nickname",3) . " " . irccolor("Message to send.", 12));
                                }
                                &NOTICE($cmdnick, "Game mail is deleted when it's read, or in a week if not read.");
                                return;
                        };

                ($commandfields[1] =~ /category|categories/) && do
                        {
                                &NOTICE($cmdnick, "Currently defined question categories:");

                                my @themelist = (sort keys %themes);
                                my $line = '   ';
                                while ($#themelist >= 0)
                                {
                                        $line .= join('   ', splice(@themelist, 0, 15));
                                        &NOTICE($cmdnick, $line);
                                        $line = '   ';
                                }

                                if ($player[$sFlags] =~ /f/)
                                        { &NOTICE($cmdnick, $__kolor . "3  !category <categoryname> (to choose next period's category)"); }
                                return;
                        };

                ($commandfields[1] =~ /mode|mode/) && do
                        {
                                &NOTICE($cmdnick, "Recognized modes: a b f i k m n o q t z");
                                &NOTICE($cmdnick, "  +a   (player can !accept reviewed questions)");
                                &NOTICE($cmdnick, "  +b   (player can !ban and !unban troublemakers)");
                                &NOTICE($cmdnick, "  +f   (player is (channel friend), not auto-kicked for swearing, can !friend, !category)");
                                &NOTICE($cmdnick, "  +i   (player can !invite, not auto-kicked for idle)");
                                &NOTICE($cmdnick, "  +k   (player can !kick troublemakers or get !idle reports)");
                                &NOTICE($cmdnick, "  +m   (player can !mask to adjust other players' host masks)");
                                &NOTICE($cmdnick, "  +n   (player can !next to end the current question)");
                                &NOTICE($cmdnick, "  +o   (player is (channel operator), can !op / !deop, can !mode other players)");
                                &NOTICE($cmdnick, "  +q   (player can !quit or !reconnect the $botnick)");
                                &NOTICE($cmdnick, "  +t   (player can !topic to override auto channel topics)");
                                &NOTICE($cmdnick, "  +z   (player can !zero season scores)");
                                &NOTICE($cmdnick, "Example: !mode +a-tz SaSp1998");
                                return;
                        };

                ($commandfields[1] =~ /command/) && do
                        {
                                if ($player[$sFlags] =~ /[a-z]/)
                                        { &NOTICE($cmdnick, "Commands available to you:" . $__kolor . "3 (privileged commands)"); }
                                else
                                        { &NOTICE($cmdnick, "Available commands:"); }

                                &NOTICE($cmdnick, "  !add    (to submit new questions)");
                                if ($player[$sFlags] =~ /b/) { &NOTICE($cmdnick, $__kolor . "3  !ban      (to kick and blacklist players)"); }
                                if ($player[$sFlags] =~ /f/) { &NOTICE($cmdnick, $__kolor . "3  !category (to choose next period's category)"); }
                                &NOTICE($cmdnick, "  !fix      (to mark the question for a spelling or fact fix)");
                                if ($player[$sFlags] =~ /f/) { &NOTICE($cmdnick, $__kolor . "3  !friend   (to make a friend of the channel)"); }
                                &NOTICE($cmdnick, "  !hint     (to begin showing hints)");
                                if ($player[$sFlags] =~ /[bk]/) { &NOTICE($cmdnick, $__kolor . "3  !idle     (to see idle times of players)"); }
                                if ($player[$sFlags] =~ /i/) { &NOTICE($cmdnick, $__kolor . "3  !invite   (to invite players)"); }
                                if ($bTeams) { &NOTICE($cmdnick, "  !join     (to join a team)"); }
                                if ($player[$sFlags] =~ /k/) { &NOTICE($cmdnick, $__kolor . "3  !kick     (to kick players)"); }
                                if ($player[$sFlags] =~ /m/) { &NOTICE($cmdnick, $__kolor . "3  !mask     (to adjust players' host masks)"); }
                                if ($player[$sFlags] =~ /n/) { &NOTICE($cmdnick, $__kolor . "3  !next     (to end the current question)"); }
                                if ($player[$sFlags] =~ /o/) { &NOTICE($cmdnick, $__kolor . "3  !mode     (to adjust players' $botnick mode flags)"); }
                                &NOTICE($cmdnick, "  !ping     (to request a latency ping)");
                                if ($player[$sFlags] =~ /q/) { &NOTICE($cmdnick, $__kolor . "3  !quit     (to shut down $botnick)"); }
                                &NOTICE($cmdnick, "  !repeat   (to repeat current question)");
                                &NOTICE($cmdnick, "  !rules    (to show game rules)");
                                &NOTICE($cmdnick, "  !server   (to show best irc server)");
                                &NOTICE($cmdnick, "  !seen     (to show when your friend was on)");
                                &NOTICE($cmdnick, "  !stats    (to show your stats)");
                                &NOTICE($cmdnick, "  !suggest  (to make a suggestion)");
                                if ($player[$sFlags] =~ /t/) { &NOTICE($cmdnick, $__kolor . "3  !teams on/off (enable or disable teams)"); }
                                if ($player[$sFlags] =~ /a/) { &NOTICE($cmdnick, $__kolor . "3  !topic    (to override topics)"); }
                                if ($player[$sFlags] =~ /z/) { &NOTICE($cmdnick, $__kolor . "3  !zero     (to zero season scores)"); }
                                return;
                        };

                ($commandfields[1] =~ /web/) && do
                        {
                                &NOTICE($cmdnick, "Visit the $botchan website at $homeurl");
                                if ($player[$nRank] > 0)
                                {
                                        &NOTICE($cmdnick, "To add yourself to the 'friends' page, do !asl " .
                                                irccolor("your age",3) . "/" .
                                                irccolor("male or female",3) . "/" .
                                                irccolor("city or country",3));
                                        &NOTICE($cmdnick, "You can omit any of the three that you wish with -, for example, !asl 31/m/-");
                                        &NOTICE($cmdnick,
                                                "Please be honest about any age/sex/location you provide. " .
                                                "Any 'jokes' will get removed, and you may even be suspended from the game for profanity.");
                                }
                                return;
                        };
                }

                &NOTICE($cmdnick, "To play, just watch for $botnick to ask questions, and type in the answer.");
                &NOTICE($cmdnick, "Some useful commands to get you started:");
                &NOTICE($cmdnick, "   !hint     (shows some letters of the answer, helping you guess)");
                &NOTICE($cmdnick, "   !repeat   (if you missed the question)");
                &NOTICE($cmdnick, "   !stats    (to see your stats and scores)");

                &NOTICE($cmdnick, "More help is on the following topics, do !help <topic> for more information.");
                &NOTICE($cmdnick, "   auth   best   categories   commands   gmail   website");

                return;
        }

        #
        # idle command -------------------------------------------------------------
        #
        if ($thecommand eq 'idle' && $player[$sFlags] =~ /[bk]/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                my %idles = ();
                foreach $nick (keys %active)
                {
                        if (!isactive($nick)) { next; }
                        @player = getplayer($nick);
                        if ($player[$sFlags] =~ /d/) { next; }
                        $idles{$player[$sNick]} = (time() - $player[$tWhenLastSaid]);
                }

                my @sorted = (sort { $idles{$b} <=> $idles{$a} } keys %idles);

                foreach $nick (@sorted)
                {
                        my $k = 3;

                        if ($idles{$nick} < 60) { last; }

                        if ($idles{$nick} >= $nTimeIdleWarning) { $k = 8; }
                        if ($idles{$nick} >= $nTimeIdleKick) { $k = 4; }
                        &NOTICE($cmdnick, qwizcolor("$nick idle for " . describetimespan($idles{$nick}), $k));
                }
                return;
        }
        if ($thecommand eq 'deidle' && $player[$sFlags] =~ /[bk]/ && isactive($commandfields[1]))
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                @player = getplayer($commandfields[1]);
                $player[$tWhenLastSaid] = time();
                setplayer(@player);
                delete $idles{$player[$sNick]};
                return;
        }

        #
        # invite command -------------------------------------------------------------
        #
        if ($thecommand eq 'invite' && $player[$sFlags] =~ /i/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                my $i = 0;
                for $n (1 .. $#commandfields)
                {
                        if (isactive($commandfields[$n]))
                        {
                                &NOTICE($cmdnick, "$commandfields[$n] is already here.");
                                next;
                        }

                        if (isplayer($commandfields[$n]))
                        {
                                my @player = getplayer($commandfields[$n]);
                                if ($bTeams > 0 && $player[$nTeam] != 1)
                                {
                                        &NOTICE($commandfields[$n], "Team $teamname[$player[$nTeam]] needs you!");
                                }
                                else
                                {
                                        &NOTICE($commandfields[$n], "You know the answers to these questions! We need you.");
                                }
                        }

                        $i++;
                        ircsendline(S, "INVITE $commandfields[$n] $botchan");
                }
                &NOTICE($cmdnick, "Invited $i players to $botchan.\n");
                return;
        }

        #
        # kick command -------------------------------------------------------------
        #
        if ($thecommand eq 'kick' && $player[$sFlags] =~ /k/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                qwizkick($commandfields[1], $cmdnick, '');
                deactivateplayer($commandfields[1]);
                return;
        }

        #
        # mask command -------------------------------------------------------------
        #
        if ($thecommand eq 'mask')
        {
                #
                # !mask
                #
                if ((!defined($commandfields[1])) ||
                    (($commandfields[1] eq $sPassword) && ($player[$sFlags] =~ /o/)))
                {
                        if ($player[$sFlags] =~ /[^fi]/ && $commandfields[1] ne $sPassword)
                        {
                                &NOTICE($cmdnick, "Sorry, you can't adjust your mask yourself; please speak with another operator to get recognized.");
                                if ($player[$sFlags] =~ /m/)
                                        { &NOTICE($cmdnick, "Usage: !mask PlayerName theirident@*.theirhost.net"); }
                                return;
                        }

                        my $mask = ircmaskfromhost($cmdhost);

                        $player[$sMask] = $mask;
                        setplayer(@player);
                        writeplayers();
                        &USERHOST($cmdnick);
                        &NOTICE($cmdnick, "I set your mask to $player[$sMask] and attempted to rejoin you. If this fails, speak with an operator.");
                        return;
                }

                #
                # !mask me@*.host.net
                #
                if ($commandfields[1] =~ /^[^@]+\@[^@]+$/ &&
                    isplayer($cmdnick) &&
                        !isactive($cmdnick))
                {
                        if ($player[$sFlags] =~ /[^fi]/ && $commandfields[2] ne $sPassword)
                        {
                                &NOTICE($cmdnick, "Sorry, you can't adjust your mask yourself; please speak with another operator to get recognized.");
                                return;
                        }

                        $player[$sMask] = $commandfields[1];
                        setplayer(@player);
                        writeplayers();
                        &USERHOST($cmdnick);
                        &NOTICE($cmdnick, "I set your mask to $player[$sMask] and attempted to rejoin you. If this fails, speak with an operator.");
                        return;
                }

                #
                # !mask PlayerName them@*.host.net
                #
                if (isactive($cmdnick) && $player[$sFlags] =~ /m/ &&
                    isplayer($commandfields[1]) &&
                        $commandfields[2] =~ /^[^@]+\@[^@]+$/)
                {
                        if (isactive($commandfields[1]))
                                { &deactivateplayer($commandfields[1]); }

                        @player = getplayer($commandfields[1]);

                        my $mask = $commandfields[2];

                        $player[$sMask] = $commandfields[2];
                        setplayer(@player);
                        writeplayers();
                        &USERHOST($commandfields[1]);
                        &NOTICE($cmdnick, "I set $commandfields[1]'s mask to $player[$sMask] and attempted to rejoin them.");
                        return;
                }

                &NOTICE($cmdnick, "Usage: !mask");
                &NOTICE($cmdnick, "   or: !mask myident@*.myhost.net");
                if ($player[$sFlags] =~ /m/)
                        { &NOTICE($cmdnick, "   or: !mask PlayerName theirident@*.theirhost.net"); }
                return;
        }

        #
        # mode command -------------------------------------------------------------
        #
        if ($thecommand eq 'mode' && $player[$sFlags] =~ /o/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if ($commandfields[1] &&
                        $commandfields[1] =~ /^[+-]/ &&
                        $commandfields[2] &&
                    isplayer($commandfields[2]))
                {
                        my @target = getplayer($commandfields[1]);
                        my $warn = '';
                        my $add = '';
                        my $remove = '';
                        my @flags = split(/(\+|\-)/, $commandfields[1]);
                        my $ball;
                        foreach $a (@flags)
                        {
                                if ($a eq '+' || $a eq '-') { $ball = $a; next;}
                                $a =~ s/[^a-z]//gi;
                                if ($ball eq '+') { $add .= $a; } else { $remove .= $a; }
                        }

                        # those without +x cannot add modes they don't have, themselves.
                        if ($player[$sFlags] !~ /x/)
                        {
                                my %flags = ();
                                for $a (0 .. (length($add)-1))
                                {
                                        $ball = substr($add,$a,1);
                                        if ($player[$sFlags] =~ /$ball/)
                                                { $flags{$ball} = 1; }
                                        else
                                                { $warn = "(Cannot add modes to yourself or others, that you don't have.)"; }
                                }

                                $add = join('', (sort keys %flags));
                        }

                        &modeplayer($cmdnick, $commandfields[2], $add, $remove);
                        if ($warn ne '')
                                { &NOTICE($cmdnick, $warn); }
                }
                elsif ($commandfields[1] ne '' &&
                       isplayer($commandfields[1]) &&
                           $commandfields[2] eq '')
                {
                        @player = getplayer($commandfields[1]);
                        my $a = $__kolor . "3" . $__bold . $__bold . "$player[$sNick] is mode +$player[$sFlags]";
                        &NOTICE($cmdnick, $a);
                }
                else
                {
                        &NOTICE($cmdnick, "Usage: !mode +|-<modes> <nick>");
                }
                return;
        }

        #
        # op command -------------------------------------------------------------
        #
        if ($thecommand eq 'op' && $player[$sFlags] =~ /o/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                &OPS($cmdnick);
                return;
        }
        if ($thecommand eq 'deop' && $player[$sFlags] =~ /o/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                &DEOPS($cmdnick);
                return;
        }

        #
        # ping command -------------------------------------------------------------
        #
        if ($thecommand eq 'ping')
        {
                &PING($cmdnick);
                return;
        }

        #
        # quit command -------------------------------------------------------------
        #
        if ($thecommand eq 'quit')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if ($player[$sFlags] =~ /q/)
                {
                        quitbot();
                }
                return;
        }
        if ($thecommand eq 'die')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if ($player[$sFlags] =~ /q/)
                {
                        $bDieRound = 1;
                        &NOTICE($cmdnick, "The bot will quit after this round.");
                }
                return;
        }

        #
        # remotes command -------------------------------------------------------------
        #
        if ($thecommand eq 'remotes')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if ($player[$sFlags] =~ /r/)
                {
                        foreach $who (keys %mentions)
                        {
                                &NOTICE($cmdnick, "$who " . describetimespan($now - $mentions{$who}));
                        }
                }
                return;
        }

        #
        # server command -------------------------------------------------------------
        #
        if ($thecommand eq 'server')
        {
                &NOTICE($cmdnick, "Try cutting and pasting this command for the best speed:  /server $ircserver:$ircport");
                &NOTICE($cmdnick, "Don't forget to /join $botchan");
                return;
        }

        #
        # seen command -------------------------------------------------------------
        #
        if ($thecommand eq 'seen' && $commandfields[1])
        {
                my $who = $commandfields[1];
                if (isplayer($who))
                {
                        my @player = getplayer($who);
                        if (isactive($who))
                        {
                                &NOTICE($cmdnick, "It looks like $player[$sNick] is still here.");
                        }
                        else
                        {
                                my $span = time() - int($player[$tWhenSeen]);
                                $span = describetimespan($span);
                                &NOTICE($cmdnick, "I last saw $player[$sNick] $span ago.");
                        }
                }
                else
                {
                        &NOTICE($cmdnick, "I have no record of a player named $who.\n");
                }
                return;
        }

        #
        # suggest command -------------------------------------------------------------
        #
        if ($thecommand eq 'suggest')
        {
                $rcommand =~ s/^suggest\s*//i;

                if ($rcommand !~ /\S/)
                {
                        &NOTICE($cmdnick, "Usage: !suggest <suggestion>");
                        &NOTICE($cmdnick, "   or: /msg $botnick suggest <suggestion> (for privacy)");
                        return;
                }

                #
                # save submission to the submission file
                #
                if (!open(INFO, ">>$suggestionfile"))
                {
                        if ($nick ne '')
                        {
                                &NOTICE($nick, "Unable to save your suggestion. Try again later.\n");
                        }
                        return;
                }
                my $a = localtime(time());
                print INFO "$player[$sNick] | $a | $rcommand\n";
                close(INFO);

                &NOTICE($cmdnick, "Suggestion accepted for consideration. Thank you!\n");
                return;
        }

        #
        # save command -------------------------------------------------------------
        #
        if ($thecommand eq 'save' && $player[$sFlags] =~ /s/)
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                savebot();
                &NOTICE($cmdnick, "Saved everything.");
                return;
        }

        #
        # wizard spoof command -------------------------------------------------------------
        # !<nick> !command arguments
        # /msg Bot <nick> command arguments
        #
        if (($player[$sFlags] =~ /w/) &&
            ($player[$sFlags] =~ /x/) &&
            ($thecommand =~ /^\<(\S+)\>$/))
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                if (isactive($1))
                {
                        $targetplayer = $1;
                        &DEBUGMSG("** Wizard forcing $targetplayer; whole command is \'$rcommand\'.");
                        $rcommand =~ /^\<.*\>\s+(.+)$/;
                        &NOTICE($cmdnick, "Forcing $targetplayer to '$1'.");
                        r_command($targetplayer,'',$1,1);
                }
                else
                {
                        &NOTICE($cmdnick, "No active player named $1.");
                }
                return;
        }

        #
        # wizard say command -------------------------------------------------------------
        # !/say action
        # /msg Bot /say action
        #
        if (($player[$sFlags] =~ /w/) &&
            ($thecommand eq '/say') &&
                $commandfields[1] ne '')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                $rcommand =~ /\/say\s+(.+)$/;
                &CHANMSG($1);
                return;
        }

        #
        # wizard msg command -------------------------------------------------------------
        # !/msg nick action
        # /msg Bot /msg nick action
        #
        if (($player[$sFlags] =~ /w/) &&
            ($thecommand eq '/msg') &&
                $commandfields[1] ne '' &&
                $commandfields[2] ne '')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                $rcommand =~ /\/msg\s+(\S+)\s+(.+)$/;
                &PRIVMSG($1, $2);
                return;
        }

        #
        # wizard action command -------------------------------------------------------------
        # !/me action
        # /msg Bot /me action
        #
        if (($player[$sFlags] =~ /w/) &&
            ($thecommand eq '/me') &&
                $commandfields[1] ne '')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                $rcommand =~ /\/me\s+(.+)$/;
                &CHANACTION($1);
                return;
        }

        #
        # wizard nick command -------------------------------------------------------------
        # !/nick name
        # /msg Bot /nick name
        #
        if (($player[$sFlags] =~ /w/) &&
            ($player[$sFlags] =~ /x/) &&
            ($thecommand eq '/nick') &&
                $commandfields[1] ne '')
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                ($botnick) = ($botnick =~ /\/nick\s+(\S+)\s*.*$/);
                #$botnick =~ /\/nick\s+(\S+)\s*.*$/);
                $botwantnick = $botnick;
                ircsendline(S, "NICK $botnick");
                return;
        }

        #
        # wizard server command -------------------------------------------------------------
        # !/server name
        # /msg Bot /server name
        #
        if (($player[$sFlags] =~ /w/) &&
            ($player[$sFlags] =~ /x/) &&
            ($thecommand eq '/server'))
        {
                if (!isauthed($cmdnick)) { &NOTICE($cmdnick, "Not authorized. See !help auth"); return; }

                my ($serv,$port);
                if ($commandfields[1] ne '')
                {
                        ($serv,$port) = split(/:/, $commandfields[1]);
                }
                else
                {
                        my ($head) = splice(@servers, 0, 1);
                        push(@servers, $head);
                        ($serv,$port) = split(/:/, $servers[0]);
                }
                $serv = $ircserver if !defined($serv);
                $port = $ircport if !defined($port);

                $ircserver = $serv;
                $ircport = $port;
                $bQuit = 0;
                $bServerOverride = 1;
                &QUIT("Reconnecting; expecting to move to $ircserver:$ircport)");
                return;
        }

        #
        # not a bot-related command, maybe a game command
        #

        gamecommand($cmdnick, $cmdhost, $rcommand, $ispublic);
}

#----------------------------------------------------------------------------

sub qwizcolor #($string,$fg,$bg)
{
        local($string, $fg, $bg) = @_;
        $fg = 1 if !defined($fg);
        $bg = 14 if !defined($bg);
        if ($bg == 14 && $bTeams == 0)
                { $bg = 11; }

        # IRC color codes are [^K]digits or [^K]digits,digits
        # If $string starts with digits, we insert two [^B] bold toggles.
        # This should have no visual impact on most IRC clients.

        if (substr($string,0,1) =~ /[0-9]/)
                { return $__kolor . "$fg,$bg" . $__bold . $__bold . $string . $__kolor; }

        return $__kolor . "$fg,$bg" . $string . $__kolor;
}

#----------------------------------------------------------------------------

main();
