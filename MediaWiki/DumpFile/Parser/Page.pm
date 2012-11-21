package MediaWiki::DumpFile::Parser::Page;

use strict;
use warnings;
use utf8;
use base 'MediaWiki::DumpFile::Pages::Page';
use constant MAX => 0x7FFFFFF;

sub new {
  my $class = shift @_;
  my $self = shift @_;
  return bless($self, $class);
}

sub text($) {
  my $self = shift @_;
  return $self->{text} if defined($self->{text});
  my @revisions = $self->revision;
  $self->{text} = $revisions[-1]->text;
  return $self->{text};
}

sub templates($) {
  my $self = shift @_;
  return @$self->{templates} if defined($self->{templates});
  my @templates = $self->__extract_contents("{{", "}}");
  $self->{templates} = \@templates;
  return @templates;
}

sub links($) {
  my $self = shift @_;
  return @$self->{links} if defined($self->{links});
  my @links = $self->__extract_contents("[[", "]]");
  $self->{links} = \@links;
  return @links;
}

sub __extract_contents($@) {
  my $self = shift @_;
  my @sign = @_;
  my @len = map { length $_ } @sign;
  my @pos;
  my $text = $self->text;
  my @positions;
  my $offset = 0;
  my $nest = 0;
  do {
    $pos[0] = index($text, $sign[0], $offset); $pos[0] = MAX if $pos[0] == -1;
    $pos[1] = index($text, $sign[1], $offset); $pos[1] = MAX if $pos[1] == -1;
    #print "**** $pos[0], $pos[1]\n";
    if ($pos[0] < $pos[1]) {
      $offset = $pos[0] + $len[0];
      push(@positions, "$sign[0],$nest,$pos[0]");
      ++$nest;
    }
    else {
      --$nest;
      $offset = $pos[1] + $len[1];
      push(@positions, "$sign[1],$nest,$pos[1]");
    }
  } while ($pos[0] != MAX && $pos[1] != MAX);
  #print "---> " . join("\n---> " => @pairs) . "\n";

  my $N = scalar(@positions);
  my @contents;
  my $k = 0;
  do {
    $k = __tie_contents(\@contents, $text, $k, $N, $sign[0], $sign[1], @positions);
  } while ($k != -1);
  return @contents;
}

sub __tie_contents($$$$$$@) {
  my ($ref_contents, $text, $k, $N, $S1, $S2, @positions) = @_;
  for (my $i = $k; $i < $N; ++$i) {
    my($sign1, $nest1, $pos1) = split(',', $positions[$i]);
    next if ($sign1 ne $S1);
    for (my $j = $i + 1; $j < $N; ++$j) {
      my($sign2, $nest2, $pos2) = split(',', $positions[$j]);
      next if ($sign2 ne $S2 || $nest1 != $nest2);
      my $content = substr($text, $pos1, $pos2 - $pos1 + 2);
      #print ">>>> $template\n";
      push(@$ref_contents, $content);
      return $i + 1;
    }
  }
  return -1;
}

sub parse_links($) {
  my ($text) = @_;
  $text =~ s/\[\[(?:ファイル|File):[^\[\]]+\]\]//g;
  $text =~ s/\[\[[^\|\[\]]+\|([^\[\]]+)\]\]/$1/g;
  $text =~ s/\[\[([^\[\]]+)\]\]/$1/g;
  $text =~ s|\[http://\S+ (\S+?)\]|$1|g;
  return $text;
}

sub location($) {
  my $self = shift;
  my ($lat, $lng) = (9999, 9999);
  for (@$self->templates) {
    $_ = parse_links($_);
    if (m/^{{(?:ウィキ座標.*?|[Cc]oord|[Cc]oor\s+(?:title\s+)?dms)\|(\d+)\|(\d+)\|([\d\.]+)\|([NS])\|(\d+)\|(\d+)\|([\d\.]+)\|([EW])\|.*}}$/s) {
      $lat = $1 + ($2 / 60) + ($3 / 3600); $lat = -$lat if $4 eq 'S';
      $lng = $5 + ($6 / 60) + ($7 / 3600); $lng = -$lng if $8 eq 'W';
      last;
    }
    if (m/^{{日本の位置情報\|(\d+)\|(\d+)\|([\d\.]+)\|(\d+)\|(\d+)\|([\d\.]+)\|.*}}$/s) {
      $lat = $1 + ($2 / 60) + ($3 / 3600);
      $lng = $4 + ($5 / 60) + ($6 / 3600);
      last;
    }
    if (m/^{{(?:[Cc]oord|Mapplot)\|(-?\d+\.\d+)\|(-?\d+\.\d+)\|.*}}$/s) {
      $lat = $1;
      $lng = $2;
      last;
    }
    if (m/^{{[Cc]oord\|(-?\d+\.\d+)\|[NS]\|(-?\d+\.\d+)\|[EW]\|.*}}$/s) {
      $lat = $1; $lat = -$lat if $2 eq 'S';
      $lng = $3; $lng = -$lng if $4 eq 'S';
      last;
    }
    if (m/^{{[Cc]oord\|(\d+)\|(\d+\.?\d*)\|([NS])\|(\d+)\|(\d+\.?\d*)\|([EW])\|.*}}$/s) {
      $lat = $1 + ($2 / 60); $lat = -$lat if $3 eq 'S';
      $lng = $4 + ($5 / 60); $lng = -$lng if $6 eq 'W';
      last;
    }
    next unless m/(?:緯度度|lat_deg|latd)\s*=\s*(-?\d+)/s;
    my $lat_deg = $1;
    next unless m/(?:経度度|lon_deg|longd)\s*=\s*(-?\d+)/s;
    my $lng_deg = $1;
    my $lat_min = (m/(?:緯度分|lat_min|latm)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lng_min = (m/(?:経度分|lon_min|longm)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lat_sec = (m/(?:緯度秒|lat_sec|lats)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lng_sec = (m/(?:経度秒|lon_sec|longs)\s*=\s*([\d\.]+)/s) ? $1 : 0;
    my $lat_dir = (m/(?:N\(北緯\)及びS\(南緯\)|lat_dir|latNS)\s*=\s*([NS])/s && $1 eq 'S') ? -1 : 1;
    my $lng_dir = (m/(?:E\(東経\)及びW\(西経\)|lon_dir|longEW)\s*=\s*([EW])/s && $1 eq 'W') ? -1 : 1;
    $lat = $lat_dir * ($lat_deg + ($lat_min / 60) + ($lat_sec / 3600));
    $lng = $lng_dir * ($lng_deg + ($lng_min / 60) + ($lng_sec / 3600));
    last;
  }
  $self->{lat} = $lat;
  $self->{lng} = $lng;
  return ($self->{lat}, $self->{lng});
}

1;
