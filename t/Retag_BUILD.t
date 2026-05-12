#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_BUILD_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use Log::Log4perl qw(:levels);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;
use Test::Output;

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	my $message = $self->uniqueStr();
	my $sut = Daybo::Twitch::Retag->new(json => 1, logLevel => 'ERROR');
	my $debugOutput = stdout_from(sub { $sut->__log($INFO, $message) });
	my $errorOutput = stdout_from(sub { $sut->__log($ERROR, $message) });

	is($debugOutput, '', 'BUILD applies configured log threshold');
	like($errorOutput, qr/"message":"\Q$message\E"/, 'BUILD configures JSON logging appender');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_BUILD_Tests->new->run);
