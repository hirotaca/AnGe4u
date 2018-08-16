######################################################
# 番組表
#
package AnGe4chk{
use strict;
use warnings;
use utf8; # ＵＴＦ－８
use Encode;
use Time::Local;
use File::Basename;
use Perl6::Say;
use LWP::UserAgent;
use LWP::ConnCache;
use URI::Escape qw/uri_unescape/;
use JSON::Parse 'parse_json';
use XML::Simple qw(:strict);
use Data::Dumper::AutoEncode;
use lib '.';
use Shot3;

local $XML::Simple::PREFERRED_PARSER = 'XML::Parser';

my$trn;
my($inc,$dec);
for(my$line="0_00:00",my$i=6;$i>=0;$i--){
 for(my$j=23;$j>=0;$j--){
  for(my$k=30;$k>=0;$k-=30){
   $inc->{sprintf("%1d_%02d:%02d",$i,$j,$k)} = $line;
   $line=sprintf("%1d_%02d:%02d",$i,$j,$k);
  }
 }
}
%$dec=reverse%$inc;

sub maketable{
   local $_;
   my($trn, $eve) = @_;

   print e"番組表作成 開始.\e[0K\n";

   my $task = [
      @{amaketable($trn, $eve)},
      @{rmaketable($trn, $eve)},
      @{jmaketable($trn, $eve)},
   ];
   if(open my $fh, ">", "banner/table.log"){
      local $Data::Dumper::Sortkeys = 1; # ハッシュのキーをソートする
      local $Data::Dumper::Indent   = 1; # インデントを縮める
      local $Data::Dumper::AutoEncode::ENCODING = 'utf8';
      print $fh eDumper $task;
      ### print eDumper $task;
      close $fh;
   }
   print e"番組表作成 終了.\e[0K\n";
   undef @$task;
}


sub nexter{
   my($line) = @_;
###   print $line;
   for my $i(0..47){
      $line = $inc->{$line} or die $!;
   }

   $line =~ /^\d_(\d\d):\d\d$/;

   if(6<= $1 && $1 < 24){
      if($line =~ /^1/){
         $line = $inc->{$line}; #  月曜はずれよう
         #print e"月ずれ\n";
      }
   }else{
      if($line =~ /^2/){
         $line = $inc->{$line}; #  火曜はずれよう
         #print e"火ずれ\n";
      }
   }
   #say " ==================================> ".$line;
   $line;
}





sub amaketable{
   local $_;
   use Web::Scraper;
   my($trn, $eve) = @_;

   my $uri = URI->new($trn->{tableuri});
   my $scraper = scraper{
      process '/html/body/div[2]/div/table/thead/tr/td', 'hidzuke[]' => 'TEXT';
      process 'td', 'htm[]' => scraper{
         process 'td',              'rowspan' => '@rowspan';
         process 'div.time',           'time' => 'TEXT';
         process 'div.time>span>img', 'movie' => '@src';
         process 'div.title-p',       'title' => 'TEXT';
         process 'div.bnr>a>img',    'banner' => '@src';
         process 'div.rp',               'rp' => 'TEXT';
         process 'td',               'repeat' => '@class';
      };
   };
   my $result = $scraper->scrape($uri);
   my $hidzuke;
   for(0..6){
      $result->{hidzuke}[$_] =~ tr■月火水木金土日■1234560■;
      $result->{hidzuke}[$_] =~ m■(\d+)/(\d+)[^\d]+(\d)■ or die $!;
      $hidzuke->[$3] = { mon => $1-1, day => $2 }
   }
   my $line  = '1_06:00';
   my $t = {};
   my $first = {};

   for(my $l=0;$l<=$#{$result->{'htm'}};$l++){
      my $time = shukutai $result->{'htm'}[$l]{'time'}//next;
      next if $time =~ /頃/;
      next if $time =~ /57/;

      while(defined $t->{$line} && $t->{$line}){
         #say e"あるズレ";
         $line = nexter($line);
      }


      ### 検証ゼロ
      $time =~ /^(\d+):\d\d$/;
      if($1 >= 24){
         $time =~ s/^(\d+):(\d\d)$/sprintf("%02d:%02d",$1-24,$2)/e;
      }

      $line =~ s/\d\d:\d\d$/$time/;

      $line =~ /\d\d:\d\d$/;
      if($time ne $&){
         print "\多分,本家の番組表がおかしい(0).\n";
      }



      my $title   = shukutai $result->{'htm'}[$l]{'title'};
      $title   =~ s/\\//;
      my $rp      = shukutai $result->{'htm'}[$l]{'rp'};
      $rp      =~ s/\\//;
      my $rowspan = ($result->{'htm'}[$l]{'rowspan'}/30) // 1;
      ### $rowspan = 2 if $rowspan == 0.5;
      my $movie   = $result->{'htm'}[$l]{'movie'} ? 1 : '';
      my $banner  = $result->{'htm'}[$l]{'banner'} ? File::Spec->catfile('.', 'banner', basename(decode('utf8', uri_unescape(shukutai($result->{'htm'}[$l]{'banner'}))))) : '';
      my $repeat  = $result->{'htm'}[$l]{'repeat'} eq "bg-repeat" ? 1 : "";

      $line =~ /^(\d)_(\d+):(\d+)$/;
      my $epocha = timelocal (0,$3,$2,$hidzuke->[$1]{day},$hidzuke->[$1]{mon},(timedb time2hash time())->{toyear}-1900);
      if($epocha < time() - 15000000){
         $epocha = timelocal (0,$3,$2,$hidzuke->[$1]{day},$hidzuke->[$1]{mon},(timedb time2hash time())->{toyear}-1900+1);
      }

      if($title =~ /ヨルナイト/ || $title =~ /FIVE STARS/i){
         $rowspan = 2;
      } 


      #say e$title;
      #say "[  $rowspan  ]";

      for(my$i=1 , my$tmp=$line ; $i<$rowspan ; $i++){
         $tmp = $inc->{$tmp};
         $t->{$tmp} = ["","",0,"","","",0,0];
         #say "PUMP";
      }
         {
            $time =~ /^(\d+):(\d+)$/;
###         my $timetmp1 = $1 >= 24 ? $1-24 : $1;
            my $timetmp1 = $1;
            my $timetmp2 = $2;

            $line =~ /^\d_(\d+):(\d+)$/;

            unless($timetmp1 == $1 && $timetmp2 == $2){
               print e"\$line = $line\n\$time = $time\n多分,本家の番組表がおかしい(3).\n";
            }
         }

      if(!$repeat){
         my $titletmp = $title;
         $titletmp =~ tr/Ａ-Ｚａ-ｚ０-９！＃＄％＆’（）．\x{3000}/A-Za-z0-9!\#$%&'\(\)\.\x{0020}/;
         $first->{$titletmp}{banner} //= $banner;
         $first->{$titletmp}{fto} = $epocha;
      }

      $t->{$line} = [$title,$rp,$rowspan,$movie,$banner,$repeat,$epocha,$epocha];

      #say e"書き終わり";

      $line = nexter($line);

   }

   for( my $j=0 , my $tmp="0_00:00" ; $j<24*7*2 ; $j++ , $tmp=$inc->{$tmp} ){
      $t->{$tmp} = ["","",1,"","","",0,0] unless defined $t->{$tmp};
      $tmp = $inc->{$tmp};
   }

   for( my $j=0 , my $tmp="0_00:00" ; $j<24*7*2 ; $j++ , $tmp=$inc->{$tmp} ){
      if($t->{$tmp}[5]){
         my $titletmp = $t->{$tmp}[0];
         $titletmp =~ tr/Ａ-Ｚａ-ｚ０-９！＃＄％＆’（）．\x{3000}/A-Za-z0-9!\#$%&'\(\)\.\x{0020}/;
         $t->{$tmp}[4] //= $first->{$titletmp}{banner};
         $t->{$tmp}[7] = $first->{$titletmp}{fto} - 3600*24*7 if $first->{$titletmp}{fto};
      }
   }

   #################################################################
   #say e"書き終わり";

   my $task = [];

   for(my $j=0 , my $tmp="0_00:00" ; $j<24*7*2 ; $j++ , $tmp=$inc->{$tmp}){
#     my $titletmp = ($t->{$tmp})->[0];
#     $titletmp =~ tr/Ａ-Ｚａ-ｚ０-９！＃＄％＆’（）．\x{3000}/A-Za-z0-9!\#$%&'\(\)\.\x{0020}/;
      $task->[$j] = {
         title     => $t->{$tmp}[0],
         rp        => $t->{$tmp}[1],
         banner    => $t->{$tmp}[4],
         repeat    => $t->{$tmp}[5],
         id        => "agqr",
         eveo      => $t->{$tmp}[7],
         comment   => (timedb time2hash $t->{$tmp}[6])->{tomin}."放送",
         filename  => $t->{$tmp}[0]." ".track($t->{$tmp}[6])." ".(timedb time2hash $t->{$tmp}[6])->{tomin}.($t->{$tmp}[5] ? "リピート放送" : ""),
         keepvideo => $t->{$tmp}[3],
         radiko    => 1,
         epocha    => $t->{$tmp}[6],
         epochb    => $t->{$tmp}[6] + $t->{$tmp}[2]*1800,
         margin    => 1,
#      timea     => (timedb time2hash $ft)->{tomin},
#      timeb     => (timedb time2hash ($ft+($t->{$tmp}[2]*1800)))->{tomin},
      };
      #print eDumper $task->[$j];
   }
#   if(open my $fh, ">", "banner/amaketable.log"){
#      local $Data::Dumper::Sortkeys = 1; # ハッシュのキーをソートする
#      local $Data::Dumper::Indent = 1; # インデントを縮める
#      local $Data::Dumper::AutoEncode::ENCODING = 'utf8';
#      print $fh eDumper $task;
#      ### print eDumper $task;
#      close $fh;
#   }

   $task;
}

sub rmaketable{
   local $_;
   my($trn, $eve) = @_;
   #print $printlog (timedb time2hash time())->{tosec}."\n";
   #print $printlog "● radiko 番組表更新.\n";
   my $uar = LWP::UserAgent->new(
      agent   => $trn->{agent},
      timeout => $trn->{timeout},
   );
   #$uar->conn_cache(LWP::ConnCache->new());

   #my $areaid = $trn->{areaid} // "JP13";
   my $task = []; # table
   if($trn->{areaid} =~ /NOID/i){
      print e"△rajiko.jp 番組表取得失敗.\n";
      return $task;
   }

   my %puri;
   $puri{today}    = "http://radiko.jp/v2/api/program/today?area_id=$trn->{areaid}";
   $puri{tomorrow} = "http://radiko.jp/v2/api/program/tomorrow?area_id=$trn->{areaid}";

   my $xmlf;

   my $k = 0;
   for my $pur (keys %puri){
      for(0..3){
         my $r = $uar->get($puri{$pur});
         $xmlf = $r->content;
#         unless(length($xmlf) >= 1024 && $r->is_success){
#            #print $printlog "△rajiko.jp 番組表取得失敗.\n";
#            return "" if $_ >= 15;
#         }
         last if length($xmlf) >= 1024 && $r->is_success;
         say r$xmlf;
         return "" if $_ >= 32;
         print e" ... リトライ(radiko.jp)\e[0K\n";
         sleep 4;
      }

      my $x = XML::Simple->new();
      my $p = $x->XMLin(
         $xmlf,
         ForceArray => 0,
         KeyAttr => []
      );


      for(my $i = 0; defined $p->{stations}{station}[$i]{id}; $i++){
         for(my $j = 0; defined $p->{stations}{station}[$i]{scd}{progs}{prog}[$j]{title}; $j++){
            my $d;
            $d->[$k]{id}    = chompel$p->{stations}{station}[$i]{id};
            $d->[$k]{title} = shukutai3(chompel$p->{stations}{station}[$i]{scd}{progs}{prog}[$j]{title});
            $d->[$k]{pfm}   = shukutai3(chompel$p->{stations}{station}[$i]{scd}{progs}{prog}[$j]{pfm});
            $d->[$k]{pfm}   = "" if $d->[$k]{pfm} =~ /hash/i;
            $d->[$k]{ft}    = locald(chompel$p->{stations}{station}[$i]{scd}{progs}{prog}[$j]{ft});
            $d->[$k]{to}    = locald(chompel$p->{stations}{station}[$i]{scd}{progs}{prog}[$j]{to});
            $d->[$k]{info}  = uri_unescape(chompel$p->{stations}{station}[$i]{scd}{progs}{prog}[$j]{info});
            $d->[$k]{info}  = "" if $d->[$k]{info} =~ /hash/i;
            $d->[$k]{info}  =~ s/\\+//g;
            $d->[$k]{info}  =~ s/"/\\"/g;
            $d->[$k]{info}  =~ /img\s+src='(.+?)'/i;
            $d->[$k]{img}   = $1 // "";
            $d->[$k]{info}  = shukutai(shukutai3 $d->[$k]{info});

            $task->[$k] = {
               title     => $d->[$k]{title},
               rp        => $d->[$k]{pfm},
               banner    => $d->[$k]{img},
               repeat    => "",

               id        => $d->[$k]{id},
               eveo      => $d->[$k]{ft},
               comment   => $d->[$k]{info},
               filename  => $d->[$k]{title}." ".track($d->[$k]{ft})." ".(timedb time2hash $d->[$k]{ft})->{tomin},
               keepvideo => "",
               radiko    => 6,
               epocha    => $d->[$k]{ft},
               epochb    => $d->[$k]{to},
               margin    => 1,
            };
            $k++;
         }
      }
   }
   #if(open my $fh, ">", "rbanner/table.log"){
   #   local $Data::Dumper::Sortkeys = 1; # ハッシュのキーをソートする
   #   local $Data::Dumper::Indent = 1; # インデントを縮める
   #   local $Data::Dumper::AutoEncode::ENCODING = 'utf8';
   #   print $fh eDumper $task;
   #   ### print eDumper $task;
   #   close $fh;
   #}
   $task;
}



sub jmaketable{
   local $_;
   my($trn, $eve) = @_;
   #print $printlog (timedb time2hash time())->{tosec}."\n";
   #print $printlog "● らじる☆らじる 番組表更新.\n";
   my @t = (
     (timedb time2hash $eve         - 3600 * 5)->{today2},
     (timedb time2hash $eve+3600*24 - 3600 * 5)->{today2}
   );

   my$uaj=LWP::UserAgent->new(
      agent   => $trn->{agent},
      timeout => $trn->{timeout},
   );
   #$uaj->conn_cache(LWP::ConnCache->new());
   my $can_accept = HTTP::Message::decodable;

   my $k = 0;
   my $task; # table

   for my $i("r1","r2","n3"){
      for my $j(@t){
         #say $j;
         my $slist;
         for(0..65535){
            local $| = 1;
            my $r = $uaj->get("http://api.nhk.or.jp/r2/pg/list/4/$trn->{areakey}/$i/$j.json",
                              "Accept-Encoding" => $can_accept,);

#            say $r->as_string;
#            say $r->decoded_content;
#            my  $headdder = $r->headers->as_string;
#            say $headdder;
#            $slist = decode_utf8 $r->content;

             $slist = decode_utf8 $r->decoded_content;

            last if(length($slist) >= 16384 && $r->is_success);

            return if $_ >= 32;
            print e" ... リトライ(らじる★らじる)\e[0K\n";
            sleep 4;
         }

         my $p = ((parse_json($slist))->{list}{$i});

         #say eDumper $p;

         for(my $i=0 ;  $i <= $#$p ; $i++){
            my $y;
            $y->[$i]{id}    = "NHKR1" if $p->[$i]{service}{id} eq "r1";
            $y->[$i]{id}    = "NHKR2" if $p->[$i]{service}{id} eq "r2";
            $y->[$i]{id}    = "NHKFM" if $p->[$i]{service}{id} eq "n3";
            $y->[$i]{title} = $p->[$i]{title};
            $y->[$i]{pfm}   = $p->[$i]{act};
            $y->[$i]{ft}    = locald($p->[$i]{start_time});
            $y->[$i]{to}    = locald($p->[$i]{end_time});
            $y->[$i]{img}   = defined $p->[$i]{images}{logo_l} ? $p->[$i]{images}{logo_l}{url} : "";
            $y->[$i]{comment}  = $p->[$i]{content} ? $p->[$i]{content} : $p->[$i]{subtitle};

            $task->[$k++] = {
               title     => $y->[$i]{title},
               rp        => $y->[$i]{pfm},
               banner    => $y->[$i]{img},
               repeat    => "",

               id        => $y->[$i]{id},
               eveo      => $y->[$i]{ft},
               comment   => $y->[$i]{comment},
               filename  => $y->[$i]{title}." ".track($y->[$i]{ft})." ".(timedb time2hash $y->[$i]{ft})->{tomin},
               keepvideo => "",
               radiko    => 7,
               epocha    => $y->[$i]{ft},
               epochb    => $y->[$i]{to},
               margin    => 1,
            };
         }
      }
   }
#   if(open my $fh, ">", "jbanner/table.log"){
#      local $Data::Dumper::Sortkeys = 1; # ハッシュのキーをソートする
#      local $Data::Dumper::Indent = 1; # インデントを縮める
#      local $Data::Dumper::AutoEncode::ENCODING = 'utf8';
#      print $fh eDumper $task;
#      ### print eDumper $task;
#      close $fh;
#   }
   $task;
}

}
############################################################################################
############################################################################################
############################################################################################
############################################################################################
# スキャン
#
package AnGe4scan{
use strict;
use warnings;
use utf8;
use Encode;
use threads ('exit' => 'threads_only',);
use threads::shared;
use Thread::Queue;
use Data::Dumper::AutoEncode;
use Perl6::Say;
use lib '.';
use Shot3;

my$q=Thread::Queue->new();

sub radiscan{
   my ($trn, $eve, $self, $first) = @_;
   local $_;

   print e"予約確認 開始.\e[0K\n";
   my $d;
   my $VAR1;
   {
      open my $fh, "<:utf8", "banner/table.log" or return;
      local $/ = undef;
      my $code = readline $fh;
      close $fh;
      eval $code;
      ### print eDumper $VAR1;
      $d = $VAR1;
      return if $@;
   }
   ### print eDumper $d;
   ### print "$eve\n";
   ### print e((timedb time2hash $eve)->{tomin})."\n";
   ### partial
   my @tk;
   my $to = 0;
   my @q;

   for(my $k=0 ; defined $d->[$k] ; $k++){
      if($first){
         if($d->[$k]{epocha} < $self->{ntp}->timen() && $self->{ntp}->timen() < $d->[$k]{epochb}){
            $tk[$to++] = $k;
            ### say eDumper $d->[$k] if $tk[$k];
         }
      }else{
         if($eve <= $d->[$k]{epocha} && $d->[$k]{epocha} < $eve +1800){
            $tk[$to++] = $k;
         }
      }
   }
   $to--;

   #print eDumper @tk;

   ### exact
   my $section = "";
   open my $fh, "<:utf8", "AnGe4u.ini" or die $!;
   for my $line (readline $fh){
      chompel $line;
      $line = shukutai $line;
      next if $line eq "";
      my $bonus = 0;
      if($line =~ /\[(\w+)\]/){
         if(lc($1) eq "program"){
            $section = 1;
         }else{
            $section = "";
         }
      }elsif($section){

         if($line =~ s/;von.*$//i){
            $bonus += 4;
         }elsif($line =~ s/;voff.*$//i){
            $bonus -= 4;
         }else{
            $line =~ s/;.*$//i
         }

         if(defined $line && $line ne ""){
            for(0..$to){
               if($d->[$tk[$_]]{title}   =~ /$line/ 
               || $d->[$tk[$_]]{rp}      =~ /$line/
               || $d->[$tk[$_]]{id}      =~/^$line$/i
               || $d->[$tk[$_]]{comment} =~ /$line/){
                  $q[$_] = 1;

                  $d->[$tk[$_]]{keepvideo} = $d->[$tk[$_]]{keepvideo}?1:0;
                  $d->[$tk[$_]]{keepvideo}+= 2 if defined $trn->{keepvideo} && $trn->{keepvideo}=~ /allon/i;
                  $d->[$tk[$_]]{keepvideo}-= 2 if defined $trn->{keepvideo} && $trn->{keepvideo}=~ /alloff/i;
                  $d->[$tk[$_]]{keepvideo}+= $bonus;
               }
            }
         }
      }
   }
   close $fh;
   open $fh, "<:utf8", "AnGe4u.ini" or die $!;
   $section = "";
   for my $line (readline $fh){
      chompel $line;
      $line = shukutai $line;
      $line =~ s/;.*$//g;
      next if $line eq "";
      if($line =~ /\[(\w+)\]/){
         if(lc($1) eq "disabled"){
            $section = 1;
         }else{
            $section = "";
         }
      }elsif($section){
         if(defined $line && $line ne ""){
            for(0..$to){
               if($d->[$tk[$_]]{title}   =~ /$line/
               || $d->[$tk[$_]]{rp}      =~ /$line/
               || $d->[$tk[$_]]{id}      =~/^$line$/i
               || $d->[$tk[$_]]{comment} =~ /$line/){
                  $q[$_] = 0;
               }
            }
         }
      }
   }
   close $fh;


#   print eDumper @tk;


   for(0..$to){
      next unless $q[$_];

      if($d->[$tk[$_]]{radiko} == 1){
         next unless ($trn->{recmode} =~ /both/i) || ($trn->{recmode} =~ /repeat/i &&  $d->[$tk[$_]]{repeat}) || ($trn->{recmode} =~ /1st/i && !$d->[$tk[$_]]{repeat});
         #print "agqr\n";
      }elsif($d->[$tk[$_]]{radiko} == 6){
         #print "radiko\n";
      }elsif($d->[$tk[$_]]{radiko} == 7){
         #print "rajiru\n";
      }else{
         print "miss!\n";
      }

      ### バナー準備
      my $filenametmp = "";
      if($d->[$tk[$_]]{img}){
         $filenametmp = uri_unescape(File::Spec->catfile("banner", basename $d->[$tk[$_]]{img}));

         my$uar=LWP::UserAgent->new(
            agent   => $trn->{agent},
            timeout => $trn->{timeout},
         );
         my $res = $uar->get($d->[$tk[$_]]{img}, ':content_file' => e$filenametmp);

         if($res->is_success){
            $d->[$tk[$_]]{img} = $filenametmp;
         }else{
            $d->[$tk[$_]]{img} = "";
         }
      }
      taskgen(
         $trn,
      {
         title     => $d->[$tk[$_]]{title},
         rp        => $d->[$tk[$_]]{rp},
         banner    => $d->[$tk[$_]]{banner},
         repeat    => $d->[$tk[$_]]{repeat},

         id        => $d->[$tk[$_]]{id},
         eveo      => $d->[$tk[$_]]{eveo},
         comment   => $d->[$tk[$_]]{comment},
         filename  => $d->[$tk[$_]]{title}." ".track($d->[$tk[$_]]{eveo})." ".(timedb time2hash $d->[$tk[$_]]{epocha})->{tomin},
         keepvideo => $d->[$tk[$_]]{keepvideo} >= 1 ? 1 : 0,
         radiko    => $d->[$tk[$_]]{radiko},
         epocha    => $d->[$tk[$_]]{epocha},
         epochb    => $d->[$tk[$_]]{epochb},
         margin    => 1,
         timea     => (timedb time2hash $d->[$tk[$_]]{epocha})->{tomin},
         timeb     => (timedb time2hash $d->[$tk[$_]]{epochb})->{tomin},
      }
      );
   }

##############################################################################
##############################################################################
# 時間指定


   open $fh, "<:utf8", "AnGe4u.ini" or return "";
   for(readline $fh){
      s/[\r\n]*//;
      $_ eq '' and next;

      if(/^([\w\-]+)\W*?"([^"]*?)"\W*?(\d+)\W+(\d+)\W+(\d+)\W+(\d+)\W+(\d+)\W+(\d+)\W+(\d+)(\D?.*)/i){
         my ($id,$title,$year,$month,$day,$hour,$min,$sec,$duration,$keepvideo) = ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10);
         $keepvideo = $keepvideo =~ /1|On|Video|Movie|動/i;
         my $tsec = locald "$year,$month,$day,$hour,$min,$sec";

         my $radiko;
            if($id=~/agqr/i)   {$radiko = 1}
         elsif($id=~/NHK\S\S/i){$radiko = 7}
         else                  {$radiko = 6}

         if((($eve <= $tsec) && ($tsec < $eve+1800) && !$first) || 
           (($tsec <= $self->{ntp}->timen()) && ($self->{ntp}->timen() < $tsec+$duration) && $first) ||
           (($self->{ntp}->timen() <= $tsec) && ($tsec < $eve+1800) && $first)){
            taskgen(
               $trn,
            {
               title     => $title,
               rp        => "",
               banner    => "",
               repeat    => "",
               id        => $id,
               eveo      => $tsec,
               comment   => (timedb time2hash $tsec)->{tomin}."放送",
               filename  => "$title ".(timedb time2hash $tsec)->{tomin},
               keepvideo => $keepvideo,
               radiko    => $radiko,
               epocha    => $tsec,
               epochb    => $tsec + $duration,
               margin    => "",
            }
            );
         }

      }elsif(/^([\w\-]+)\W*?"([^"]*?)"[^"月火水木金土日\w]*?([月火水木金土日0-6])[^月火水木金土日\w]+?(\d+)\W+(\d+)\W+(\d+)\W+(\d+)(\D?.*)/i){
         my ($id,$title,$wday,$hour,$min,$sec,$duration,$keepvideo) = ($1,$2,$3,$4,$5,$6,$7,$8);
         $wday =~ tr/日月火水木金土/0123456/;
         $keepvideo = $keepvideo =~ /1|On|Video|Movie|動/i;

         my ($asec,$amin,$ahour,$aday,$amon,$ayear,$awday,undef,undef) = localtime $eve;

         my $yobinum = (localtime $eve)[6];
         next unless $wday == $yobinum; # 曜日一致

         my $tsec = $hour *3600 + $min *60 + $sec;   # target 一日
         my $eveo = $ahour*3600 + $amin*60 + $asec;  # eve    一日

         my $evev = $eve - $eveo; # 今日の０時

         my $radiko;
            if($id=~/agqr/i)   {$radiko = 1}
         elsif($id=~/NHK\S\S/i){$radiko = 7}
         else                  {$radiko = 6}

         if((($eveo <= $tsec && $tsec < $eveo + 1800) && !$first) ||
           (($evev+$tsec <= $self->{ntp}->timen()) && ($self->{ntp}->timen() < $evev+$tsec+$duration) && $first) ||
           (($self->{ntp}->timen() <= $evev+$tsec) && ($evev+$tsec < $eve+1800) && $first)){
            taskgen(
               $trn,
            {
               title     => $title,
               rp        => "",
               banner    => "",
               repeat    => "",
               id        => $id,
               eveo      => ($evev + $tsec),
               comment   => (timedb time2hash ($evev + $tsec))->{tomin}."放送",
               filename  => "$title ".(timedb time2hash ($evev + $tsec))->{tomin},
               keepvideo => $keepvideo,
               radiko    => $radiko,
               epocha    => ($evev + $tsec),
               epochb    => ($evev + $tsec + $duration),
               margin    => "",
            });
         }
      }
   }
   close $fh;
   print e"予約確認 終了.\e[0K\n";
}


##############################################################################
##############################################################################
sub taskgen{
   local $_;
   my($trn, $c) = @_;

   $c->{filename} = kinf(kin($c->{filename}));
   $c->{rp}       = king(kin($c->{rp}      ));
   $c->{comment}  = king(kin($c->{comment} ));
   $c->{comment}  = "" if $c->{comment}  =~ /hash/i;
###$c->{title}    =     (kin($c->{tltle}   ));
   $c->{title}    =~ tr!♡♥💝❤〜−!▽▼▼▼～-!;

   my $z = $trn->{logpath};
   my $vr = $z ?         "--verbose" :         "--quiet";
   my $vf = $z ? "-loglevel verbose" : "-loglevel quiet";
   my $vm = $z ?                "-v" :          "-quiet";

#  my $repeater = (timedb time2hash $c->{repeat})->{tomin} ? "リピート放送" : "";
   my $repeater = $c->{repeat} ? "リピート放送" : "";

   my $filem4a = quot(File::Spec->catfile($trn->{outpath},"$c->{id} $c->{filename}$repeater&&&&.m4a"));
   my $filemp4 = quot(File::Spec->catfile($trn->{outpath},"$c->{id} $c->{filename}$repeater&&&&.mp4"));

   my $logtime = ((timedb time2hash time)->{tosec});
   my $ichigi = sprintf "%04d", int rand 10000;

   my $logrtmpdump = "2>> ".quot(File::Spec->catfile($trn->{logpath}//$trn->{outpath}, "rtmpdump_".$c->{id}." ".$c->{title}." ".$logtime."&&&&".$ichigi.".log"));
   my $logffmpeg   = "2>> ".quot(File::Spec->catfile($trn->{logpath}//$trn->{outpath},   "ffmpeg_".$c->{id}." ".$c->{title}." ".$logtime."&&&&".$ichigi.".log"));
   my $logmp4box   = "2>> ".quot(File::Spec->catfile($trn->{logpath}//$trn->{outpath},   "mp4box_".$c->{id}." ".$c->{title}." ".$logtime."&&&&".$ichigi.".log"));

   $logmp4box   = '2> nul' unless $z;
   $logrtmpdump = "" unless $z;
   $logffmpeg   = "" unless $z;

   my $banner = (-f e$c->{banner}) ? "-itags cover=".quot($c->{banner}) : "";


   main::inifileread($trn);
   my $rtmpdumpoption = $trn->{rtmpdumpoption};
   $rtmpdumpoption =~ s/aandg/$trn->{server}/g;
   # print "RTMPDumpOption : $rtmpdumpoption\n";


   my $rtmpdump;
   if   ($c->{radiko} == 1){$rtmpdump = "$trn->{rtmpdump} $vr $rtmpdumpoption --stop \$\$\$\$ $logrtmpdump |"}
   elsif($c->{radiko} == 6){$rtmpdump = "$trn->{rtmpdump} $vr ________ $logrtmpdump |"}
   elsif($c->{radiko} == 7){$rtmpdump = ""}
   elsif($c->{radiko} == 2){$rtmpdump = ""}
   else{print e"radiko判定が不正.\n"}


   my $ffmpeg;
   if   ($c->{radiko} == 1){$ffmpeg = "$trn->{ffmpeg} $vf $trn->{ffmpegoption} -i pipe:0           -acodec copy"}
   elsif($c->{radiko} == 6){$ffmpeg = "$trn->{ffmpeg} $vf $trn->{ffmpegoption} -i pipe:0           -acodec copy"}
   elsif($c->{radiko} == 7){$ffmpeg = "$trn->{ffmpeg} $vf $trn->{ffmpegoption} -i $trn->{$c->{id}} -acodec copy -bsf:a aac_adtstoasc -t \$\$\$\$"}
   elsif($c->{radiko} == 2){$ffmpeg = ""}
   else{print e"radiko判定が不正.\n"}

#  my $mp4box = "$trn->{mp4box} $vm $trn->{mp4boxoption} -tmp \"$trn->{outpath}\" $banner";
   my $mp4box = "$trn->{mp4box} $vm $trn->{mp4boxoption} $banner";

   my $metadata =  ' -metadata   title='.quot($c->{title}." ".track($c->{eveo}))
                  .' -metadata  artist='.quot($c->{rp})
                  .' -metadata   album='.quot($c->{title})
                  .' -metadata comment='.quot($c->{comment})
                  .' -metadata   genre='.quot('Radio')
                  .' -metadata    date='.quot((timedb time2hash $c->{eveo})->{toyear})
                  .' -metadata    year='.quot((timedb time2hash $c->{eveo})->{toyear})
                  .' -metadata   track='.quot(track $c->{eveo})
                  ;

   my $key_utf8_a = shukutai2 "$rtmpdump $ffmpeg -vn          $metadata $filem4a $logffmpeg";
   my $key_utf8_b = shukutai2 "$mp4box                                  $filem4a $logmp4box";

   my $key_utf8_c = shukutai2 "$rtmpdump $ffmpeg -vcodec copy $metadata $filemp4 $logffmpeg";
   my $key_utf8_d = shukutai2 "$mp4box                                  $filemp4 $logmp4box";

   # sleep(rand(3)+0.1);

   for(1..$trn->{dumpn}){
      my $tmp = $c->{repeat} ? "(R)$c->{title}" : $c->{title};
      if($_ != 1){
         $key_utf8_a =~ s/&&&&/[$_]$&/gi;
         $key_utf8_b =~ s/&&&&/[$_]$&/gi;
         $key_utf8_c =~ s/&&&&/[$_]$&/gi;
         $key_utf8_d =~ s/&&&&/[$_]$&/gi;
         $tmp .= "[$_]";
      }

      my $pak = {};

      $pak->{title}  = $tmp;
      $pak->{cmd}    = $c->{keepvideo} ? $key_utf8_c : $key_utf8_a;
      $pak->{box}    = $c->{keepvideo} ? $key_utf8_d : $key_utf8_b;
      $pak->{tx}     = $c->{radiko};
      $pak->{id}     = $c->{id};

      $pak->{epocha} = $c->{epocha};
      $pak->{epochb} = $c->{epochb};
      $pak->{margin} = $c->{margin};

###   $pak->{repeat} = $c->{repeat};
      $pak->{keepvideo} = $c->{keepvideo};

      if($c->{margin}){
         $pak->{epocha} -= $trn->{premargin};
         $pak->{epochb} += $trn->{postmargin};
      }

      $pak->{duration} = $c->{epochb} - $c->{epocha};

      $q->enqueue($pak);
   }
}


sub childpol{
   my($self, $trn) = @_;
#bp ("childpol",$self, $trn);
   for my $i(1..($trn->{thrn})){
      $trn->{"thr_$i"} = threads->create(\&kindergarten, $self, $i, $trn);
   }
}

sub exiter{
   my ($trn) = @_;
   for my $i(1..($trn->{thrn})){
      $trn->{"thr_$i"}->exit();
   }
}




my$qq="";
share($qq);

sub kindergarten{
   my($self, $i, $trn) =@_;
   my ($command,$commands,$return,$returns) = ("","","","");
   $self->{ind} = Ind->new($i);
   for(my$j=0;;$j=0){
      ### print eDumper $self->{opushon};
      $self->{opushon}->readconfig();
      my $debugpath = "";
      my $pak = {};
      my $cmd3 = "";
      my $quick = 0;
      my $num = "#".$i;
      $self->{ind}->change("","","-","待ち受け");
      my $aa = 0;
      my $bb = 0;
      my $cc = 0;
      $pak = $q->dequeue;
      if($self->{ind} =~ /^\D+$/){
         next if ! defined $pak->{epochb} || $pak->{epochb} < 943887600;
      }
      $self->{ind}->change( "Tx" , $pak->{id} , $pak->{epochb} , $pak->{title} );
      if($pak->{tx} == 0){
         $debugpath .= "J ";
         sleep(rand(5)+.1);
         next;

      }elsif($pak->{tx} == 1){ # agqr
         print e"$num 登録  ".$pak->{id}." : ".$pak->{title}." ".(timedb time2hash $self->{ntp}->timen())->{chksprintf}."\n";
         ### say eDumper $pak;
         $self->{ind}->busy("Wait");
         next if $trn->{rectest};
         $debugpath .= "L ";

      }elsif($pak->{tx} == 2){ # web
         $debugpath .= "H0 ";
         if(!$qq){
            $qq = 1;
            print e"$num 登録  ダウンロード. ".(timedb time2hash $self->{ntp}->timen())->{chksprintf}."\n";
            hibikios($self, $i, $trn);
         }
         next;
      }elsif($pak->{tx} == 6){ # radiko
         print e"$num 登録  ".$pak->{id}." : ".$pak->{title}." ".(timedb time2hash $self->{ntp}->timen())->{chksprintf}."\n";
         $self->{ind}->busy("Wait");
         next if $trn->{rectest};
         $debugpath .= "X ";
      }elsif($pak->{tx} == 7){ # らじる
         print e"$num 登録  ".$pak->{id}." : ".$pak->{title}." ".(timedb time2hash $self->{ntp}->timen())->{chksprintf}."\n";
         $self->{ind}->busy("Wait");
         next if $trn->{rectest};
      $debugpath .= "Y";
      }else{
         print e"$num 登録  ".$pak->{id}." : ".$pak->{title}."\n" ;
         $self->{ind}->busy("Error");
         $debugpath .= "E ";
         sleep 10;
         next;
      }

      $debugpath .= "A3 ";
      $aa = ($pak->{epocha}-$self->{ntp}->timen()-30)*$trn->{btest}; # 30秒前
      $self->{ind}->busy("Wait");
      sleep $aa if 1 <= $aa;

      $debugpath .= "\n";

      $j = 1 if $pak->{epocha} < $self->{ntp}->timen(); # 時間切れはリトライあつかい

      while($pak->{epochb} > (($self->{ntp}->timen() + 120) / $trn->{btest})){

         $debugpath .= "B1[".($pak->{epochb} - $pak->{epocha})."] "; # のこり時間予測量
         $command = $pak->{cmd};

         if($pak->{tx} == 6){
            $self->{ind}->busy("Auth");
            for($cmd3 = "" ; $cmd3 eq "" ;){
               $cmd3 = Rakko2::radikos($trn,$pak->{id}, "");
            }
         }

         $self->{ind}->busy("Adjust");

         my $mark = $j == 0 ? "" : "(".($j+1).")";
         $command =~ s/&&&&/$mark/g;
         $command =~ s/________/$cmd3/;
         $bb = ($pak->{epocha} - $self->{ntp}->timen()) / $trn->{btest};

         sleep $bb if 1 <= $bb;

         if($j==0){
            $cc = $pak->{epochb} - $pak->{epocha};
            $self->{ind}->busy("Busy");
         }else{
            $cc = $pak->{epochb} - $self->{ntp}->timen();
            $self->{ind}->busy(sprintf "Busy%2d",$j+1);
         }

         $cc /= $trn->{btest};                     # 時間圧縮テスト
         $debugpath .= "B2[" . $cc . "] ";         # 自乗あり
         $command =~ s/\$\$\$\$/$cc/g;
         if(defined $trn->{tst0}){ # エラーを出すテスト
            $self->{ind}->busy("Test 0");
            $return = 56;
            sleep $cc if 1 <= $cc;
            $debugpath .= "B3[tst0] ";
         }elsif($cc > 4){
            $return = system e"$command";
            #print e"$command\n\n\n\n";
            $debugpath .= "B4[$return] ";
         }else{
            $self->{ind}->busy("Error");
            $return = 38;
            sleep 4;
            $debugpath .= "B5[Err] ";
         }

         if(!$return && defined !$trn->{tst1}){
            $commands = $pak->{box};
            $commands =~ s/&&&&/$mark/g;
            if($commands =~ /"([^"\.]+?)(\.m4a|\.mp4)"/i){
               my $fn = $1.$2;
               my $hi = $`;
               my $mi = $';
               if((-f e$fn) && ((-s e$fn) >= 512)){
                  $debugpath .= "C1 ";  # MP4Box 実行
                  $self->{ind}->busy("MP4Box");

                  if(defined $trn->{cmcut} && $trn->{cmcut} && $pak->{margin} && $fn =~ /\\agqr\s/ && $j == 0){
                     $self->{ind}->busy("CM Cut");
                     $debugpath .= "C7 ";  # CM Cut
                     my $duration = $pak->{duration};
                     my $fno = Mutoon::mutoon($fn, $trn, $duration, 1);

                     if(-f e($fno) && -s e($fno) >= 512){
                        $returns .= system e"$hi \"$fno\" $mi"; # CMｶｯﾀｰ
                     }else{
                        $self->{ind}->busy("ERR322");
                        sleep 4;
                     }
                  }

                  $returns .= system "start \"MP4Box\" /B /MIN /WAIT " . e$commands;
                  $self->{ind}->busy("Gone");
                  sleep 4;
                  last if $pak->{tx} == 6 || $trn->{btest} != 1; # 無理に終わる
               }else{
                  unlink e$1;
                  $self->{ind}->busy("Err122"); # ファイルが無いか小さい
                  $returns .= " 122";
                  $debugpath .= "C6[".time."] ";
                  sleep 4;
               }
            }else{
               $self->{ind}->busy("ERR201"); # ファイル名がだいぶ違う
               $returns .= " 201";
               $debugpath .= "C0[2] ";
               sleep 4;
            }
         }elsif($quick++ < 128 && $pak->{tx} == 1 && defined $trn->{qrquick} && $trn->{qrquick}){
            $self->{ind}->busy("Quick"); # コマンドが落ちてる
            $debugpath .= "C4[".($pak->{epochb}-$self->{ntp}->timen())."]$trn->{qrquick}\n";
            next;
         }else{
            $self->{ind}->busy(sprintf("Err%03d",$return)); # コマンドが落ちてる
            $returns .= " e$return";
            $debugpath .= "C3\n";
            sleep 4;
         }

         $debugpath .= "E1\n";
#        $self->{ind}->busy("Wait +");

         $j++;
      }

      $debugpath .= "X\n";
      if($trn->{logpath}){
         open my $fh, '>', e(File::Spec->catfile($trn->{logpath},
            "thr_".(kinf(kin($trn->{title})))." ".(timedb time2hash time())->{tosec}.".log")) or print "$!\n";
         print $fh encode_utf8 "\$command  = $command\n";
         print $fh encode_utf8 "\$return   = $return\n";
         print $fh encode_utf8 "\$commands = $commands\n";
         print $fh encode_utf8 "\$returns  = $returns\n";
         print $fh encode_utf8 "\$debugpath= $debugpath\n";
         print $fh encode_utf8  "epocha    = ".$pak->{epocha}."\n";
         print $fh encode_utf8  "epochb    = ".$pak->{epochb}."\n";
         print $fh encode_utf8  " time     = ".(timedb time2hash $self->{ntp}->timen())->{tosec}."\n";
         print $fh encode_utf8  " time A   = ".(timedb time2hash $pak->{epocha})->{tosec}."\n";
         print $fh encode_utf8  " time B   = ".(timedb time2hash $pak->{epochb})->{tosec}."\n";
         print $fh eDumper $pak;
         print $fh eDumper $trn;
         close $fh;
      }
   }
}


sub onsenhibiki{
###   open my $fh, "+<", "banner/onhibi.log" or return;
###   flock $fh, 2;
###   my $queueline = readline $fh;
###   my @tmp = split(/\s+/,$queueline);
###   my $w = shift @tmp;
###   truncate($fh, 0);
###   seek($fh, 0, 0);
###   print $fh join(" ",@tmp);
###   close $fh;

      $q->enqueue({
         title  => "ダウンロード準備中",
         tx     => 2,
         epocha => 0,
         epochb => "-",
         cmd    => "",
         box    => "",
         id     => "",
      });
}


sub hibikios{
   my($self, $i, $trn) = @_;
   while(-e "banner/onhibi.log" && !-z "banner/onhibi.log"){
      my $queueline;
      {
         open my $fh, "+<", "banner/onhibi.log" or return;
         flock $fh, 2;
         
         $queueline = readline $fh;
         close $fh;
         if($queueline =~ /^\s*$/){
            unlink "banner/onhibi.log";
            return;
         }
      }
      

      {
         open my $fh, "+<", "banner/onhibi.log" or return;
         flock $fh, 2;
         my @tmp = split(/\s+/,$queueline);
         my $w = shift @tmp;
         truncate($fh, 0);
         seek($fh, 0, 0);
         print $fh join(" ",@tmp);
         close $fh;

         if(0 <= $w && $w <= 6){
            Thamo4::exam($w, $i, $trn, $self);
         }elsif(10 <= $w && $w <= 16){
            Anko4::exam($w-10, $i, $trn, $self);
         }else{
            print "字が間違ってるとしか.\n";
         }
      }
   }
   $qq="";
   unlink "banner/onhibi.log" if -z "banner/onhibi.log";
}
}
########################################################################
########################################################################
########################################################################
########################################################################
########################################################################
########################################################################
########################################################################
package Ind{
use strict;
use warnings;
no warnings 'uninitialized';
use utf8;
use Encode;
use Data::Dumper::AutoEncode;

my @dat;
my $thr;

sub new{
   my $self = shift;
   $thr = shift;
   @dat = ("","","-","待ち受け");
   mkdir "banner";
   open my $fh, ">:utf8", "banner/thr$thr.log" or die $!;
   print $fh join(",",$dat[0],$dat[1],$dat[2],$dat[3]);
   bless \@dat, ref $self || $self;
}

sub change{
   local $_;
   my $self = shift;
   @dat = @_;
   open my $fh, ">:utf8", "banner/thr$thr.log" or die $!;
   print $fh join(",",$dat[0],$dat[1],$dat[2],$dat[3]);
}

sub busy{
   local $_;
   my $self = shift;
   $dat[0] = shift;
   open my $fh, ">:utf8", "banner/thr$thr.log" or die $!;
   print $fh join(",",$dat[0],$dat[1],$dat[2],$dat[3]);
}

sub DESTROY{
   local $_;
   my($self) = @_;
   @dat = ();
   unlink "banner/thr$thr.log" or die $!;
}
}
############################################################################################
############################################################################################
############################################################################################
############################################################################################
package Mutoon{
use strict;
use warnings;
use utf8; # ＵＴＦ－８
use Perl6::Say;
use File::Spec;
use Data::Dumper::AutoEncode;
use Audio::Wav;
use File::Temp qw/tempdir/;
use lib '.';
use Shot3;
use constant TICK => 24;
use constant DEBUG => 0;
use constant MUTECHAIN => 0.010;
use constant MUTEWIDTH => 0.080;
use constant MUTESENSE => 0.000;
use constant SPEED => int(512 ** (1/3));
use constant LV => 4;
use constant LV2 => LV * 4;


my $loglevel = "-loglevel quiet";

sub printee($){
   my ( $sec, $min, $hour, $day, $mon, $year, $mday, $yday, $isdst ) = gmtime($_[0]);
   sprintf "(%02d:%02d:%02d.%03d)" ,$hour, $min,  $sec, ($_[0] - int($_[0])) * 1000;
}

sub points(@){
   my $aaa;
   $aaa  = e printee($_[0]);
   $aaa .= "  ";
   $aaa .= e printee($_[1]);
   $aaa .= "->";
   $aaa .= e printee($_[2]);
   $aaa .= sprintf "  Duration [%5.3f]", $_[2] - $_[0];
   $aaa .= "  Cut ".printee($_[1]);
}


#############################################################
### 無音部分を探す ##########################################


sub high($){

   local $| = 1;

   my $wav = new Audio::Wav;
   my $r = $wav->read(e shift);

   my $length = $r->length();
   my ($details, undef) = $r->details();

   local $Data::Dumper::Sortkeys = 1; # ハッシュのキーをソートする
   local $Data::Dumper::Indent = 1; # インデントを縮める

   print e Dec Dumper $details;

   my $count = 0;
   my $pos = $details->{data_start} + $details->{sample_rate};
   $r->move_to($pos);
   my $data = ($r->read())[0];

   my $sd = 0;
   my $cue = [];

   while(defined $data && $pos < $details->{data_finish}){
      $count = ( - LV <= $data && $data <= LV - 1 ) ? $count + 1 : 0 ;

      if($count >= SPEED){
      
         my $to   = low ( $pos                       , $r );
         my $from = lowb( $pos -               SPEED , $r );

         my $dur = ($to - $from) / $details->{bytes_sec};

         my ( $sec, $min, $hour, $day, $mon, $year, $mday, $yday, $isdst ) =  gmtime($pos /$details->{bytes_sec} );
         print e sprintf  "[%02d:%02d:%02d.%03d]  ",$hour, $min,  $sec,             ($pos /$details->{bytes_sec}*1000)%1000;

            ( $sec, $min, $hour, $day, $mon, $year, $mday, $yday, $isdst ) =  gmtime($from/$details->{bytes_sec} );
         print e sprintf  "(%02d:%02d:%02d.%03d)"  ,$hour, $min,  $sec,             ($from/$details->{bytes_sec}*1000)%1000;

            ( $sec, $min, $hour, $day, $mon, $year, $mday, $yday, $isdst ) =  gmtime($to  /$details->{bytes_sec} );
         print e sprintf"->(%02d:%02d:%02d.%03d)"  ,$hour, $min,  $sec,             ($to  /$details->{bytes_sec}*1000)%1000;

         my $center = ($to+$from)/2;

         printf "  Duration [%5.3f]  Cut (%8.3f) = %10d    CM:=%8.3f\n",$dur,$center/$details->{bytes_sec},$pos,$center/$details->{bytes_sec} - $sd;

         $sd = $center/$details->{bytes_sec};
         $pos = $to;
         $count = 0;


         push @$cue,[$from/$details->{bytes_sec},$center/$details->{bytes_sec},$to/$details->{bytes_sec},""];

      }
      $pos += SPEED*2;
      $r->move_to($pos);
      $data = ($r->read())[0];

   }
   $r->DESTROY();
   return $cue;
}


sub low($$){
   my $to = shift;
   my $r = shift;
   $r->move_to($to);
   for( my $data = ($r->read())[0] ; defined $data ; $data = ($r->read())[0] ){
      last unless - LV2 <= $data && $data <= LV2 - 1;
      ### say c$r->position();
   }
   return $r->position();
}


sub lowb($$){
   my $from = shift;
   my $r = shift;
   $r->move_to($from);
   for( my $data = ($r->read())[0] ; defined $data ; $data = ($r->read())[0] ){
      last unless ( - LV2 <= $data ) && ( $data <= LV2 - 1 ) && ( $r->position() > 2 );
      $from -= 2;
      $r->move_to($from);
      ### say r$r->position();
   }
   return $r->position() + 2;
}

###########################################################
### 番組の長さについて ####################################

sub labelprog($$){
   local $_;

   my $cue = shift;
   my $duration = shift;

   my @prs = (
      6*1800 - 60,
      5*1800 - 60,
      4*1800 - 60,
      3*1800 - 60,
      2*1800 - 60,
      1*1800 - 60,
   );

   my ($ii,$jj);
   my $pdur;

   lf:for(@prs){
      next if $_ >= $duration; # 予選


      #print " $cue->[1][2] - $cue->[0][0] = ".($cue->[1][2] - $cue->[0][0])."\n";
      #print " $cue->[1][0] - $cue->[0][2] = ".($cue->[1][0] - $cue->[0][2])."\n";
      #say $#$cue;

      lq:for(my$i = 0      ; $i <= $#$cue-1 ; $i++){
         for(my$j = $#$cue ; $j >  $i       ; $j--){

            if(($cue->[$j][2] - $cue->[$i][0] > $_)
             &&($cue->[$j][0] - $cue->[$i][2] < $_)){
               ($ii,$jj)=($i,$j);
               $pdur = $_;
               say e sprintf"############################  (%3d->%3d) [ %4d ]", $ii, $jj, $pdur;
               last lf;
            }
         }
      }
   }
   if(defined $ii && defined $jj &&  defined $pdur){
      my($pstart,$pstop) = cutpos($cue,$ii,$jj,$pdur);
#     return undef unless defined $pstart && defined $pstop;
      pop   @$cue;
      shift @$cue;
      return $pstart,$pstop;
   }
   return undef,undef;
}

############################################################
## CM の長さについて #######################################


sub labelcm($){

   my $cue = shift;
#   if($#$cue <= 1){
#      return;
#   }

   my $cmpoint = [];

   local $_;

   my($i,$j,$k,$flag);
   my @cutt;
   for($i=0;$i<$#$cue;$i++){
      $flag = "";
      koko: for $j (60,40,30,19.5,20,14.5,15){
         for($k=$i+1; $k<$#$cue; $k++){
            if($cue->[$k][2] - $cue->[$i][0] > $j
            && $cue->[$k][0] - $cue->[$i][2] < $j){

               $cue->[$i][3] = !$cue->[$i][3];
               $cue->[$k][3] = !$cue->[$k][3];

               my($a,$b) = cutpos_2($cue, $i, $k, $j);
               if(@cutt && $cutt[$#cutt] == $a){
                  pop @cutt;
               }else{
                  push(@cutt, $a);
               }
               push(@cutt, $b);
               $flag = $j;

               last koko;
            }
         }
      }
      if($flag){
#        say e sprintf "%s => %s (%4d)  %7.2f - %7.2f  span (%3d , %3d)" , 
         say e sprintf "%s => %s (%3.1f)  %7.2f - %7.2f  span (%3d , %3d)" , 
            printee $cue->[$i][1] ,
            printee $cue->[$k][1] ,
            $flag,
            $cue->[$k][0] - $cue->[$i][2] ,
            $cue->[$k][2] - $cue->[$i][0] ,
            $i, $k;

            $i = $k - 1;

      }else{
         say e sprintf "%s => (  :  :  .   ) (____)  %7.2f - %7.2f  span (%3d ,    )" , 
            printee $cue->[$i][1] ,
        ### printee $cue->[$k][1] ,
            $cue->[$k][0] - $cue->[$i][2] ,
            $cue->[$k][2] - $cue->[$i][0] ,
            $i ;
      }
   }


   for(my$i=0; $i<=$#$cue; $i++){
      $cmpoint->[$i] = $cue->[$i][1];
   }
   return @cutt;
}


### 平和な感じに切り口を切る ################################

sub cutpos($$$$){

   local $_;

   my $cue = \shift;
   my $f = shift;
   my $t = shift;
   my $duration = shift;



   if(($$cue->[$t][2] - $$cue->[$f][0] > $duration)
    &&($$cue->[$t][0] - $$cue->[$f][2] < $duration)){

      my $room0 = $$cue->[$f][2] - $$cue->[$f][0];
      my $room1 = $$cue->[$t][2] - $$cue->[$t][0];
      my $roomx = $duration - ($$cue->[$t][0] - $$cue->[$f][2]);

      my $thex = $roomx * $room0 / ($room0 + $room1);

      my $starttime = $$cue->[$f][2] - $thex;

      for(($t+1)..$#$$cue){pop   @$$cue}
      for(0..($f-1))      {shift @$$cue}

      return $starttime, $starttime + $duration;

   }else{
      return undef, undef;
   }
}


### アグレッシブに切り口を切る ################################

sub cutpos_2($$$$){

   my $cue = \shift;
   my $f = shift;
   my $t = shift;
   my $duration = shift;


   my ($starttime, $stoptime);
   if($$cue->[$t][0] - $$cue->[$f][0] <= $duration){
      $starttime = $$cue->[$f][0];
      $stoptime  = $$cue->[$f][0] + $duration;
      $$cue->[$t][0] = $stoptime;
      $$cue->[$t][1] = ($$cue->[$t][0] + $$cue->[$t][2])/2;
   }else{
      $stoptime  = $$cue->[$t][0];
      $starttime = $$cue->[$t][0] - $duration;
      $$cue->[$f][0] = $starttime;
      $$cue->[$f][1] = ($$cue->[$f][0] + $$cue->[$f][2])/2;
   }
      say "damejan 1" unless $stoptime  <= $$cue->[$t][2]; 
      say "damejan 2" unless $starttime >= $$cue->[$f][0]; 


   return $starttime, $stoptime;
}
#########################################################################
### つながってる無音点を合体させる ######################################

sub squeeze($){
   my $cue = shift;
   for(my$i=0 ; $i < $#$cue ; $i++){
      if($cue->[$i+1][0] - $cue->[$i][2] < MUTECHAIN){
         $cue->[$i][2] = $cue->[$i+1][2];
         $cue->[$i][1] = ( $cue->[$i][0] + $cue->[$i][2] ) / 2;
         splice @$cue , $i+1 , 1 ; # バグってる
         $i--;
      }
   }
   for( my$i=0 ; $i < $#$cue ; $i++ ){
      if($cue->[$i][2] - $cue->[$i][0] < MUTEWIDTH){
         print e points @{$cue->[$i]};
         print e sprintf "  CM:=%8.3f",$cue->[$i+1][0] - $cue->[$i][2];
         print "\n";
         splice @$cue , $i , 1;
         $i--;
      }else{
         print e points @{$cue->[$i]};
         print e sprintf "  CM:=%8.3f",$cue->[$i+1][0] - $cue->[$i][2];
         print "\n";
      }
   }
   return $cue;
}



#####################################################################################################
### 切るところを決める ##############################################################################
sub multcut($$){
   local $_;

   my $cue = shift;
   my $duration = shift;
  for(my$i=0 ; $i <= $#$cue ; $i++){
      $cue->[$i][0] -= MUTESENSE;
      $cue->[$i][2] += MUTESENSE;
   }


#####################################################################################################
### 番組全体の大きさ #####################################################


   my ( $pstart , $pstop ) = labelprog $cue , $duration;
   say e"labelprogでベイルアウト" unless defined $pstart && defined $pstop;;
   return [undef, undef]          unless defined $pstart && defined $pstop;


####################################################################################################
### 切りながらそろえる #####################################################


   my @point = labelcm($cue);


#####################################################################################################
### 仕上げ #######################################################

   @point = ($pstart, @point, $pstop);
   say e"切る場所そのもの";

   for(my $i = 0; $i <= $#point - 1 ; $i++){
######print  e sprintf ("%9.3f (%3d:%02d) CM:=:%9.3f \n", $point[$i], $point[$i]/60, $point[$i]%60, $point[$i]   - $point[$i-1]);
      print  e sprintf ("%9.3f (%3d:%02d) CM:=:%9.3f \n", $point[$i], $point[$i]/60, $point[$i]%60, $point[$i+1] - $point[$i]);
   }
   print  e sprintf ("%9.3f (%3d:%02d)\n", $point[$#point], $point[$#point]/60, $point[$#point]%60);
   return \@point;
}


#####################################################################
# メイン
#####################################################################

sub mutoon{
   local $_;

   my ($fn, undef, $duration, $test) = @_;

   my $dir =  File::Temp->newdir();
   my $tempdir = d $dir->dirname;
   $dir->unlink_on_destroy(1);
#  my $tempdir = d tempdir(CLEANUP => 1);
#  my $tempdir = "tmp";


   my $wavename = File::Spec->catfile("$tempdir", "###tmp###.wav");
   my $metatxt  = File::Spec->catfile("$tempdir", "###metadata###.txt");
   my $context  = File::Spec->catfile("$tempdir", "###file_list###.txt");
      $wavename =~ s/\\/\\\\/g;
      $metatxt  =~ s/\\/\\\\/g;
      $context  =~ s/\\/\\\\/g;

   my $fno = $fn;
   $fno =~ s/\.m4a$|\.mp4$/(N)$&/i;

   system e"ffmpeg -i \"$fn\" -f ffmetadata $loglevel -y \"$metatxt\"";

   my $ret = system e"ffmpeg -i \"$fn\" -ar 4096 -ac 1 $loglevel -y \"$wavename\"";

   my $cue = [[]];
      $cue = high ( $wavename ) ;

   my $point = multcut ( $cue , $duration );

   say e "メインでベイルアウト" unless defined $point->[0] && defined $point->[1];
   return 0                    unless defined $point->[0] && defined $point->[1];

   my $myopt = ($fn =~ /\.m4a$/i) ? ("-c:a copy -vn") : ("-c:a copy -c:v copy");
   my $myext = $& if $fn =~ /\.m4a$|\.mp4$/i;


   open my $fh, ">:utf8", e$context;
   print $fh "# 合体ファイルリスト\n";
   for(my $i = 0 , my $f = shift @$point , my $t = shift @$point ; defined $f && defined $t ; $i++ , $f = shift @$point , $t = shift @$point){

      printf $fh "# ■■ %02d:%02d  ⇒  %02d:%02d\n",int($f/60),$f%60,int($t/60),$t%60;

      my $dur = $t - $f;
      my $concat = File::Spec->catfile($tempdir, sprintf("###TMP%02d###%s", $i, $myext)) ;
      $concat =~ s/\\/\\\\/g;
      my $command = "ffmpeg -i \"$fn\" -ss $f -to $t $loglevel $myopt -y \"$concat\"";
      say e$command;
      system e$command;
      print $fh "file $concat\n";
   }
   close $fh;
   undef $fh;


   system e"ffmpeg -f concat -safe 0 -i \"$context\" -i \"$metatxt\" -map_metadata 1 $loglevel $myopt -y \"$fno\"";

   unlink $context;

   return $fno;

}
}
########################################################################
########################################################################
########################################################################
########################################################################
########################################################################
package Rakko2{
use strict;
use warnings;
use utf8; # ＵＴＦ－８
use Perl6::Say;
use Encode;
use File::Spec;
use LWP::UserAgent;
use LWP::Protocol::https;
use HTTP::Headers;
use XML::Simple qw(:strict);
use MIME::Base64;
use Compress::Zlib;
use Data::Dumper::AutoEncode;
use lib '.';
use Shot3;





###########################################################
sub radikos{
                                  #########################
   local $_;

   my ($trn, $station, $nine) = @_;

   my $ua = LWP::UserAgent->new(
      agent   => $trn->{agent},
      timeout => $trn->{timeout},
   );

   my $playerswf = "myplayer-release.swf";
   my $playerurl = "http://radiko.jp/apps/js/flash/".$playerswf;
   my $playerfile= File::Spec->catfile(".",$trn->{ini},$playerswf);

   my $wait = 4;

   $station //= "QRR";

###########################################################
#

   if(!-f $playerfile){
      for(0..3){
         my $res = $ua->get(
            $playerurl,
            ":content_file" => $playerfile
         );
         last if $res->is_success;
         sleep $wait;
      }
   }
   if(! -f e$playerfile){
      print e"プレイヤファイル入手失敗\n$playerfile\n";
      return "";
   }
############################################################
#


   my $buf;
   {
   open my $fh00, "<", $playerfile or return "";
   binmode $fh00;
   local $/ = undef;
   read $fh00, $buf, 8;
   $buf = readline $fh00;
   die "zlib header error\n" unless $buf =~ /^\x78\xDA/;
   $buf = uncompress($buf);
   $buf =~ /......JFIF/;
   $buf = $&.$';
  }

############################################################
#

   my $r = HTTP::Request->new( POST => 'https://radiko.jp/v2/api/auth1_fms');

   $r->header("pragma" => "no-cache");
   $r->header("X-Radiko-App" => "pc_ts");
   $r->header("X-Radiko-App-Version" => "4.0.0");
   $r->header("X-Radiko-User" => "test-stream");
   $r->header("X-Radiko-Device" => "pc");
   $r->header("post-data" => '\r\n');
   $ua->ssl_opts(verify_hostname => 0);

   my $auth1_fms;
   for(0..3){
      my $res = $ua->request($r);
      $auth1_fms = $res->as_string;
      last if $res->is_success;
      sleep $wait;
   }
   unless($auth1_fms =~ /200 OK/i){
      print e"第１認証失敗.(101)\n";
      return "";
   }

############################################################
#

   my ($authtoken, $offset, $length);
   {
   local $/ = undef;
   local *STDERR;
   open STDERR, '>', undef;
   $authtoken = $1 if $auth1_fms =~ /x-radiko-authtoken: ([\w-]+)/il;
   $offset =    $1 if $auth1_fms =~ /x-radiko-keyoffset: (\d+)/il;
   $length =    $1 if $auth1_fms =~ /x-radiko-keylength: (\d+)/il;
   }

   unless($authtoken && $offset && $length){
      print e"第１認証失敗.(102)\n";
      return "";
   }


   my $partialkey = chompel( encode_base64 substr $buf, $offset, $length);

############################################################
#

   $r = HTTP::Request->new( POST => 'https://radiko.jp/v2/api/auth2_fms');
   $r->header("pragma" => "no-cache");
   $r->header("X-Radiko-App" => "pc_ts");
   $r->header("X-Radiko-App-Version" => "4.0.0");
   $r->header("X-Radiko-User" => "test-stream");
   $r->header("X-Radiko-Device" => "pc");
   $r->header("X-Radiko-Authtoken" => $authtoken);
   $r->header("X-Radiko-Partialkey" => $partialkey);
   $r->header("post-data" => '\r\n');
   $ua->ssl_opts(verify_hostname => 0);

   my $auth2_fms;
   for(0..3){
      my $res = $ua->request($r);
      $auth2_fms = $res->content;
      last if $res->is_success;
      sleep $wait;
   }

   if($auth2_fms =~ /([^,\r\n]+?),[^,]+?,[^,]+?$/){
      print e Dec "$auth2_fms\n";
      return $1 if defined $nine && $nine eq "-9";
   }else{
      print e"第２認証失敗.\n";
      return;
   }

############################################################
#
   $r->header("pragma" => "no-cache");
   $r->header("X-Radiko-App" => "pc_ts");
   $r->header("X-Radiko-App-Version" => "4.0.0");
   $r->header("X-Radiko-User" => "test-stream");
   $r->header("X-Radiko-Device" => "pc");
   $r->header("X-Radiko-Authtoken" => $authtoken);
   $r->header("X-Radiko-Partialkey" => $partialkey);
   $r->header("post-data" => '\r\n');
   $ua->ssl_opts(verify_hostname => 0);

   my $xmlx;
   for(0..3){
      my $res = $ua->get("http://radiko.jp/v2/station/stream/$station.xml");
      $xmlx = $res->content;
      last if $res->is_success;
      sleep $wait;
   }

   my @url_parts = ($1, $2, $3, $4) if $xmlx =~ m!<item>\s*(.*)://(.*?)/(.*)/(.*?)\s*</item>!;

############################################################
#

   my $quiet = $trn->{logpath} ? " --verbose" : " --quiet";

   my $cmd3 =
       ### "trn->{rtmpdump}"
        $quiet
       ." --rtmp \"$url_parts[0]://$url_parts[1]\""
       ." --app \"$url_parts[2]\""
       ." --playpath \"$url_parts[3]\""
       ." -W $playerurl"
       ." -C S:\"\" -C S:\"\" -C S:\"\" -C S:\"$authtoken\""
       ." --live"
       ." --stop \$\$\$\$"
       ." --timeout 120"
       ;

   return $cmd3;
}
}
############################################################################################
############################################################################################
############################################################################################
############################################################################################
package main{
use Perl6::Say;
use utf8;
#use Encode;
use lib '.';
use Shot3;
use Ntp;

main();

sub main{
   my $self ={};
   my $trn  ={};
   #my $thr;

   configer($self,$trn);

#bp ($self,$trn);

   my $nownow = time();
   my $param = {
      offset2 => $trn->{offset2},
      btest   => $trn->{btest},
      nownow  => $nownow,
      basec   => $trn->{ftime} ? locald ($trn->{ftime}) : $trn->{nownow},
   };

   print e"時刻補正";
   $self->{ntp} = Ntp->new($param);
   $self->{ntp}->netntp($trn->{ntps});
   print e(" ".$self->{ntp}->timeno()." 秒.\n");

#bp ($self,$trn);

   my $thr_child  = threads->create(\&AnGe4scan::childpol, $self, $trn);
   my $thr_table  = threads->create(\&table,    $self, $trn);
   my $thr_scan   = threads->create(\&scan,     $self, $trn);
   my $thr_onhibi = threads->create(\&download, $self, $trn);
   my $thr_eonhibi= threads->create(\&eonhibi,  $self, $trn);

   for(;;){
      if(!$thr_table->is_running){
         $thr_table = threads->create(\&table, $self, $trn);
         print ll("table リスタート.")."\e[0K\n";
      }
      if(!$thr_scan->is_running){
         $thr_scan = threads->create(\&scan, $self, $trn);
         print r("scan リスタート.")."\e[0K\n";
      }

      if(-e "banner/shutdown"){
         unlink "banner/shutdown";
         unlink "banner/onhibi.log";
         AnGe4scan::exiter($trn);
#         for my $i(1..($trn->{thrn})){
#            unlink "banner/thr$trn->{\"thr$i\"}";
#         }
         $thr_child ->  detach;
         $thr_table ->  detach;
         $thr_scan  ->  detach;
         $thr_onhibi->  detach;
         $thr_eonhibi-> detach;
         exit;
      }
      sleep 4;
   }
}

sub table{
   my($self, $trn) = @_;

   AnGe4chk::maketable($trn, (int($self->{ntp}->timen()/1800)) * 1800);
   AnGe4scan::radiscan($trn, (int($self->{ntp}->timen()/1800)) * 1800, $self, 1);

   for(;;){
      my $eve = (int($self->{ntp}->timen()/1800) + 1) * 1800;
      my $chk = $eve - 900;
      while($chk >= $self->{ntp}->timen()){
         #exit if int rand(1.01); # only for test ***
         sleep 4;
      }
      sleep rand(100)+1;
      AnGe4chk::maketable($trn, $eve);
      while($eve >= $self->{ntp}->timen()){
         #exit if int rand(1.01); # only for test ***
         sleep 4;
      }
   }
   $self->{ntp}->netntp($trn->{ntps});
}

sub scan{
   local $| = 1;
   my($self, $trn) = @_;
   my $thr;

   for(;;){
      my $eve = (int($self->{ntp}->timen()/1800) + 1) * 1800;
      my $chk = $eve - ($trn->{setuptime}//3)*60;
      while($chk >= $self->{ntp}->timen()){
         #exit if int rand(1.01); # only for test ***
         print e((timedb time2hash $self->{ntp}->timen())->{tosec})."\e[0K\e[1G";
         print eDumper $trn;
         sleep 1;
         ### print e((timedb time2hash $self->{ntp}->timen())->{tosec}."\n");
      }
      inifileread($trn);
      AnGe4scan::radiscan($trn, $eve, $self, "");
      while($eve >= $self->{ntp}->timen()){
         #exit if int rand(1.01); # only for test ***
         print e((timedb time2hash $self->{ntp}->timen())->{tosec})."\e[0K\e[1G";
         print eDumper $trn;
         sleep 1;
      }
   }
}


sub eonhibi{
   for(;;){
      my($self, $trn) = @_;
      print e"音泉 響 定期ダウンロードチェック.\n";
      inifileread($trn);
      onhibiqueue($self, [ 1, 2, 3, 4, 5, 6   ], $trn) if $trn->{ehibiki};
      onhibiqueue($self, [11,12,13,14,15,16,10], $trn) if $trn->{eonsen};
      sleep 3600 * 2;
   }
}


sub onhibiqueue{
   my($self, $pu, $trn) = @_;
   if(! -e "banner/onhibi.log"){
      open my $fh0, ">", "banner/onhibi.log" or die $!;
      close $fh0;
   }
   open my $fh, "+<", "banner/onhibi.log" or die $!;
   flock $fh, 2;
   my $queueline = readline $fh;
   my @tmp = split(/\s+/,$queueline);
   push @tmp, @$pu;
   truncate($fh, 0);
   seek($fh, 0, 0);
   print $fh join(" ",@tmp);
   close $fh;
}


sub download{
   my($self, $trn) = @_;
   for(;;){
      if(-e "banner/onhibi.log" && ! -z "banner/onhibi.log"){
         AnGe4scan::onsenhibiki;
      }
      sleep 4;
   }
}

sub inifileread{
   local $_;
   my($trn) = @_;
   open(my $fh, "<:utf8", "AnGe4u.ini") or Wx::MessageBox("AnGe4u.ini を開けません. : $!");
   my $section = "komento";
   for(readline $fh){
      s/[\r\n]*$//;
      s/^\x{20}+//;
       s/\x{20}+$//;
      if(/\[(\w+)\]/i){
         $section = $1;
      }elsif(lc($section) eq "config"){
         /\s*(\S+)\s*=\s*(\S+)/;
         $trn->{$1} = $2;
      }
   }
   close $fh;
   return $trn;
}

sub configer{
   use Cwd;
   use FindBin;
   use Opshon3;

   ($self,$trn) = @_;

   local $_;


   my $kidopath = d(getcwd());
   my $angepath = d($FindBin::Bin);
   if(! chdir e$angepath){
      print e"ディレクトリ移動失敗. : $!";
      return;
   }
   my $ini = d"banner";
   mkdir e$ini;
   unlink "banner/onhibi.log";

   $self->{opushon} = Opshon3->new($trn);
   $self->{opushon}->readconfig();
   $self->{opushon}->cmdlopt();

   $trn->{kidopath} = $kidopath;
   $trn->{angepath} = $angepath;
   $trn->{ini}      = $ini;

   $trn->{ntps} //= join(",",qw/
             ntp.nict.jp
     ntp.jst.mfeed.ad.jp
   s2csntp.miz.nao.ac.jp
          ntp.ring.gr.jp
         jp.pool.ntp.org
     ats1.e-timing.ne.jp
       ntp.shoshin.co.jp
   /);

   $trn->{offset2}   //=  0;
   $trn->{setuptime} //=  3;
   $trn->{premargin} //= 15;
   $trn->{postmargin}//= 15;
   $trn->{outpath}   //= ".";
   $trn->{logpath}   //= "";
   $trn->{btest}     //=  1;
   $trn->{recmode}   //= "Both";
   $trn->{keepvideo} //= "Auto";
   $trn->{ehibiki}   //=  0;
   $trn->{eonsen}    //=  0;
   $trn->{thrn}      //=  8;
   $trn->{rectest}   //= ($trn->{btest} == 1) ? "" : 1 ;

   print e"● radiko.jp トレーニング";
   for(0..3){
      $trn->{areaid} = Rakko2::radikos($trn,undef,"-9");
      if($trn->{areaid}){;
         print e" - 終了.\n";
         print e" エリアＩＤ $trn->{areaid}.\n";
         last;
      }else{
         sleep 4;
      }
   }
   $trn->{areaid}   //= "NOID";

   open my $fh, ">:utf8", "banner/areaid.log";
   print $fh $trn->{areaid};
   close $fh;
   undef $fh;

   $trn->{rtmpdump} //= File::Spec->catfile('.','rtmpdump.exe');
   $trn->{ffmpeg}   //= File::Spec->catfile('.','ffmpeg.exe');
   $trn->{mp4box}   //= File::Spec->catfile('.','mp4box.exe');
   $trn->{dumpn}    //= 1;
   $trn->{rtest}    //= 100000;

   $trn->{agent}    //= 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)';
   $trn->{timeout}  //= 20;

   $trn->{tableuri} //= 'http://www.agqr.jp/timetable/streaming.html';

   $trn->{rtmpdumpoption} //=
       '--rtmp "rtmpe://fms1.uniqueradio.jp/"'
      .' -a "?rtmp://fms-base2.mitene.ad.jp/agqr/"'
      .' -f "WIN 16,0,0,257"'
      .' -W "http://www.uniqueradio.jp/agplayerf/LIVEPlayer-HD0318.swf"'
      .' -p "http://www.uniqueradio.jp/agplayerf/newplayerf2-win.php"'
      .' -C B:0'
      .' -y "aandg"'
      .' --live'
      .' --timeout 120'
      ;
   $trn->{server} = 'aandg1';
   $trn->{ffmpegoption}   //= '-y';
   $trn->{mp4boxoption}   //= '-dref -ipod';


   use Web::Scraper;
   $trn->{nhkloc} //= "東京";
###my $uri = URI->new("https://www3.nhk.or.jp/netradio/app/config_pc_2016.xml");
   my $uri = URI->new("http://www.nhk.or.jp/radio/config/config_web.xml");
   my $scraper = scraper{
      process "radiru_config>stream_url>data", "htm[]" => scraper{
         process "areajp"  => "AREAJP"  => "TEXT";
         process "areakey" => "AREAKEY" => "TEXT";
         process "r1hls"   => "NHKR1"   => "HTML";
         process "r2hls"   => "NHKR2"   => "HTML";
         process "fmhls"   => "NHKFM"   => "HTML";
      };
   };
   my $result = $scraper->scrape($uri);
   for(0..$#{$result->{htm}}){
      if($result->{htm}[$_]{AREAJP} eq $trn->{nhkloc}){
         $trn->{NHKR1} = $result->{htm}[$_]{NHKR1};
         $trn->{NHKR1} =~ /http[^\[\]]*m3u8/;
         $trn->{NHKR1} = quot($&);
         $trn->{NHKR2} = $result->{htm}[$_]{NHKR2};
         $trn->{NHKR2} =~ /http[^\[\]]*m3u8/;
         $trn->{NHKR2} = quot($&);
         $trn->{NHKFM} = $result->{htm}[$_]{NHKFM};
         $trn->{NHKFM} =~ /http[^\[\]]*m3u8/;
         $trn->{NHKFM} = quot($&);
         $trn->{areakey} = $result->{htm}[$_]{AREAKEY};
      }
   }

   jc($self);

}

sub jc{
   my $self = shift;
   local $_;

   mkdir e$trn->{ini} if ! -d (e$trn->{ini});
   if(300000000 < time - (stat $trn->{ini})[9] && time - (stat $trn->{ini})[9] < 300003600){
      print "*** Failed ***\n少し時間をおいて試してください.目安は10分後." unless $_;
      exit 255;
      return "";
   }

   my $toolok = 1;

   Hane2::summon_7za();
   $toolok &&= !!execheck($self,"7za.exe","u","^7-Zip");

   Hane2::summon_ffmpeg();
   $toolok &&= !!execheck($self,"ffmpeg.exe","-L","^ffmpeg");

   Hane2::summon_rtmpdump();
   $toolok &&= !!execheck($self,"rtmpdump.exe","-h","^RTMPDump") ? 1 : "";

   Hane2::summon_mp4box();
   $toolok &&= !!execheck($self,"mp4box.exe","-version","^MP4Box");

   if($toolok){
      utime(time, time, $trn->{ini});
   }else{
      rendachk $self;
      print "ツールを正しく導入できません.\n時間をおいて再度試すか\n直接ダウンロードしてください." unless $_;
      exit 255;
   }
}

sub execheck{
   local $_;
   my $self = shift;
   my $exe = shift;
   my $opt = shift;
   my $exp = shift;
   return 0 unless -f $exe;
   open my $h, File::Spec->catfile(".",$exe)." $opt 2>&1 |";
   my $line = getline $h;
   chomper $line;

   return 1 if defined $line && $line =~ /$exp/;
   $line = getline $h;
   chomper $line;
   return 1 if defined $line && $line =~ /$exp/;
   print e"$exe が見つかりません." unless $_;
   exit 255;
   return 0;
}


#BEGIN{
#   open my $fh, ">", "banner/shutdown";
#   unlink "banner/onhibi.log";
#   for my $i(1..$trn->{thrn}){
#      open my $fh "banner/thr$trn->{thr_$i}";
#      print $fh "N/A,N/A,N/A,N/A";
#      close $fh;
#   }
#   unlink "banner/shutdown";
#}
#END{
#      unlink "banner/shutdown";
#      unlink "banner/onhibi.log";
#      for my $i(1..$trn->{thrn}){
#         unlink "banner/thr$trn->{\"thr$i\"}";
#      }
#      $thr_child ->  detach;
#      $thr_table ->  detach;
#      $thr_scan  ->  detach;
#      $thr_onhibi->  detach;
#      $thr_eonhibi-> detach;
#};
}
############################################################################################
############################################################################################
############################################################################################
############################################################################################
package Hane2{
use strict;
use warnings;
use utf8; # ＵＴＦ８
use Perl6::Say;
use Archive::Zip;
use File::Copy;
#use File::chdir;
use File::Basename;
use File::Spec;
use LWP::UserAgent;
use URI::Escape qw/uri_unescape/;
use Web::Scraper;

#   local *STDOUT;
#   open STDOUT, '>', undef;


# open my $fh, ">", File::Spec->catfile($AnGe4w::trn->{ini}, "hane2.log") or die $!;


sub fda2{
   local $_;
   print "+--(f0)--- $_[0]->{M}\n";
   if(!defined $_[0]->{T}){
      print  "!!!! Downloading (wait for a LONG TIME) !!!!\n";
      my $ua      = 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)';
      my $timeout = 10;
      print "+--(f1)--- $_[0]->{M}\n";
      my $lwp = LWP::UserAgent->new(agent => $ua, timeout => $timeout);
      my $res = $lwp->get($_[0]->{L}, ':content_file' => "$_[0]->{M}");
      if(!$res->is_success){
         print "ツールが導入できません. 手動でお願いします.\nhttp://hirotaca.blog.fc2.com/blog-entry-243.html";
         exit;
      }
      print "+--(f2)--- $_[0]->{M}\n";
      return !!$res->is_success;
   }else{
      print "+--(f3)--- $_[0]->{M}\n";
      return !!copy(File::Spec->catfile("../testfile",$_[0]->{M}), ".");
   }
   print "+--(f4)--- $_[0]->{M}\n";
}


sub cto2{
   local $_;
   print "+(c0)----- $_[0]->{S}\n";
   my $zip = Archive::Zip->new();
   return undef unless -f $_[0]->{M};
   $zip->read($_[0]->{M});
   print "+(c1)----- $_[0]->{S}\n";
   my @members = $zip->members();
   for my $each (@members) {
      $zip->read($_[0]->{M});
      my $name = $each->fileName();
      if($name =~ /$_[0]->{E}/i){
         print "+(c3)----- $_[0]->{S}\n";
         $zip->read($_[0]->{M});
         $zip->extractMemberWithoutPaths($name);
         return 1
      }
      $zip->read($_[0]->{M});
   }
   print "+(c4)----- $_[0]->{S}\n";
   return "";
}


sub xtr7za{
   local $_;
   my $fnp = "";
   print "+--(x0)--- $_[0]->{M}\n";
   return undef unless -f $_[0]->{M};
   open my $h, "7za.exe l $_[0]->{M} |" or return undef;
   print "+--(x1)--- $_[0]->{M}\n";
   for my $line(readline $h){
      if($line =~ /$_[0]->{E}/i){
         print "+--(x3)--- $_[0]->{M}\n";
         $fnp = $&;
         last;
      }
   }
   close $h;
   print "+--(x4)--- $_[0]->{M}\n";
   return "" unless $fnp;
   print "+--(x5)--- $_[0]->{M}\n";
   return ! system "7za.exe e -y $_[0]->{M} $fnp > nul";
}


sub downxtr{
   local $_;
   print "+---(z0)-- ".($_[0]->{M}//$_[0]->{S})."\n";
   if(! -f $_[0]->{S}){
      print "+---(z1)-- ".($_[0]->{M}//$_[0]->{S})."\n";
      if(! -f ($_[0]->{M}//"")){
         print "+---(z2)-- ".($_[0]->{M}//$_[0]->{S})."\n";
         fda2 $_[0];
      }else{
         print "+---(z3)-- ".($_[0]->{M}//$_[0]->{S})."\n";
      }

      print "+---(z4)-- ".($_[0]->{M}//$_[0]->{S})."\n";

      if($_[0]->{M} =~ /\.zip$/i){
         print "+---(z5)-- ".($_[0]->{M}//$_[0]->{S})."\n";
         return cto2 $_[0];
      }elsif($_[0]->{M} =~ /\.7z$/i){
         print "+---(z6)-- ".($_[0]->{M}//$_[0]->{S})."\n";
         return xtr7za $_[0];
      }else{
         print "+---(z7)-- ".($_[0]->{M}//$_[0]->{S})."\n";
         return "";
      }
   }
   print "+---(z8)-- ".($_[0]->{M}//$_[0]->{S})."\n";
}


sub ffmpegscr{
   local $_;
   my $coon = $_[0];
   print "+-----(s0) $coon->{S}\n";
   opendir my $dh, ".";
   for my $line (readdir $dh){
      if($line =~ /$coon->{G}/i){
         print "+-----(s1) $coon->{S}\n";
         $coon->{M} = $&;
         return $coon;
      }
   }
   print "+-----(s2) $coon->{S}\n";

   if(! -f ($coon->{M} // "") && ! -f $coon->{S}){
      print "+-----(s3) $coon->{S}\n";
      print  "!!! Scraping !!!\n";
      my $scraper = scraper{
         process('a', 'lnk[]' => '@href');
      };
      print "+-----(s4) $coon->{S}\n";
      my $result = $scraper->scrape(URI->new($coon->{U}));
      print "+-----(s5) $coon->{S}\n";
#      my $counter = rand(6);
      foreach my $line (@{$result->{'lnk'}}){
         print "+-----(s6) $coon->{S} $line\n";
         if($line =~ /$coon->{F}/i){
            print "+-----(s7) $coon->{S}\n";
            my ($fn, $path, $ext) = fileparse($&, '.7z');
            my $fn1 = File::Spec->catfile($fn, "bin", $coon->{S});
            my $fn2 = $fn.$ext;
            $coon->{L} = $&;
            $coon->{M} = $fn2;
#            last if $counter-- <= 0;
         }
      }
      print "+-----(s8) $coon->{S}\n";
   }
   print "+-----(s9) $coon->{S}\n";
   return $coon;
}



sub summon_7za{
   downxtr({
###   'L' => 'http://jaist.dl.sourceforge.net/project/sevenzip/7-Zip/15.11/7z1511.exe',
###   'L' => 'http://osdn.jp/frs/g_redir.php?m=kent&f=/sevenzip/F7-Zip/9.20/7za920.zip',
###   'L' => 'http://mirror.liquidtelecom.com/sourceforge/s/se/sevenzip/7-Zip/15.12/7z1512.exe',
###   'L' => 'http://mirror.liquidtelecom.com/sourceforge/s/se/sevenzip/7-Zip/9.20/7za920.zip',
###   'L' => 'http://osdn.jp/frs/g_redir.php?m=kent&f=/sevenzip/7-Zip/9.20/7za920.zip',
      'L' => 'http://jaist.dl.sourceforge.net/project/sevenzip/7-Zip/9.20/7za920.zip',
      'M' => '7za920.zip',
      'S' => '7za.exe',
      'E' => '7za.exe',
   });
}



sub summon_mp4box{
   downxtr({
      'L' => 'http://sada5.sakura.ne.jp/files/MP4Box/MP4Box_0.5.1-DEV-rev4868+50-git-7b8f8c3.7z',
      'M' => 'MP4Box_0.5.1-DEV-rev4868+50-git-7b8f8c3.7z',
      'S' => 'MP4Box.exe',
      'E' => 'MP4Box.*\\\\win32\\\\MP4Box.exe',
   });
}


sub summon_ffmpeg{
   downxtr(
      ffmpegscr({
         'U' =>  'https://ffmpeg.zeranoe.com/builds/win32/static/',
#         'F' =>  'https://ffmpeg.zeranoe.com/builds/win32/static/ffmpeg-[^\-]*?-[^\-]*?-win32-static\\.7z$',
#         'G' =>                                                '^ffmpeg-[^\-]*?-[^\-]*?-win32-static\\.7z$',
#         'E' =>                                                 'ffmpeg-[^\-]*?-[^\-]*?-win32-static\\\\bin\\\\ffmpeg\\.exe',
#         'E' =>                                                 'ffmpeg[^\\\\]+\\\\bin\\\\ffmpeg\\.exe',
         'F' =>  'https://ffmpeg.zeranoe.com/builds/win32/static/ffmpeg-latest-win32-static\\.zip$',
         'G' =>                                                '^ffmpeg-latest-win32-static\\.zip$',
         'E' =>                                                 'ffmpeg-latest-win32-static.bin.ffmpeg.exe',
         'S' => 'ffmpeg.exe',
      })
   );
}

sub summon_rtmpdump{
   downxtr({
      'L' => 'https://rtmpdump.mplayerhq.hu/download/rtmpdump-2.4-git-010913-windows.zip',
      'M' => 'rtmpdump-2.4-git-010913-windows.zip',
      'S' => 'rtmpdump.exe',
      'E' => 'rtmpdump.exe',
   });
}
}
############################################################################################
############################################################################################
############################################################################################
############################################################################################
package Anko4{
use strict;
use warnings;
use utf8;
use Perl6::Say;
use Encode;
use File::Copy qw/move/;
use File::Basename;
use File::Spec;
use File::Temp qw/tempdir/;
use Time::HiRes;
use LWP::UserAgent;
use JSON::Parse 'parse_json';
use XML::Simple qw(:strict);
use Data::Dumper::AutoEncode;
use lib '.';
use MP3::Tag;
use Shot3;

sub exam{
   my ($i, $id, $trn, $self, $log) = @_;
#  my $tempdir = d tempdir(CLEANUP => 1);
   my $dir =  File::Temp->newdir();
   my $tempdir = d $dir->dirname;
   $dir->unlink_on_destroy(1);

   open my $fh, ">", e(File::Spec->catfile($trn->{logpath},"Anko_(".yoobi($i).") ".((timedb time2hash time)->{tosec}).".log")) if $trn->{logpath};
   $self->{ind}->change("PriPro", "onsen", "Download", "音泉 準備中");

   my $ua = $trn->{agent}//'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)';
   my $timeout = $trn->{timeout}//10;
   my $wait = 1;
#   my($s,$n) = Time::HiRes::gettimeofday;
#   my $timestamp = $s . substr($n,0,3);

###########################################################
# 目次のダウンロード
#
   $self->{ind}->change("Index", "onsen", "Download", "音泉 番組表取得中");

   my $prog = LWP::UserAgent->new(
      "agent"   => $ua,
      "timeout" => $timeout,
   );

   my $res;

   for my $k (0..3){
      $res = $prog->get("http://www.onsen.ag/api/shownMovie/shownMovie.json");
      last if $res->is_success;
      sleep $wait;
   }
   if(!$res->is_success){
      $self->{ind}->change("", "", "-", "");
      return;
   }

   my $slist = $res->content;

   print $fh $slist if $trn->{logpath};

   my $programlist = parse_json($slist);

   print $fh eDumper $programlist if $trn->{logpath};

   for my $idp (@{$programlist->{result}}){

      for my $k (0..3){
         $res = $prog->get("http://www.onsen.ag/data/api/getMovieInfo/$idp");
         last if $res->is_success;
         sleep $wait;
      }
      next unless $res->is_success;

      my $tmp = $res->content;
      $tmp =~ s/^callback\(//;
      $tmp =~ s/\)\;\s*$//;
      print $fh $tmp if $trn->{logpath};

      my $ref = parse_json($tmp);
      print $fh eDumper($ref) if $trn->{logpath};

      if(!$ref->{moviePath}){
         print $fh encode_utf8("そんなファイルはない : ".($idp//"")."\n") if $trn->{logpath};
         next;
      }

      if(defined $ref->{schedule} && $ref->{schedule}){
         if($ref->{schedule} =~ /([月火水木金土日])曜/){
            my $ref->{yobinum} = $1;
            $ref->{yobinum} =~ tr/日月火水木金土/0123456/;
            next if $ref->{yobinum} != $i; # 曜日違い
         }else{
            next;
         }
      }

      $self->{ind}->change("Analysis", "onsen", "Download", "音泉 番組表日付展開");

      next if ! $ref->{update};

      my($year,$mon,$day) = split(/\./, ($ref->{update}//"0.0.0"), 3);
      my $date = (timedb time2hash locald(join(",",split(/\./, $ref->{update}),0,0,0)))->{anko};

      my $sharp;
      if($ref->{count} =~ /^\d+$/){
         $sharp = sprintf("#%03d", $ref->{count});
      }else{
         $sharp = "#$ref->{count}";
         $ref->{count} = 999;
      }

      my $title = kin $ref->{title};
      $title =~ tr/:\\/：￥/;
      my $filename = "onsen";
      $filename .= kinf(" $title") if $title;
      $filename .= " $sharp" if $sharp;
      $filename .= " $date" if $date;
      $filename .= $& if $ref->{moviePath}{pc} =~ /\.mp3|\.mp4/i;
      $filename =  kinf $filename;
      $filename =~ tr/:\\/：￥/;
      my $filenamez = File::Spec->catfile($trn->{outpath},$filename);
      $filename     = File::Spec->catfile($tempdir       ,$filename);
      my $text = $ref->{schedule};
      next if -f e$filenamez; #################### mp3がすでにあるのでskip ##################
      ### say e$filenamez;

##########################################################
# mp3ダウンロード
#
      $self->{ind}->change("Busy", "onsen", "Download", "音泉 (".yoobi($i).") $title");

      my $uamp3 = LWP::UserAgent->new(
         "agent"   => $trn->{agent}  //"Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0",
         "timeout" => $trn->{timeout}//10,
      );

      for(0..3){
        my $resmp3 = $uamp3->get(
            $ref->{moviePath}{pc},
            ":content_file" => e$filename
         );
         last if $resmp3->is_success;
         sleep $wait;
      }

####################### mp3が無いのでskip ####################
      if(! -f e$filename){
         print $fh encode_utf8("!! skip $filename") if $trn->{logpath};
         next;
      }
##########################################################
# 絵
#
      $self->{ind}->change("Busy", "onsen", "Download", "音泉 アイコン ダウンロード");

      $ref->{thumbnailPath} =~ /\.[^.]{3,4}$/;

      my $piclocal = kinf(File::Spec->catfile($trn->{ini}//'banner',$title.$&));
      ### say e$piclocal;

#      if(!-f e$piclocal){
         my $picture = LWP::UserAgent->new(
            agent   => $trn->{agent}  //"Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0",
            timeout => $trn->{timeout}//10,
         );
         for(0..3){
            my $res = $picture->post(
               'http://www.onsen.ag/'.$ref->{thumbnailPath},
               ':content_file' => e$piclocal
            );
            last if $res->is_success;
            sleep $wait;
         }
         
#      }
      $self->{ind}->change("Busy", "onsen", "Download", "音泉 タグ追加");

##########################################################
# mp4
#


      if($ref->{moviePath}{pc} =~ /mp4$/i){
         my $tempfile = File::Spec->catfile($tempdir,"tttmmmppp.mp4");

         my $quiet = $trn->{logpath} ? quot(File::Spec->catfile($trn->{logpath},"Anko_ffmpeg_$title".(timedb time2hash time)->{tosec}.".log")) : " nul";
         my $cmd = "ffmpeg"
            .' -i '.quot($filename)
            .' -c:v copy'
            .' -c:a copy'
            .' -metadata   title='.quot($title.($sharp ? " $sharp":""))
            .' -metadata  artist='.quot($ref->{personality})
            .' -metadata   album='.quot($title)
            .' -metadata comment='.quot($text)
            .' -metadata   genre='.quot('Radio')
            .' -metadata    date='.quot($year)
            .' -metadata    year='.quot($year)
            .' -metadata   track='.quot($ref->{count})
            .' -y'
            .' '.quot($tempfile)
            ." 2>> $quiet"
            ;

         $quiet = $trn->{logpath} ? quot(File::Spec->catfile($trn->{logpath},"Anko_MP4Box_$title".(timedb time2hash time)->{tosec}.".log")) : " nul";
         my $box = "MP4Box"
            .' -dref'
            .' -info'
            .' -ipod'
            .' -tmp '.quot($tempdir)
            .' -itags cover='.quot($piclocal)
            .' '.quot($filename)
            ." 2>> $quiet"
            ;


         #print $fh $cmd."\n\n" if e$trn->{logpath};
         system e$cmd;

         unlink e($filename);
         move(e($tempfile), e($filename));

         #print $fh $box."\n\n" if e$trn->{logpath};
         system e$box;

      }else{
##########################################################
# mp3
#
         my $mp3 = MP3::Tag->new(e$filename);
         $mp3->get_tags();
         $mp3->{ID3v1}->remove_tag() if exists $mp3->{ID3v1};
         $mp3->{ID3v2}->remove_tag() if exists $mp3->{ID3v2};
         my $id3v2 = $mp3->new_tag("ID3v2");
         MP3::Tag->config("write_v24" => 1); # ID3v2.4 での書き込みを有効にする

         $id3v2->add_frame('TPE1', e($ref->{personality}));
         $id3v2->add_frame('TIT2', e($title.($sharp ? " $sharp":"")));
         $id3v2->add_frame('TALB', e($title));
         $id3v2->add_frame('TYER', $year);
         $id3v2->add_frame('TRCK', $ref->{count});
         $id3v2->add_frame('TCON', 'Radio');
         $id3v2->add_frame('COMM', 'JPN', e($text), e($text));
         my $pic;
         {
            open my $fh0, "<", e$piclocal;
            binmode $fh0;
            local $/ = undef;
            $pic = readline $fh0;
            close $fh0;
         }
         $id3v2->add_frame ( "APIC" , chr(0x0) , "image/jpeg" , chr(0x0) , "Cover Art" , $pic ) if $piclocal =~ /\.jpe?g$/i;
         $id3v2->add_frame ( "APIC" , chr(0x0) , "image/png"  , chr(0x0) , "Cover Art" , $pic ) if $piclocal =~ /\.png$/i;
         $id3v2->add_frame ( "APIC" , chr(0x0) , "image/gif"  , chr(0x0) , "Cover Art" , $pic ) if $piclocal =~ /\.gif$/i;
         $id3v2->write_tag;
      }
##########################################################
# owari
#
      $self->{ind}->change("PostPr", "onsen", "Download", "音泉 終了処理");

      for(0..15){
         last if move(e($filename),e($filenamez));
         sleep 1;
      }
   }
}
}
############################################################################################
############################################################################################
############################################################################################
############################################################################################
package Thamo4{
use strict;
use warnings;
use utf8; # ＵＴＦ－８
use Perl6::Say;
use Encode;
use File::Spec;
use File::Copy qw/move/;
use File::Basename;
use File::Temp qw/tempdir/;
use URI::Escape qw/uri_unescape/;
use LWP::UserAgent;
use JSON::Parse 'parse_json';
use HTTP::Headers;
use HTTP::Response;
use Data::Dumper::AutoEncode;
use lib '.';
use Shot3;


sub exam{
#  my $tempdir = d tempdir(CLEANUP => 1);
   my $dir =  File::Temp->newdir();
   my $tempdir = d $dir->dirname;
      $dir->unlink_on_destroy(1);

   local $Data::Dumper::Sortkeys = 1; # ハッシュのキーをソートする
   #local $Data::Dumper::Indent = 1; # インデントを縮める

   local $_;
#   local *STDOUT;
#   open STDOUT, '>', undef;

   my $w = shift//5;
   my $id = shift//5;
   my $trn = shift;
   my $self = shift;
   my $log = shift;

   my $stationid = "hibiki";

   my $ua = LWP::UserAgent->new;
   my $r  = HTTP::Request->new;

   $self->{ind}->change("Index", "hibiki", "Download", "響 番組表取得");

   $ua->agent($trn->{agent}//'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0');
   $ua->timeout($trn->{timeout}//"10");
   $ua->ssl_opts({verify_hostname => 0});

   $r->header('X-Requested-With' => 'XMLHttpRequest');
   $r->header('Origin' => 'http://hibiki-radio.jp/');
   $r->method('GET');

say lb"#####################################################################" if defined $log;
   $r->uri('https://vcms-api.hibiki-radio.jp/api/v1/programs');

   my $res;
   for my $ii(0..3){
      $res = $ua->request($r);
      last if $res->is_success;
   }

   if(!$res->is_success){
      return;
   }

   my $sample0 = parse_json(decode_utf8 $res->content);



   if(defined $log){
      open my $fh, ">", e(File::Spec->catfile($log,"sample0.JSON"));
      print $fh eDumper $sample0;
      close $fh;
   }

   nn:for( my $j = 0 ; defined $sample0->[$j]{access_id} ; $j++ ){

      next unless $w == $sample0->[$j]{day_of_week}; # 数字？
      my $day_of_week = "(".yoobi($w).")";
      my $access_id = $sample0->[$j]{access_id};

      $self->{ind}->change("Tx", "hibiki", "Download", "響 $day_of_week 番組情報要求");
say r"##################################################################### $access_id" if defined $log;
      $r->uri('https://vcms-api.hibiki-radio.jp/api/v1/programs/'.$access_id);

      for my $ii(0..3){
         $res = $ua->request($r);
         last if $res->is_success;
      }
      if(!$res->is_success){
         return;
      }

      my $sample1 = parse_json(decode_utf8 $res->content);
#     next unless defined $sample1->{latest_episode_id};

      if(defined $log){
         open my $fh, ">", e(File::Spec->catfile($log,"sample1_$access_id.JSON"));
         print $fh eDumper $sample1;
      }

      next unless defined $sample1->{access_id};
      next unless defined $sample1->{episode};
      next unless defined $sample1->{episode}{video};




      my $pname = $sample1->{episode}{program_name};
      my $name = $sample1->{episode}{name};
#     my $name = $sample1->{episode_name};

      $pname = kinf $pname;
      $pname =~ tr/:\\/：￥/;

      say e$pname if defined $log;

      my $cast         = $sample1->{cast};

      my $description  = $sample1->{description};
      $description  =~ s/\s+/ /g;
      $description  =~ s/\\+//g;
      $description  =~ s/"/\\"/g;

#     $sample1->{updated_at} =~ m|^(\d+)/(\d+)/(\d+)|;
     $sample1->{episode}{updated_at} =~ m|^(\d+)/(\d+)/(\d+)|;
#     $sample1->{episode_updated_at} =~ m|^(\d+)/(\d+)/(\d+)|;
#     $sample1->{publish_start_at} =~ m|^(\d+)/(\d+)/(\d+)|;
      my $episode_updated_at = sprintf("%4d年%02d月%02d日",$1,$2,$3); 

      my $year             = $1//"";
      my $pc_image_url     = $sample1->{pc_image_url}//"";

#     my $latest_episode_name = $sample1->{latest_episode_name}//"";
      my $latest_episode_name = $name//"";
      my $ttrack = "";
      ### $latest_episode_name = "" if $latest_episode_name =~ /次回|生放送/;
      $latest_episode_name =~ tr/[０１２３４５６７８９/0123456789/;
      $latest_episode_name =~ tr/[〇一二三四五六七八九/0123456789/;
      $latest_episode_name =~ tr/―ーｰ/---/;
      if($latest_episode_name =~ /[\d\-]+/){
         $latest_episode_name = $&;
         if($latest_episode_name =~ /-/){
            $latest_episode_name = "";
            $ttrack = "#".$latest_episode_name;
         }else{
            $latest_episode_name = $latest_episode_name;
            $ttrack = "#".sprintf("%03d",$latest_episode_name);
         }
      }else{
         $latest_episode_name = $name;
         $ttrack = "";
      }

      $self->{ind}->change("Tx", "hibiki", "Download", "響 $day_of_week プレイリスト要求");

say ll"#####################################################################" if defined $log;


      my $filename  = "hibiki $pname $ttrack $episode_updated_at.m4a";
      my $filenamez = File::Spec->catfile($trn->{outpath}//".", $filename);
         $filename  = File::Spec->catfile($tempdir           , $filename);
      next if -f e$filenamez;

      my $video_id = $sample1->{episode}{video}{id};
      ## $video_id //= $sample1->{episode}{episode_parts}{id};
      next unless $video_id;

      $r->uri("https://vcms-api.hibiki-radio.jp/api/v1/videos/play_check?video_id=$video_id");


      for my $ii(0..3){
         $res = $ua->request($r);
         last if $res->is_success;
      }

      if(!$res->is_success){
         return;
      }

      #print decode_utf8 $res->content;


      my $sample2 = parse_json(decode_utf8 $res->content);
      if(defined $log){
         open my $fh, ">", e(File::Spec->catfile($log,"sample2_$access_id.JSON"));
         print $fh eDumper $sample2;
      }


      my $token        = $sample2->{token};
      my $playlist_url = $sample2->{playlist_url};
      next unless $playlist_url;

      $self->{ind}->change("Busy", "hibiki", "Download", "響 $day_of_week $pname");

      my $cmd = $trn->{ffmpeg}
         ." -i \"$playlist_url\""
         ." -vn"
         ." -acodec copy"
         ." -bsf:a aac_adtstoasc"
         ." -metadata   title=\"$pname".($ttrack?" $ttrack":"")."\""
         ." -metadata  artist=\"$cast\""
         ." -metadata   album=\"$pname\""
         ." -metadata comment=\"$description\""
         ." -metadata   genre=\"Radio\""
         ." -metadata    year=\"$year\""
         ." -metadata    date=\"$year\""
         ." -metadata   track=\"$latest_episode_name\""
         ." \"$filename\""
         ." 2> nul"
         ;
      system e$cmd;

      my $lwp = LWP::UserAgent->new(
         agent   => $trn->{agent}  // "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)",
         timeout => $trn->{timeout}// "10",
      );

      $pc_image_url =~ /(\.[^.]+)$/;
      my $imgfile = File::Spec->catfile("banner", $pname.$1);
      #$res = $lwp->get($pc_image_url, ':content_file' => e$imgfile) if ! -f e$imgfile;
      $res = $lwp->get($pc_image_url, ':content_file' => e$imgfile);

      next if ! -f e$imgfile;
      next if ! -f e$filename;

      $self->{ind}->change("MP4Box", "hibiki", "Download", "響 $day_of_week タイトル画像結合");

      my $box = $trn->{mp4box}
         ." -dref"
         ." -info"
         ." -ipod"
         ." -tmp ".quot($tempdir)
         ." -itags cover=\"".$imgfile."\""
         ." \"$filename\""
         ." 2> nul"
         ;

      system e$box;
      move(e($filename),e($filenamez));

   }
}
}
