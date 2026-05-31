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

package Daybo::Twitch::Transforms;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(normalizeArtist);

=pod

=head1 NAME

Daybo::Twitch::Transforms - Artist-name transformations for Twitch stream recordings

=head1 DESCRIPTION

Pure functions that convert raw yt-dlp artist handles into human-readable
display names.  All three functions are exported on request.

Fork or replace this module to apply your own handle mappings and
normalisation rules without touching any other part of the codebase.

=head1 FUNCTIONS

=over

=item C<__fixConjunctions($artist)>

Lowercases C<on>, C<and>, and C<or> when they appear as interior words
(not first or last) in C<$artist>.  Returns the artist string unchanged
if it contains two words or fewer.

=cut

sub __fixConjunctions {
	my ($artist) = @_;
	my @words = split(/\s+/, $artist);
	return $artist if (@words <= 2);
	foreach my $i (1 .. $#words - 1) {
		$words[$i] = lc($words[$i]) if ($words[$i] =~ /^(?:on|and|or)$/i);
	}
	return join(' ', @words);
}

=item C<__fixWorldSuffix($artist)>

Ensures a trailing C<world> token is separated from the preceding word by
a space, and normalizes a trailing C< Uk> suffix to C< UK>.

=cut

sub __fixWorldSuffix {
	my ($artist) = @_;
	$artist =~ s/(\S)(world)$/$1 $2/i;
	$artist =~ s/ Uk$/ UK/i;
	return $artist;
}

=item C<normalizeArtist($artistRaw)>

Converts a raw yt-dlp artist handle into a display name.  Strips
C<Official>, C<Music>, and C<dj> tokens; replaces underscores with
spaces; splits camelCase runs into words; applies title-case; fixes
conjunctions and world-suffix; and applies a table of hardcoded
handle-to-name overrides.

Fork or edit this module to add mappings for streamers not yet listed.

=cut

sub normalizeArtist {
	my ($artistRaw) = @_;
	my $artist = $artistRaw;

	$artist =~ s/Official//gi;
	$artist =~ s/Music//gi;
	$artist = 'Raymond Doyle' if ($artist eq 'CarteBlanche88');
	$artist = 'Taucher' if ($artist =~ m/^taucher66$/i);
	$artist = 'Kristina Sky' if ($artist eq 'TheRealKristinaSky');
	$artist = 'Edit' if ($artist eq 'The_Real_DJ_Edit' || $artist eq 'TheReal_DJEdit');
	$artist = 'Vlastimil' if ($artist =~ m/^vlastimilvibes$/i);
	$artist =~ s/dj//i;
	$artist =~ s/_/ /g;
	$artist =~ s/\s*$//;
	$artist =~ s/^\s*//;

	if ($artist =~ /^[A-Z]{3,}/ || $artist =~ /[a-z][A-Z]/) {
		my @words = ($artist =~ /([A-Z][a-z]+|[A-Z]+|[a-z]+|[0-9]+)/g);
		$artist = join(' ', map { ucfirst(lc($_)) } @words);
	}

	$artist = __fixWorldSuffix($artist);
	$artist =~ s/\b([a-z])/uc($1)/ge;
	$artist = __fixConjunctions($artist);

	$artist = 'DJ Chopper' if ($artistRaw eq 'djChopper');
	$artist = 'DJ DNA' if ($artist eq 'Dna');
	$artist = 'DJ Edit' if ($artist eq 'Edit');
	$artist = 'DJ Paulo' if ($artist eq 'Paulo');
	$artist = 'DJ Baedine' if ($artist eq 'Baedine');
	$artist = 'HANAWINS' if ($artist eq 'Hanawins');
	$artist = 'A D A M S K I' if ($artistRaw eq 'A_D_A_M_S_K_I');
	$artist = 'Bugi' if ($artistRaw eq 'xX_Bugi_Xx');
	$artist = 'ReOrder' if ($artistRaw eq 'ReOrderDJ');
	$artist = 'Rob Kidd' if ($artist =~ m/^robkidd/i);
	$artist = 'Ryan Moon' if ($artist =~ m/^ryanmoon/i);
	$artist = 'Mark Sherry' if ($artistRaw =~ m/^marksherrydj$/i);
	$artist = 'Markus Schulz' if ($artistRaw =~ m/^markusschulz$/i);
	$artist = 'Ferry Corsten' if ($artist =~ m/^ferrycorsten/i);
	$artist = 'Noemi Black' if ($artist =~ m/^noemiblack/i);
	$artist = 'Fraser Binnie' if ($artist =~ m/^fraserbinnie/i);
	$artist = 'Stoneface & Terminal' if ($artist eq 'Stoneface Terminal');
	$artist = 'XiJaro & Pitch' if ($artistRaw eq 'XiJaroAndPitch');
	$artist = 'FaBiESto' if ($artistRaw eq 'FaBiESto');
	$artist = 'Gabriel & Dresden' if ($artistRaw eq 'gabrielanddresden');
	$artist = $artistRaw if ($artistRaw eq 'Music4ThaMasses');
	$artist = $artistRaw if ($artistRaw eq 'RaZoR368');
	$artist = lc($artistRaw) if ($artistRaw =~ m/^tkkttony$/i);
	$artist = $artistRaw if ($artistRaw =~ /TV$/);

	return $artist;
}

=back

=cut

1;
