#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_getExt_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub testSuccess {
	my ($self) = @_;
	plan tests => 3;

	is(Daybo::Twitch::Retag::__getExt('file.MP3'), 'mp3', 'returns lower-case extension');
	is(Daybo::Twitch::Retag::__getExt('archive.tar.MP4'), 'mp4', 'uses final extension');
	is(Daybo::Twitch::Retag::__getExt($self->uniqueStr()), '', 'returns empty string when there is no extension');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_getExt_Tests->new->run);
