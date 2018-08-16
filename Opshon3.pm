package Opshon3{
use strict;
use warnings;
use utf8; # ＵＴＦ－８
use File::Copy qw/move/;
use lib '.';
use Shot3;



my $trn;

sub new{
   my $self = shift;
   $trn = \shift;
   bless $trn, ref $self || $self;
}

sub cmdlopt{
   my $self = shift;
   my $tmp = "";
   for my $line (@ARGV){
      $line =~ s/[\r\n]+$//;
      if($tmp =~ s/^-(\D)/$1/){
         if($line =~ /^-\D/){
            $$trn->{$line} = 1;
            $tmp = $line;
         }else{
            $$trn->{lc $tmp} = $line;
            $tmp = '';
         }
      }else{
         $tmp = $line;
      }
   }
   $$trn->{lc $tmp} = 1 if $tmp =~ s/^-(\D)/$1/;
}


sub readconfig{
   my $self = \shift;
   open my $fh, "<:utf8", "AnGe4u.ini" or return "";
   my $active = "";
   for my $line (readline $fh){
      $line =~ s/[\r\n]+$//;
      $line =~ s/;.*$//;
      $line = shukutai $line;
      next if $line eq '';
      if($line =~ /\[(\w+)\]/){
         $active = lc($1) eq "config";
      }elsif($active){
         if($line =~ /^(\S*)\s*=\s*(\S*)/){
            $$trn->{lc($1)} = $2;
         }
      }
   }
}

sub cfgop{
   my $self = shift;
   my $key = shift;
   my $arg = shift;
   my $end = "";
   my $dst = "";
   move("ange4u.ini","__ange4u.ini__")     or return "";
   open my $fi, "<:utf8", "__ange4u.ini__" or return "";
   open my $fo, ">:utf8", "ange4u.ini"     or return "";
   my $active = "";
   for my $line (readline $fi){
      $line =~ s/[\r\n]*$//;
      next if $line eq '';
      if($line =~ /\[(\w+)\]/){
         $active = lc($1) eq "config";
         $dst .= "$line\n";
      }elsif($active){
         if($line =~ /([^\s=]+)(\s*=\s*)/i && !$end){
            #print e"[$1][$2]\n";
            my $tmp1 = $1;
            my $tmp2 = $2;
            if((lc($key) eq lc($tmp1)) && !$end){
               my $tmp = "$key$2$arg";
               $end = "■設定変更■+- $tmp\n";
               $$trn->{lc($key)} = $arg;
               $dst .= "$tmp\n";
            }else{
               $dst .= "$line\n";
            }
         }else{
            $dst .= "$line\n";
         }
      }else{
         $dst .= "$line\n";
      }
   }
   if(!$end){
      $dst .= "$key = $arg\n";
      $end = "■設定変更■\n+- $key = $arg\n";
   }

   print $fo $dst;
   close $fi;
   close $fo;
   undef $fi;
   undef $fo;
   unlink ("__ange4u.ini__");
   $end;
}
}
1;