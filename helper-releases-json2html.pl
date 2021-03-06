#!/usr/bin/env perl

use Modern::Perl;
use FindBin;
use File::Slurper qw(read_text write_text);
use File::Basename qw(basename);
use Cpanel::JSON::XS;
use Mojo::Template;

sub json_load_and_sort {
  my ($filename) = @_;
  my $rel = Cpanel::JSON::XS->new->decode(read_text($filename));
  my %map = (
      "MSWin32-x64-multi-thread"       => "9",
      "MSWin32-x86-multi-thread-64int" => "8",
      "MSWin32-x86-multi-thread"       => "7",
      "MSWin32-x64-multi-thread-ld"    => "6",
  );
  $rel = [ reverse sort {
             $a->{date}."-".sprintf("%f.9", $a->{numver})."-".$map{$a->{archname}//"1$a->{archname}"}
             cmp
             $b->{date}."-".sprintf("%f.9", $b->{numver})."-".$map{$b->{archname}//"1$b->{archname}"}
           } @$rel ];
  return $rel;
}

sub json_check {
  my ($rel) = @_;
  die "no ARRAY ref" unless ref $rel eq 'ARRAY';
  for my $r (@$rel) {
    die "invalid name"     unless $r->{name};
    die "invalid archname" unless $r->{archname} =~ /^MSWin32-.+/;
    die "invalid date"     unless $r->{date}     =~ /^2\d\d\d-\d\d-\d\d$/;
    die "invalid relnotes" unless !$r->{relnotes} || $r->{relnotes} =~ m!^https?://strawberryperl\.com/release-notes/5\..+\.html$!;
    die "invalid numver"   unless $r->{numver} > 5.008 && $r->{numver} < 6;
    die "invalid version"  unless $r->{version}  =~ /^5\.\d+\.\d+\.\d+$/;
    die "no edition"       unless keys %{$r->{edition}} > 0;
    die "invalid edition"  unless 0 == grep { $_ !~ /^(msi|zip|pdl|portable)$/} keys %{$r->{edition}};
    for my $e (keys %{$r->{edition}}) {
      die "invalid url [$e]"    unless $r->{edition}{$e}{url} =~ m!^https?://strawberryperl\.com/download/5\..+?/strawberry-perl-.+(zip|msi)$!;
      die "invalid sha1 [$e]"   unless $r->{edition}{$e}{sha1} =~ /^[0-9a-f]{40}/i;
      die "invalid sha256 [$e]" unless $r->{edition}{$e}{sha256} =~ /^[0-9a-f]{64}/i;
    }
  }
}

sub json_to_html {
  my ($rel, $filename) = @_;
  my $ep = do { local $/ = undef; <DATA> };
  my $out = Mojo::Template->new->vars(1)->render($ep, { releases => $rel });
  write_text($filename, $out);
}

sub json_to_json {
  my ($rel, $filename) = @_;
  write_text($filename, Cpanel::JSON::XS->new->canonical->pretty->encode($rel));
}

my $rel = json_load_and_sort("$FindBin::Bin/releases.json");
json_check($rel);
json_to_json($rel, "$FindBin::Bin/releases.json"); # save sorted releases.json
json_to_html($rel, "$FindBin::Bin/releases.html"); # save releases.html

__DATA__
<!DOCTYPE html>
<!-- !!! THIS FILE IS GENERATED FROM releases.json - DO NOT EDIT THIS FILE !!! -->
<html lang="en">
<head>
<meta charset="utf-8">

<title>Strawberry Perl for Windows - Releases</title>

<link rel="shortcut icon" type="image/vnd.microsoft.icon" href="favicon.ico">
<link rel="stylesheet" type="text/css" href="main.css">

<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  ga('create', 'UA-37040168-1', 'strawberryperl.com');
  ga('require', 'displayfeatures');
  ga('require', 'linkid', 'linkid.js');
  ga('set', 'anonymizeIp', true);
  ga('send', 'pageview');
</script>
</head>
<body>

<img src="images/320554_9491.jpg" alt="strawberries" width="357" height="728" border="0" align="right">
<table border="0" cellspacing="0" cellpadding="0">
  <tr>
    <td>

      <h1>Strawberry Perl Releases</h1>
      <a href="/">back to homepage</a>

      <h2>Explanatory Notes</h2>
      <ul>
        <li><b>MSI installer</b> = preferred way, requires admin privileges to install</li>
        <li><b>ZIP edition</b> = admin privileges not required, however you need to run some post-install scripts manually after unzip</li>
        <li><b>Portable edition</b> = suitable for "perl on USB stick" (you can move/rename the perl directory and it will still work)</li>
        <li><b>PDL edition</b> = portable edition + extra <a href="http://pdl.perl.org/">PDL</a> related modules and external libraries</li>
      </ul>

% my %seen;
% my %tmp;
% for my $r (@$releases) {
%   my $id = sprintf("%s-%.9f", $r->{date}, $r->{numver});
%   my $bit = $r->{archname} =~ /x86/ ? '32bit' : '64bit';
%   my $v = sprintf("%s-%s", "$r->{numver}" =~ s/^(5\.\d\d\d).*$/$1/r, $r->{archname});
%   if ($r->{edition}{msi} && !$seen{$v} && $r->{numver} > 5.014) {
%     for my $e (keys %{$r->{edition}}) {
%       $tmp{$id}{$e}{$bit} = $r->{edition}{$e}{url};
%     }
%     $tmp{$id}{version} = $r->{version};
%     $tmp{$id}{date} = $r->{date};
%   }
%   $seen{$v}++;
% }
% my @summary = reverse sort { $a->{version} cmp $b->{version} } map { $tmp{$_} } (keys %tmp);

      <p>&nbsp;</p>
      <h2>Recommended downloads</h2>
      <table class="file" width="100%" border="0" cellpadding="3" cellspacing="0">
        <tr>
          <td><b>Version</b></td>
          <td><b>Date</b></td>
          <td><b>MSI edition</b></td>
          <td><b>Portable</b></td>
          <td><b>PDL edition</b></td>
          <td><b>ZIP edition</b></td>
        </tr>
% for my $s (@summary) {
        <tr>
          <td><b><%=$s->{version}%></b></td>
          <td><%=$s->{date}%></td>
          <td>
%  if ($s->{msi}) {
%    if ($s->{msi}{'32bit'} && $s->{msi}{'64bit'}) {
            <a href="<%=$s->{msi}{'32bit'}%>">32bit</a>/<a href="<%=$s->{msi}{'64bit'}%>">64bit</a>
%    } elsif ($s->{msi}{'32bit'}) {
            <a href="<%=$s->{msi}{'32bit'}%>">32bit</a>
%    }
%  }
          </td>
          <td>
%  if ($s->{portable}) {
%    if ($s->{portable}{'32bit'} && $s->{portable}{'64bit'}) {
            <a href="<%=$s->{portable}{'32bit'}%>">32bit</a>/<a href="<%=$s->{portable}{'64bit'}%>">64bit</a>
%    } elsif ($s->{portable}{'32bit'}) {
            <a href="<%=$s->{portable}{'32bit'}%>">32bit</a>
%    }
%  }
          </td>
          <td>
%  if ($s->{pdl}) {
%    if ($s->{pdl}{'32bit'} && $s->{pdl}{'64bit'}) {
            <a href="<%=$s->{pdl}{'32bit'}%>">32bit</a>/<a href="<%=$s->{pdl}{'64bit'}%>">64bit</a>
%    } elsif ($s->{pdl}{'32bit'}) {
            <a href="<%=$s->{pdl}{'32bit'}%>">32bit</a>
%    }
%  }
          </td>
          <td>
%  if ($s->{zip}) {
%    if ($s->{zip}{'32bit'} && $s->{zip}{'64bit'}) {
            <a href="<%=$s->{zip}{'32bit'}%>">32bit</a>/<a href="<%=$s->{zip}{'64bit'}%>">64bit</a>
%    } elsif ($s->{zip}{'32bit'}) {
            <a href="<%=$s->{zip}{'32bit'}%>">32bit</a>
%    }
%  }
          </td>
        </tr>
% }
      </table>


% my %emap = ( msi => "MSI installer", zip => "ZIP edition", portable => "Portable edition", pdl => "PDL edition" );
% my $lastver = '0';

% for my $rel (@$releases) {
%   if ($lastver ne $rel->{version}) {
%     $lastver = $rel->{version};
      <p>&nbsp;</p>
      <h2>Strawberry Perl <%=$rel->{version}%> (<%=$rel->{date}%>)</h2>
% }
% if ($rel->{relnotes}) {
      <ul><li><%=$rel->{name}%> - <a href="<%=$rel->{relnotes}%>">Release Notes</a></li></ul>
% } else {
      <ul><li><%=$rel->{name}%></li></ul>
% }
      <table class="file" width="100%" border="0" cellpadding="3" cellspacing="0">
        <tr><td align="left"><b>Download</b></td><td align="right"><b>SHA1 Digest</b></td><td align="right"><b>Size</b></td></tr>
% for my $edi (sort keys %{$rel->{edition}}) {
%   my $basename = $rel->{edition}{$edi}{url} =~ s|^.*/strawberry-perl-([^/]+)$|$1|r;
%   my $longname = $emap{$edi} // die "NOT FOUND";
%   my $mbsize = sprintf("%.1f", $rel->{edition}{$edi}{size}/1000000);
        <tr>
          <td align="left"><a href="<%=$rel->{edition}{$edi}{url}%>" onclick="ga('send', 'event', 'Release', 'Download', '<%=$basename%>');"><%=$longname%></a></td>
          <td align="right"><%=$rel->{edition}{$edi}{sha1}%></td><td align="right"><%=$mbsize%>&nbsp;MB</td>
        </tr>
% }
      </table>
% }
    </td>
  </tr>
</table>

</body>
</html>
