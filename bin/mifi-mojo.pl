#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib/mojo-origin";

$ENV{MOJO_HOME} = $FindBin::Bin;
$ENV{MOJO_POLL} = 1;

use Mojolicious::Lite; # in lib/mojo-origin
use Mojo::JSON;
use Time::HiRes;
use Data::Dumper;


BEGIN {
    # install JSON and JSON::XS if you can!
    eval 'use JSON;';
    eval 'sub HAS_JSON(){ '.( $@ ? 0 : 1 ).'}';
};

# yes, 127.0.1.1 not 127.0.0.1 ( due to issues with flash and local connections )
unless ( @ARGV ) {
    @ARGV = qw( daemon --listen http://127.0.1.1:4000 );
    push( @ARGV, "--lock=$FindBin::Bin/var/mifi-status.lock" );
    push( @ARGV, "--pid=$FindBin::Bin/var/mifi-status.pid" );
}

# globals
# ip of mifi
my $ip = '192.168.1.1';

my $json = HAS_JSON ? JSON->new : Mojo::JSON->new;
my $clients = {};
my $last;
my $history = [];
my $tx = 0;
my $rx = 0;

websocket '/' => sub {
    my $self = shift;
    my $id = scalar( $self->tx->connection );
    my ( $cid ) = $id =~ m/\(0x([^\)]+)\)/;
    $clients->{ $cid } = $self;

    app->log->debug( "ws connect - $id is $cid" );

    $self->finished(sub {
        delete $clients->{ $id };
        return;
    });
    $self->receive_message(sub {
        #my $self = shift;
        #my ( $id ) = scalar( $self->tx->connection ) =~ m/\(0x([^\)]+)\)/;
        check_mifi();
    });
    $self->send_message( $json->encode( { cid => $cid, last => $last || {}, history => $history } ) );
};

get '/favicon.ico' => sub {
    shift->redirect_to( 'http://xant.us/favicon.ico' );
};

get '/' => sub {
    shift->render( 'index', clients => $clients );
};

# see bin/flash-policy-server
print "Remember, you need to also run bin/flash-policy-server as root for this to work...\n";

check_mifi();

app->start;

exit;

sub check_mifi {
    app->client->async->get( "http://$ip/getStatus.cgi?dataType=TEXT" => \&process )->process;
}


sub process {
    my $self = shift;
    my $r = $self->res->body;

#    if ( $timer ) {
#        warn "timer: $timer\n";
#        app->client->ioloop->timer( $timer => { after => 3, cb => \&check_mifi } );
#    }

    if ( !$r || $r !~ m/\x1b/ ) {
        app->log->debug('mifi unavailable');
        return;
    }

    my $data = {};
    while( $r =~ s/^([^\x1b]+)\x1b// ) {
        my ( $k, $v ) = split( /=/, $1, 2 );
        $data->{$k} = $v;
    }

    unless ( defined $last ) {
        $last = $data;
#        push( @$history, $last );
        print Data::Dumper->Dump([$data])."\n";
        update( $data, 1 ) if %$clients;
        return;
    }

    if ( %$clients ) {
        my $c = {};
        foreach my $k ( keys %$data ) {
            $c->{$k} = $data->{$k} if ( $last->{$k} ne $data->{$k} );
        }
        $last = $data;
        if ( keys %$c ) {
            update( $c );
            push( @$history, $c );
            if ( $#{$history} > 50 ) {
                shift @$history;
            }
        }
    } else {
        $last = $data;
    }

}

sub update {
    my $c = shift;
    my $startup = shift || 0;

    print Data::Dumper->Dump([$c])."\n";

    my $data = $json->encode( $c );
    foreach my $cli ( values %$clients ) {
        next unless defined $cli;
        eval {
            $cli->send_message( $data );
        };
        app->log->debug( "Error while sending data: $@" ) if $@;
    }
}

1;
__DATA__

@@ index.html.ep
% my $url = $self->req->url->to_abs->scheme( 'ws' )->path( '/' );
% use Data::Dumper;
<!doctype html>
<html lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>MiFi Status</title>
<meta http-equiv="generator" content="Mojolicious" />
<meta http-equiv="imagetoolbar" content="no" />
<link rel="shortcut icon" type="image/x-icon" href="/favicon.ico" />
<link rel="icon" type="image/x-icon" href="/favicon.ico" />
<meta http-equiv="X-UA-Compatible" content="chrome=1">
<!-- ExtJS CSS -->
<link rel="stylesheet" type="text/css" href="js/ext-3.2-beta/resources/css/ext-all.css" />

<!-- link rel="stylesheet" type="text/css" href="css/mifi-status.css" --/>
</head>
<body scroll="no">

<!-- ExtJS -->
<script type="text/javascript" src="js/ext-3.2-beta/adapter/ext/ext-base.js"></script>
<script type="text/javascript" src="js/ext-3.2-beta/ext-all.js"></script>

<script type="text/javascript" src="js/web-socket-js/swfobject.js"></script>
<script type="text/javascript" src="js/web-socket-js/FABridge.js"></script>
<script type="text/javascript" src="js/web-socket-js/web_socket.js"></script>

<script type="text/javascript">
    WebSocket.__swfLocation = "js/web-socket-js/WebSocketMain.swf";
    Ext.BLANK_IMAGE_URL = 'js/ext-3.2-beta/resources/images/s.gif';
    Ext.onReady(function() {
        var rt = Ext.data.Record.create([
            { name: 'id' },
            { name: 'name' },
            { name: 'rx' }
        ]);

        var store = window.store = new Ext.data.JsonStore({
            reader: new Ext.data.JsonReader( { idProperty: 'id', fields: rt } )
        });
        store.recordType = rt;

        var recId = 0;

        var chart = new Ext.Viewport({
            iconCls: 'chart',
            title: 'MiFi Trafic',
            frame: true,
            width: 700,
            height: 300,
            layout: 'fit',
            items: {
                xtype: 'linechart',
                store: store,
                url: 'js/ext-3.2-beta/resources/charts.swf',
                xField: 'name',
                yField: 'rx',
                yAxis: new Ext.chart.NumericAxis({
                    displayName: 'Rx',
                    labelRenderer : Ext.util.Format.numberRenderer('0.0000')
                }),
                tipRenderer : function(chart, record){
                    return record.data.rx + ' Mb Down / '+record.data.tx + ' Mb Up';
                    //Ext.util.Format.number(record.data.visits, '0,0') + ' visits in ' + record.data.name;
                },
                chartStyle: {
                    xAxis: {
                        color: 0x69aBc8,
                        majorTicks: {color: 0x69aBc8, length: 4},
                        minorTicks: {color: 0x69aBc8, length: 2},
                        majorGridLines: {size: 1, color: 0xeeeeee}
                    },
                    yAxis: {
                        color: 0x69aBc8,
                        majorTicks: {color: 0x69aBc8, length: 4},
                        minorTicks: {color: 0x69aBc8, length: 2},
                        majorGridLines: {size: 1, color: 0xdfe8f6}
                    },
                },
                series: [{
                    type: 'line',
                    displayName: 'Rx',
                    yField: 'rx',
//                    labelRenderer : Ext.util.Format.numberRenderer('0.0000'),
                    style: {
                        color:0x99BBE8
                    }
                },{
                    type:'line',
                    displayName: 'Tx',
                    yField: 'tx',
//                    labelRenderer : Ext.util.Format.numberRenderer('0.0000'),
                    style: {
                        color: 0x15428B
                    }
                }]
            }
        });

        var ws = null;
        var last = {};

        var ping = function() {
            if ( ws ) {
                ws.send( "." );
                ping.defer( 1000 );
            }
        };
        var tick = function() {
            var rx = lastrx || 0;
            var tx = lasttx || 0;
            var r = new rt({ id: ++recId, name: recId, rx: rx, tx: tx }, recId );
            store.add( r );
            if ( store.getCount() > 50 ) {
                store.removeAt( 0 );
            }
            tick.defer( 1000 );
//            if ( ws )
//                ws.send('.');
        };

        var lastrx = 0;
        var lasttx = 0;
        
        var lastrx2 = 0;
        var lasttx2 = 0;

        var connect = function() {
            // Connect to Web Socket.
            // Change host/port here to your own Web Socket server.
            ws = new WebSocket("<%= $url %>");

            // Set event handlers.
            ws.onopen = function() {
                lastrx = 0;
                lasttx = 0;
                ws.send('.');
                ping.defer( 2000 );
            };

            ws.onmessage = function(e) {
                var data = Ext.decode( e.data );
                if ( data.history ) {
                    store.removeAll();
                    var lrx = 0, ltx = 0;
                    for ( var i = 0, len = data.history.length; i < len; i++ ) {
                        if ( data.history[ i ]['WwSessionRxMb'] || data.history[ i ]['WwSessionTxMb']  ) {
                            lrx = ( data.history[ i ]['WwSessionRxMb'] || lrx ) - lrx;
                            ltx = ( data.history[ i ]['WwSessionTxMb'] || ltx ) - ltx;
                            var r = new rt( { id: ++recId, name: recId, rx: lrx, tx: ltx }, recId );
                            store.add( r );
                        }
                    }
                    lastrx = lrx;
                    lasttx = ltx;
                    return;
                }
                if ( data['WwSessionRxMb'] || data['WwSessionTxMb'] ) {
                    if ( data['WwSessionRxMb'] ) {
                        if ( lastrx === 0 )
                            lastrx = data['WwSessionRxMb'];
                        if ( lastrx2 === 0 )
                            lastrx2 = data['WwSessionRxMb'];
                        var tmp = data['WwSessionRxMb'] - lastrx2;
                        lastrx2 = data['WwSessionRxMb'];
                        lastrx = tmp;
                    }
                    if ( data['WwSessionTxMb'] ) {
                        if ( lasttx === 0 )
                            lasttx = data['WwSessionTxMb'];
                        if ( lasttx2 === 0 )
                            lasttx2 = data['WwSessionTxMb'];
                        var tmp = data['WwSessionTxMb'] - lasttx2;
                        lasttx2 = data['WwSessionTxMb'];
                        lasttx = tmp;
                    }
                }
                last = data;
            };

            ws.onclose = function() {
                connect.defer( 5000 );
            };
        };

        tick();

        connect();

        var addrec = function() {
            var d = new Date();
            var r = new rt({ name: d.getHours()+':'+d.getSeconds(), rx: Math.random() * 100 }, ++recId );
            //store.insert( 0, r );
            store.add( r );
            addrec.defer( 3000 );
        };
//        addrec.defer( 1000 );
    });
</script>
</body>
</html>
