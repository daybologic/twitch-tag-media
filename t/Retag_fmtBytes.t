#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_fmtBytes_Tests;
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
	plan tests => 6;

	is(Daybo::Twitch::Retag::__fmtBytes(undef), '0 bytes', 'undef formats as zero bytes');
	is(Daybo::Twitch::Retag::__fmtBytes(999), '999 bytes', 'formats bytes');
	is(Daybo::Twitch::Retag::__fmtBytes(1024), '1.0 KiB (1024 bytes)', 'formats KiB');
	is(Daybo::Twitch::Retag::__fmtBytes(1024 * 1024), '1.00 MiB (1048576 bytes)', 'formats MiB');
	is(Daybo::Twitch::Retag::__fmtBytes(1024 * 1024 * 1024), '1.000 GiB (1073741824 bytes)', 'formats GiB');
	is(Daybo::Twitch::Retag::__fmtBytes(1000 * 1024 * 1024 * 1024), '0.977 TiB (1073741824000 bytes)', 'formats TiB');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_fmtBytes_Tests->new->run);
