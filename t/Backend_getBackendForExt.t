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

package Backend_getBackendForExt_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::Exception;
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend->new());

	return EXIT_SUCCESS;
}

sub testFailure {
	my ($self) = @_;
	plan tests => 1;

	my $ext = $self->uniqueStr();

	my ($pkg, $method) = ('Daybo::Twitch::TagWrap::Backend', '__initBackends');
	$self->mock($pkg, $method, sub { return {} });

	throws_ok(
		sub { $self->sut->getBackendForExt($ext) },
		qr/Cannot find module which deals with extension '\Q$ext\E'/,
		'dies when no backend registered for extension',
	);

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 1;

	my $ext          = $self->uniqueStr();
	my $fake_backend = bless({}, 'FakeBackend');

	my ($pkg, $method) = ('Daybo::Twitch::TagWrap::Backend', '__initBackends');
	$self->mock($pkg, $method, sub { return { uc($ext) => $fake_backend } });

	my $result = $self->sut->getBackendForExt(lc($ext));
	is($result, $fake_backend, 'correct backend returned for extension (case-insensitive)');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Backend_getBackendForExt_Tests->new->run);
