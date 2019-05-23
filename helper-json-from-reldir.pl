#!/usr/bin/env perl

use Modern::Perl;
use DateTime;
use Crypt::Digest 'digest_file_hex';
use File::Slurper 'read_text';
use File::Glob 'bsd_glob';
use File::Spec::Functions 'canonpath';
use File::Basename 'basename';
use Cpanel::JSON::XS;

die "Usage:\n  $0 c:\\strawberry_build\\output\n" unless @ARGV;

my %out;

for my $dir (@ARGV) {
  die "non-existing dir '$dir'" unless -d $dir;
  for my $file (bsd_glob("$dir/*.zip"), bsd_glob("$dir/*.msi")) {
    $file = canonpath($file) =~ s|\\|/|gr;
    my $basename = basename($file);
    if ($file =~ m!/strawberry-perl(-ld|-no64)?-(5\.\d+\.\d+\.\d+)-(32bit|64bit)(-PDL|-portable)?\.(zip|msi)!) {
      my $arch = $1 // '';
      my $ver  = $2;
      my $bits = $3;
      my $edit = $4 // '';
      my $extension = $5;

      warn "processing: $file\n";
      my $archname = "MSWin32-".($bits eq '32bit' ? 'x86' : 'x64')."-multi-thread";
      $archname .= "-64int" if $arch ne '-no64' && $bits eq '32bit';
      $archname .= "-ld" if $arch eq '-ld';
      my $edition = $extension;
      $edition = "pdl" if $edit eq '-PDL';
      $edition = "portable" if $edit eq '-portable';

      my $modtime = (stat($file))[9];
      my $dt = DateTime->from_epoch(epoch => $modtime, time_zone => "local");
      my $date = $dt->ymd;
      my $name = $dt->strftime("%B %Y") . " / $ver / $bits";
      $name .= " / without USE_64_BIT_INT" if $arch eq '-no64' && $bits eq '32bit';
      $name .= " / with USE_64_BIT_INT" if $arch ne '-no64' && $bits eq '32bit';
      $name .= " / with USE_LONG_DOUBLE" if $arch eq '-ld';
      my @n = split /\./, $ver;
      my $numver = 0 + sprintf("%s.%09d", $n[0], $n[1]*1000000 +$n[2]*1000 + $n[3]); # must be a number not a string
      my $relnotes = "http://strawberryperl.com/release-notes/$ver-$bits.html",

      my %map = (
        "MSWin32-x64-multi-thread"       => "1009",
        "MSWin32-x86-multi-thread-64int" => "1008",
        "MSWin32-x86-multi-thread"       => "1007",
        "MSWin32-x64-multi-thread-ld"    => "1006",
      );
      my $key = "$numver-".($map{$archname} // "1000$archname");

      $out{$key}{archname} = $archname;
      $out{$key}{date} = $date;
      $out{$key}{name} = $name;
      $out{$key}{numver} = $numver;
      $out{$key}{relnotes} = $relnotes if $extension eq 'msi';
      $out{$key}{version} = $ver;
      $out{$key}{edition}{$edition} = {
         "sha1"   => digest_file_hex("SHA1", $file),
         "sha256" => digest_file_hex("SHA256", $file),
         "size"   => -s $file,
         "url"    => "http://strawberryperl.com/download/$ver/$basename",
      };
    }
    else {
      warn "SKIPPING: $file\n";
    }
  }
}

my @final = map { $out{$_} } reverse sort keys %out;
say Cpanel::JSON::XS->new->canonical->pretty->encode(\@final);
