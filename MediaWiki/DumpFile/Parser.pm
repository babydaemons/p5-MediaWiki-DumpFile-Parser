package MediaWiki::DumpFile::Parser;
use base 'MediaWiki::DumpFile::Pages';

use strict;
use MediaWiki::DumpFile::Parser::Page;

sub new {
  my ($class, @args) = @_;
  my $self = MediaWiki::DumpFile::Pages->new(@args);
  bless($self, $class);
}

sub next {
  my $page = MediaWiki::DumpFile::Pages::next(@_);
  return MediaWiki::DumpFile::Parser::Page->new($page);
}

1;
