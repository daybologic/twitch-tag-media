#!/usr/bin/perl
# Twitch media tagger.
# Copyright (c) 2023-2026, Rev. Duncan Ross Palmer (2E0EOL)
# All rights reserved.

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
