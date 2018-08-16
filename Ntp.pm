######################################################
# 時計
#

package Ntp{
use strict;
use warnings;
use utf8;
use threads ('exit' => 'threads_only',);
use lib '.';
use Client;
use Shot3;
use Data::Dumper::AutoEncode;

no warnings 'uninitialized';


my $nownow;
my $btest;
my $basec;
my $offset2;
my $offset;

sub new{
   my $self = shift;
   my $param = shift;
   $offset2 = $param->{offset2}// 0;
   $btest   = $param->{btest}  // 1;
   $nownow  = time();
   $basec   = $param->{basec}  // $nownow;
   bless $param, ref $self || $self;
}

sub param{
   print "\$nownow = $nownow\n";
   print "\$btest  = $btest\n";
   print "\$basec  = $basec\n";
   print "\$offset2= $offset2\n";
   print "\$offset = $offset\n";
}



sub timeno{
   my($self) = @_;
   $offset;
}

sub timem {
   my($self) = @_;
   ( time() - $nownow ) * $btest + $basec + $offset2;
}

sub timen {
   my($self) = @_;
   ( time() - $nownow ) * $btest + $basec + $offset2 + $offset;
}

sub netntp{
   my($self, $ntps) = @_;
###open my $printlog, ">:utf8", "printlog.log";
###print $printlog (timedb time2hash time())->{tosec}."\n";
###print $printlog "● インターネット時刻補正.\n";
   local $_;
   my $svr;
   my($offseter, $e);
   for my $server (split(/,/, $ntps)){
      $svr = $server;
      my ($thr) = threads->create(sub{
         $SIG{'KILL'} = sub{threads->exit()};
         my ($e,$h) = Net::SNTP::Client::getSNTPTime("-hostname",$server);
         ### print eDumper $h;
         return(int($h->{'RFC4330'}{'Clock Offset'}+.5)), $e;
      });

      for( my $now = time ; time - $now < 15 && !$thr->is_joinable() ; sleep 1 ){
      }
      if($thr->is_joinable()){
         ($offseter, $e) = $thr->join();
         if(defined $offseter && ! $e){
            last;
         }else{
            next;
         }
      }else{
         $thr->detach();
         next;
      }
   }
   $offseter //= 0;
###print $printlog " 時刻補正. $offseter sec. （$svr）\n";
   $offset = $offseter;
   $offseter;
}
}
1;
