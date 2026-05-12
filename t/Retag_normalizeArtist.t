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

package Retag_normalizeArtist_Tests;
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
	plan tests => 10;

	is(Daybo::Twitch::Retag::__normalizeArtist('TheRealKristinaSky'), 'Kristina Sky', 'uses exact display-name override');
	is(Daybo::Twitch::Retag::__normalizeArtist('taucher66'), 'Taucher', 'uses case-insensitive display-name override');
	is(Daybo::Twitch::Retag::__normalizeArtist('The_Real_DJ_Edit'), 'DJ Edit', 'normalises DJ Edit override');
	is(Daybo::Twitch::Retag::__normalizeArtist('XiJaroAndPitch'), 'XiJaro & Pitch', 'normalises and override');
	is(Daybo::Twitch::Retag::__normalizeArtist('gabrielanddresden'), 'Gabriel & Dresden', 'normalises ampersand override');
	is(Daybo::Twitch::Retag::__normalizeArtist('A_D_A_M_S_K_I'), 'A D A M S K I', 'preserves spaced acronym override');
	is(Daybo::Twitch::Retag::__normalizeArtist('Music4ThaMasses'), 'Music4ThaMasses', 'preserves mixed-case special name');
	is(Daybo::Twitch::Retag::__normalizeArtist('ExampleOfficialMusic'), 'Example', 'strips Official and Music tokens');
	is(Daybo::Twitch::Retag::__normalizeArtist('someArtist_world'), 'Some Artist World', 'normalises underscores and camel case');
	is(Daybo::Twitch::Retag::__normalizeArtist('channelTV'), 'channelTV', 'preserves TV-suffixed raw name');

	return EXIT_SUCCESS;
}

package main; ## no critic (Modules::ProhibitMultiplePackages)
use strict;
use warnings;
exit(Retag_normalizeArtist_Tests->new->run);
