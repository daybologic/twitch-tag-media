#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
#     * Neither the name of the the maintainer, nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

package Retag_log_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use JSON::PP qw(decode_json);
use Log::Log4perl qw(get_logger :levels);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;
use Test::Output;

sub tearDown {
	my ($self) = @_;
	get_logger('Daybo.Twitch.Retag')->level($INFO);
	return EXIT_SUCCESS;
}

sub testJsonHash {
	my ($self) = @_;
	plan tests => 2;

	my $sut = Daybo::Twitch::Retag->new(json => 1);
	my $output = stdout_from(sub { $sut->logger->emit($INFO, { event => 'unit' }) });

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
	my $output = stdout_from(sub { $sut->logger->emit($INFO, $message) });

	my $decoded = decode_json($output);
	is($decoded->{message}, $message, 'wraps scalar message');
	is($decoded->{level}, 'INFO', 'adds scalar message level');

	return EXIT_SUCCESS;
}

sub testThreshold {
	my ($self) = @_;
	plan tests => 1;

	my $sut = Daybo::Twitch::Retag->new(json => 1, logLevel => 'ERROR');
	get_logger('Daybo.Twitch.Retag')->level($ERROR);
	my $output = stdout_from(sub { $sut->logger->emit($INFO, $self->uniqueStr()) });

	is($output, '', 'does not emit below threshold');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_log_Tests->new->run);
