#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

package Retag_log_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use JSON::PP qw(decode_json);
use Log::Log4perl qw(:levels);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;
use Test::Output;

sub testJsonHash {
	my ($self) = @_;
	plan tests => 2;

	my $sut = Daybo::Twitch::Retag->new(json => 1);
	my $output = stdout_from(sub { $sut->__log($INFO, { event => 'unit' }) });

	my $decoded = decode_json($output);
	is($decoded->{event}, 'unit', 'keeps supplied JSON fields');
	is($decoded->{level}, 'INFO', 'adds level to JSON hash');

	return EXIT_SUCCESS;
}

sub testJsonScalar {
	my ($self) = @_;
	plan tests => 2;

	my $message = $self->uniqueStr();
	my $sut = Daybo::Twitch::Retag->new(json => 1);
	my $output = stdout_from(sub { $sut->__log($INFO, $message) });

	my $decoded = decode_json($output);
	is($decoded->{message}, $message, 'wraps scalar message');
	is($decoded->{level}, 'INFO', 'adds scalar message level');

	return EXIT_SUCCESS;
}

sub testThreshold {
	my ($self) = @_;
	plan tests => 1;

	my $sut = Daybo::Twitch::Retag->new(json => 1, logLevel => 'ERROR');
	my $output = stdout_from(sub { $sut->__log($INFO, $self->uniqueStr()) });

	is($output, '', 'does not emit below threshold');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_log_Tests->new->run);
