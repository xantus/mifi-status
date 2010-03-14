#!/usr/bin/perl
# MiFi Status Panel
# Copyright (c) 2010 - David Davis <xantus@xantus.org> http://xant.us/

# quick and dirty status panel, don't judge me :)

use strict;
use warnings;

use FindBin;
use Glib::EV;
use Gtk2 -init;
use EV;
use AnyEvent::HTTP;
use Gtk2::TrayIcon;
#use Data::Dumper;

# todo get this from ifconfig / wifi device
my $ip = '192.168.1.1';

my $path = $FindBin::Bin."/images";

if ( !-d $path || !-e "$path/0batt1.gif" ) {
    mkdir( $path ) unless ( -d $path );
    my @images = qw(
        1batt.gif
        0batt1.gif
        0batt2.gif
        0batt3.gif
        0batt4.gif
        vzrssi1.gif
        vzrssi2.gif
        vzrssi3.gif
        vzrssi4.gif
        vzrssi5.gif
    );
    if ( $^O eq 'MSWin32' ) {
        print "Download and these images into the images/ dir:\n";
        foreach ( @images ) { print "$_\n"; }
    } else {
        print "Downloading image resources from your MiFi... (using wget)\n";
        system( 'wget', '-q', "http://$ip/images/$_", '-O', "$path/$_" ) foreach ( @images );
    }
}

my $status = [qw(
    Searching
    Connecting
    Connected
    Disconnecting
    Disconnected
    Not Activated
    Modem Failure
    Dormant
    SIM Failure
)];

my $last;
my $info = Gtk2::TrayIcon->new( 'MiFi Status' );
my $label = Gtk2::Label->new( ' Checking ' );
my $tooltip = Gtk2::Tooltips->new;
$tooltip->set_tip( $info, 'MiFi Status Tooltip' );
$info->add( $label );

my $signal = Gtk2::TrayIcon->new( 'MiFi Signal' );
my $signal_icon = Gtk2::Image->new_from_file( "$path/vzrssi1.gif" );
$signal->add( $signal_icon );

my $batt = Gtk2::TrayIcon->new( 'MiFi Battery' );
my $batt_icon = Gtk2::Image->new_from_file( "$path/1batt.gif" );
$batt->add( $batt_icon );

# change the order of the label and icons here
# reverse order
$batt->show_all;
$signal->show_all;
$info->show_all;

my $timer = EV::timer( 1, 0, \&check_mifi );

main Gtk2;

sub check_mifi {
    http_get "http://$ip/getStatus.cgi?dataType=TEXT", \&process;
}

sub process {
    my $r = shift;

    $timer = EV::timer( 3, 0, \&check_mifi );

    if ( !$r || $r !~ m/\x1b/ ) {
        $label->set_text( 'MiFi - Can\'t get status :(' );
        return;
    }

    my $data = {};
    while( $r =~ s/^([^\x1b]+)\x1b// ) {
        my ( $k, $v ) = split( /=/, $1, 2 );
        $data->{$k} = $v;
    }
    unless ( defined $last ) {
        $last = $data;
#        print Data::Dumper->Dump([$data])."\n";
        update( $data, 1 );
        return;
    }

    my $c = {};
    foreach my $k ( keys %$data ) {
        $c->{$k} = $data->{$k} if ( $last->{$k} ne $data->{$k} );
    }

    $last = $data;

    update( $c );

#    print Data::Dumper->Dump([$c])."\n" if ( keys %$c );
}

sub update {
    my $c = shift;
    my $startup = shift || 0;

    return unless ( keys %$c );

    # WwIpAddr
    # WwDNS1
    # BaBattChg
    # WwConnStatus
    # WwRssi
    # WiConnClients
    # BaBattStat
    # WwSessionTxMb
    # WwMask
    # WwNetwkTech
    # WwNetwkName
    # WwGateway
    # WwRoaming
    # WwSessionRxMb

    my $up = $c->{'WwSessionTxMb'} || $last->{'WwSessionTxMb'};
    my $down = $c->{'WwSessionRxMb'} || $last->{'WwSessionRxMb'};
    my $s = $c->{'WwConnStatus'} || $last->{'WwConnStatus'};

    # label
    $label->set_text( sprintf( 'MiFi - %s - Up: %.2f Dn: %.2f ', $status->[ $s ], $up, $down ) );

    # tooltip
    if ( $c->{'WwIpAddr'} || $c->{'WwSessionRxMb'}
        || $c->{'WwSessionTxMb'} || $c->{'WwRoaming'} ) {
        $tooltip->set_tip( $info, sprintf( "%s %s\nIP: %s\nNetmask: %s\nGateway: %s\nDNS: %s\nRoaming: %s\nClients: %s\n\nUpload: %.2f MB\nDownload: %.2f MB",
            @{$last}{qw( WwNetwkName WwNetwkTech WwIpAddr WwMask WwGateway WwDNS1 )},
            ( $last->{'WwRoaming'} ? 'Yes' : 'No' ),
            @{$last}{qw( WiConnClients WwSessionTxMb WwSessionRxMb )}
        ) );
    }

    # signal
    if ( $c->{'WwRssi'} ) {
        $signal_icon->set_from_file( $path.sprintf( '/vzrssi%d.gif', $c->{'WwRssi'} ) );
    }

    # battery charging
    if ( exists $c->{'BaBattChg'} ) {
        my $img = "$path/1batt.gif";

        if ( $c->{'BaBattChg'} == 1 ) {
            $batt_icon->set_from_file( $img );
            if ( !$startup && -x '/usr/bin/notify-send' ) {
                # libnotify doesn't show animated icons, so just show the max charge
                $img = $path.sprintf( '/0batt%d.gif', 4 );
                system( '/usr/bin/notify-send', qw( -u normal -i ), $img, join( ' ', @{$last}{qw( WwNetwkName WwNetwkTech )} ), 'Battery Charging' );
            }
        } else {
            $c->{'BaBattStat'} = $last->{'BaBattStat'};
            if ( !$startup && -x '/usr/bin/notify-send' ) {
                $img = $path.sprintf( '/0batt%d.gif', $c->{'BaBattStat'} );
                system( '/usr/bin/notify-send', qw( -u normal -i ), $img, join( ' ', @{$last}{qw( WwNetwkName WwNetwkTech )} ), 'Battery Discharging' );
            }
        }
    }

    # battery discharging
    if ( $last->{'BaBattChg'} == 0 && $c->{'BaBattStat'} ) {
        my $img = $path.sprintf( '/0batt%d.gif', $c->{'BaBattStat'} );
        $batt_icon->set_from_file( $img );
        # ubuntu: sudo apt-get install libnotify-bin
        if ( $c->{'BaBattStat'} < 2 && -x '/usr/bin/notify-send' ) {
            system( '/usr/bin/notify-send', qw( -u critical -i ), $img, join( ' ', @{$last}{qw( WwNetwkName WwNetwkTech )} ),  'Warning!<br>Battery Low' );
        }
    }
}

1;
