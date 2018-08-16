#line 1 "Shot3.pm"
package Shot3{
#use 5.020002;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

use utf8;
use Encode;
use File::Spec;
use Time::Local;
use Term::ReadKey qw/ReadKey/;
use Data::Dumper::AutoEncode;


sub chomper{
   my $tmp = $#_ == 0 ?  \shift : \$_;
   return $$tmp unless defined $$tmp;
   $$tmp =~ s/[\n\r]*$//;
   return $$tmp
}

sub chompel{
   my $tmp = $#_ == 0 ?  \shift : \$_;
   return "" unless defined $$tmp;
   $$tmp =~ s/[\n\r]*$//;
   return $$tmp
}

sub shukutai{
   my $a = $#_ == 0 ? shift : $_;
   return $a unless defined $a;
   $a =~ s/^\x{20}+//;
   $a =~ s/\x{20}+$//;
   return $a;
}

sub shukutai2{
   my $a = shukutai @_;
   return $a unless defined $a;
   $a =~ s/\x{20}{2,}/\x{20}/g;
   return $a;
}

sub shukutai3($){
   local $/ = undef;
   my $tmp = shift;
   $tmp =~ s/\s+/ /g;
   return $tmp;
}



sub kin($){
      my $tmp = shift;
      return "" unless defined $tmp && $tmp;
      $tmp =~ tr!♡♥💝❤〜−!▽▼▼▼～-!; # りえしょん対応 # みったん対応
      $tmp = d(e($tmp));
      $tmp =~ s/\?/？/g;
      return $tmp;
}

sub kinf($){
   my ( $tmp ) = @_;
      $tmp =~ tr!\/\?\:\*\"\>\<\|!／？：＊”＞＜｜!;
   return $tmp;
}

sub king($){
   my ($tmp) = @_;
   $tmp =~ tr/"/\"/;
   return $tmp;
}


sub tranc($$){
   my $cchr;
   {
      use bytes;
      $cchr = length $_[0];
   }
   while($cchr > $_[1]){
      $_[0] =~ s/.$//;
      {
         use bytes;
         $cchr = length $_[0];
      }
   }
   return $_[0];
}





sub yoobi{
   my @w = ('日','月','火','水','木','金','土');
   return $w[$_[0]];
}
sub now{
   $_[0] =~ /(\d)_(\d\d):(\d\d)/;
   return yoobi($1)."曜日$2時$3分";
}
sub now2{
   $_[0] =~ /(\d)_(\d\d):(\d\d)/;
   return "(".yoobi($1).")$2時$3分";
}


my $encoz;

BEGIN{
   if($^O =~ /^MSWin32$/i){
      require Win32::Console::ANSI;
      $encoz = find_encoding('cp932');
      $Data::Dumper::AutoEncode::ENCODING = 'CP932';
   }else{
      $encoz = find_encoding('utf8');
   }
#   print "$^O\n";

}


sub nssn{
   my $a =  $_[0];
   $a =~ s/^[\s012]?\d$/00/ and return $a;
   $a =~ s/^[345]\d$/30/ and return $a;
   $a =~ s/^[678]\d$/60/ and return $a;
   die "Chi Ga U !!\n";
}

#no warnings 'redefine';
#sub e{$encoz->encode($_[0]//"")}
#sub d{$encoz->decode($_[0]//"")}
sub e{encode("cp932",$_[0]//"")}
sub d{decode("cp932",$_[0]//"")}
sub Enc{Encode::encode_utf8($_[0]//$_)}
sub Dec{Encode::decode_utf8($_[0]//$_)}


#sub  g{shift} # Green
#sub  c{shift} # Cyan
#sub  w{shift} # Gray
#sub  r{shift} # Red
#sub lg{shift} # Green
#sub ll{shift} # Yellow
#sub lb{shift} # Blue
#sub lm{shift} # Magenta
#sub llc{shift} # Cyan
#sub lw{shift} # White




sub  g{"\e[0;32m".e($_[0])."\e[0m"} # Green
sub  c{"\e[0;36m".e($_[0])."\e[0m"} # Cyan
sub  w{"\e[1;30m".e($_[0])."\e[0m"} # Gray
sub  r{"\e[1;31m".e($_[0])."\e[0m"} # Red
sub lg{"\e[1;32m".e($_[0])."\e[0m"} # Green
sub ll{"\e[1;33m".e($_[0])."\e[0m"} # Yellow
sub lb{"\e[1;34m".e($_[0])."\e[0m"} # Blue
sub lm{"\e[1;35m".e($_[0])."\e[0m"} # Magenta
sub llc{"\e[1;36m".e($_[0])."\e[0m"} # Cyan
sub lw{"\e[1;37m".e($_[0])."\e[0m"} # White






sub bp{
   local $Data::Dumper::AutoEncode::ENCODING = 'CP932';
   local $Data::Dumper::Sortkeys = 1; # ハッシュのキーをソートする
   local $Data::Dumper::Indent   = 1; # インデントを縮める
   print eDumper @_;
   local $| = 1;
   print "\n\*";
   while(1){
      print "\e[1D+";
      last if defined ReadKey -1;
###   sleep 0.5;
      select (undef,undef,undef, 0.5);
      print "\e[1D\*";
      last if defined ReadKey -1;
###   sleep 0.5;
      select (undef,undef,undef, 0.5);
   }
   $_[0];
}

sub mkfile{
   my $i0 = $_[0] // "undef";
   my $i1 = $_[1] // 10000;
   my $i2 = $_[2] // "f";
   if(defined $i2 && $i2 eq "d"){
      mkdir e $i0;
   }else{
      open(my $fh, '>', e$i0) or die e$!;
      print $fh e "only4tests";
      close $fh;
   }
   utime(time - $i1, time - $i1, e$i0) or print "$!\n";
   return -e e$i0
}

sub locald{
   my $joined = shift;
   my @split;
   if($joined =~ /^(\d+)[^\d]+(\d+)[^\d]+(\d+)[^\d]+(\d+)[^\d]+(\d+)[^\d]+(\d+)$/){
      @split = ($1, $2, $3, $4, $5, $6);
   }elsif($joined =~ /^(\d\d\d\d)-(\d\d)-(\d\d)\s+(\d\d):(\d\d):(\d\d)$/){
      @split = ($1, $2, $3, $4, $5, $6);
   }elsif($joined =~ /^(\d\d\d\d)\D+(\d\d)\D+(\d\d)\D+(\d\d)\D+(\d\d)\D+(\d\d)$/){
      @split = ($1, $2, $3, $4, $5, $6);
   }elsif($joined =~ /^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)$/){
      @split = ($1, $2, $3, $4, $5, $6);
   }elsif($joined =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/){
      @split = ($1, $2, $3, $4, $5, $6);
   }elsif(@split = split /,/, $joined,6){
      ### print e"切れてない." unless $#split == 5;
   }
   $split[1] --;
   $split[0] -= 1900 if $split[0] >= 1900;

   eval{timelocal($split[5], $split[4], $split[3], $split[2], $split[1], $split[0])};
###return "00000000000000" if $@;
   return undef if $@;

   return timelocal($split[5], $split[4], $split[3], $split[2], $split[1], $split[0]);
}

sub time2hash{
   my %a;
   my @w = ('日','月','火','水','木','金','土');
   return {} unless defined $_[0];
   ($a{sec}, $a{min}, $a{hour}, $a{mday}, $a{mon}, $a{year}, $a{wday}, $a{yday}, $a{isdst}) = localtime $_[0];
   $a{year} += 1900;
   $a{mon} ++;
   $a{yoobi} = $w[$a{wday}];
   return \%a;
}

sub timedb{
   my %q;
   $q{line}       = "test";
   $q{tosec}      = sprintf("%04d年%02d月%02d日(%s)%02d時%02d分%02d秒", $_[0]->{year}, $_[0]->{mon}, $_[0]->{mday}, $_[0]->{yoobi}, $_[0]->{hour}, $_[0]->{min}, $_[0]->{sec});
   $q{tomin}      = sprintf("%04d年%02d月%02d日(%s)%02d時%02d分"      , $_[0]->{year}, $_[0]->{mon}, $_[0]->{mday}, $_[0]->{yoobi}, $_[0]->{hour}, $_[0]->{min});
   $q{today}      = sprintf("%04d年%02d月%02d日"                      , $_[0]->{year}, $_[0]->{mon}, $_[0]->{mday});
   $q{today2}     = sprintf("%04d-%02d-%02d"                          , $_[0]->{year}, $_[0]->{mon}, $_[0]->{mday});
   $q{toyear}     = sprintf("%04d"                                    , $_[0]->{year});
   $q{chksprintf} = sprintf(                      "%02d時%02d分%02d秒",                                                             $_[0]->{hour}, $_[0]->{min}, $_[0]->{sec});
   $q{line}       = sprintf("%1d_%02d:%02d"                           , $_[0]->{wday}, $_[0]->{hour}, nssn($_[0]->{min}));
   $q{ftimef}     = sprintf("%04d,%02d,%02d,%02d,%02d,%02d"           , $_[0]->{year}, $_[0]->{mon}, $_[0]->{mday},                 $_[0]->{hour}, $_[0]->{min}, $_[0]->{sec});
   $q{radiko}     = sprintf("%04d%02d%02d%02d%02d%02d"                , $_[0]->{year}, $_[0]->{mon}, $_[0]->{mday},                 $_[0]->{hour}, $_[0]->{min}, $_[0]->{sec});
   $q{anko}       = sprintf("%04d年%02d月%02d日(%s)"                  , $_[0]->{year}, $_[0]->{mon}, $_[0]->{mday}, $_[0]->{yoobi});
   return \%q;
}


sub track($){
   my $eve = shift;
   my $styear = (time2hash $eve)->{year};
   my $gantan = locald "$styear,01,01,00,00,00";
   $styear =~ s/^\d\d//;
   return sprintf("%02d%02d", $styear, int(($eve - $gantan) / (3600 * 24 * 7)));
}


sub pathxo{
   my $p = {};
   $p = shift;
   for(my $x=0; defined $p->{'path'}[$x]; $x++){
      for(my $y=0; defined $p->{path}[$y]; $y++){
         next if $x == $y;
         my $tmp = File::Spec->catfile($p->{path}[$x], $p->{path}[$y], $p->{file});
         return $tmp if -f e $tmp;
      }
   }
   return undef;
}

sub pathxp{
   print "0 pass\n";
   return undef unless defined $_[1] && $_[1] ne '';
   print "1 pass\n";
   return $_[1] if File::Spec->file_name_is_absolute($_[1]) && -d $_[1];
   print "2 pass\n";
   return File::Spec->rel2abs(File::Spec->catdir($_[0], $_[1])) if -d File::Spec->catdir($_[0], $_[1]);
   print "3 pass\n";
   return undef;
}



my $QTY;

sub quot{
   $QTY = q/"/;
   _quotcore(@_);
}
sub quots{
   $QTY = q/'/;
   _quotcore(@_);
}
sub _quotcore{
   my $i;
   my @a;
   my $h;
   if($#_ == 0){
      if(ref($_[0]) eq 'ARRAY'){
         for($i=0; $i<=$#{$_[0]}; $i++){
            $h->[$i] = "$QTY$_[0]->[$i]$QTY";
         }
         $h;
      }else{
         "$QTY$_[0]$QTY";
      }
   }elsif($#_ != -1){
      for($i=0; $i<=$#_; $i++){
         $a[$i] = "$QTY$_[$i]$QTY";
      }
      @a;
   }elsif(ref($_) eq 'ARRAY'){
      for($i=0; $i<=$#$_; $i++){
         $_->[$i] = "$QTY$_->[$i]$QTY";
      }
      $_;
   }else{
      $_ = "$QTY$_$QTY";
   }
}


sub statok{
   $a = shift // $_;
   $b = shift // 10000;
   return undef unless -e $a;
   (stat $a)[9] + $b <= time;
}



our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
   chomper
   chompel
   shukutai
   shukutai2
   shukutai3
   kin
   kinf
   king
   yoobi
   yoobi2
   now
   now2
   bp
   e
   d
   Enc
   Dec
   g
   c
   w
   r
   lg
   ll
   lb
   lm
   llc
   lw
   tranc
   nssn
   quot
   quots
   statok
   pathxo
   defer
   makefile
   locald
   time2hash
   timedb
   track
);
}

1;
