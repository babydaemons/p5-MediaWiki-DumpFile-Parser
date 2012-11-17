#!/usr/bin/env perl
use strict;
use utf8;
use MediaWiki::DumpFile::Parser;
use MediaWiki::DumpFile::Parser::Page;
use constant SEP => "=" x 78 . "\n";

binmode(STDOUT, ":utf8");

my $input = \*STDIN;
my $parser = MediaWiki::DumpFile::Parser->new($input);
my $page;
while (defined($page = $parser->next())) {
  print "【", $page->title, "】\n";
  print $page->text, "\n";
  print SEP, join("\n" => $page->templates), "\n", SEP;
}
