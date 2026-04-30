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

package Backend_initBackends_Tests;
use strict;
use warnings;
use Moose;

use lib 'externals/libtest-module-runnable-perl/lib';

our $mockGlob;

# Override CORE::GLOBAL::glob before any module loads so that bare glob()
# calls in production code (which dispatch through CORE::GLOBAL::glob) are
# intercepted.  The (_) prototype mirrors glob's own prototype.  The fallback
# calls CORE::glob so that normal glob usage elsewhere is unaffected.
BEGIN {
	*CORE::GLOBAL::glob = sub (_) {
		if (defined $Backend_initBackends_Tests::mockGlob) {
			return $Backend_initBackends_Tests::mockGlob->(@_);
		}
		return CORE::glob($_[0]);
	};
}

extends 'Test::Module::Runnable';

use Daybo::Twitch::TagWrap::Backend;
use English qw(-no_match_vars);
use POSIX qw(EXIT_SUCCESS);
use Test::More 0.96;

sub setUp {
	my ($self) = @_;

	$self->sut(Daybo::Twitch::TagWrap::Backend->new());

	return EXIT_SUCCESS;
}

sub tearDown {
	my ($self) = @_;
	undef $mockGlob;
	return EXIT_SUCCESS;
}

sub testFailure {
	my ($self) = @_;
	plan tests => 2;

	my @warnings;
	local $SIG{__WARN__} = sub { push(@warnings, @_) };

	local $mockGlob = do {
		my @files = ('fake/path/Nonexistent.pm');
		sub { return shift(@files) };
	};

	my $result = $self->sut->__initBackends();
	is_deeply($result, {}, 'empty hashref returned when module cannot be loaded');
	like($warnings[0], qr/Could not import package/, 'warning emitted on load failure');

	return EXIT_SUCCESS;
}

sub testSuccess {
	my ($self) = @_;
	plan tests => 2;

	local $mockGlob = do {
		my @files = ('fake/path/MP3.pm');
		sub { return shift(@files) };
	};

	my $result = $self->sut->__initBackends();
	ok(exists($result->{MP3}), 'MP3 key present in returned hashref');
	isa_ok($result->{MP3}, 'Daybo::Twitch::TagWrap::Backend::MP3');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Backend_initBackends_Tests->new->run);
