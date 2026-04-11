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

package Daybo::Twitch::TagWrap::Backend::MKV;
use Moose;

extends 'Daybo::Twitch::TagWrap::Backend';

use English qw(-no_match_vars);
use File::Spec;
use File::Temp qw(tempfile);

=item C<deleteTags($file)>

No-op for MKV files; tag removal is handled implicitly by C<writeTags>.

=cut

sub deleteTags {
	# no-op
}

=item C<readTags($file)>

Runs C<mkvextract tags FILE> and parses the Matroska XML output to
extract the canonical tag fields (artist, album, track, year, comment).
Returns a hash ref of the fields found, or C<undef> if none are present.

=cut

my %__reverseTagMap = (
	ALBUM         => 'album',
	ARTIST        => 'artist',
	COMMENT       => 'comment',
	DATE_RELEASED => 'year',
	TITLE         => 'track',
);

sub readTags {
	my ($self, $file) = @_;

	open(my $fh, '-|', 'mkvextract', 'tags', $file) or return;
	local $INPUT_RECORD_SEPARATOR = undef;
	my $xml = <$fh>;
	close($fh);

	return unless defined($xml);

	my %tags;
	while ($xml =~ m{<Simple>\s*<Name>([^<]+)</Name>\s*<String>([^<]*)</String>.*?</Simple>}gs) {
		my ($name, $value) = ($1, $2);
		my $field = $__reverseTagMap{$name};
		$tags{$field} = __xmlUnescape($value) if (defined($field));
	}

	return %tags ? \%tags : undef;
}

=item C<writeTags($file, $artist, $album, $track, $year, $comment)>

Writes Matroska global tags to C<$file> using C<mkvpropedit>.  Builds an
XML tag file (Matroska tag format), writes it to a temporary file, then
calls C<mkvpropedit --tags global:TMPFILE FILE>.  The temporary XML file
is removed after the call.  No return value.

=cut

my %__tagMap = (
	album   => 'ALBUM',
	artist  => 'ARTIST',
	comment => 'COMMENT',
	track   => 'TITLE',
	year    => 'DATE_RELEASED',
);

sub writeTags {
	my ($self, $file, $artist, $album, $track, $year, $comment) = @_;

	my %values = (
		album   => $album,
		artist  => $artist,
		comment => $comment,
		track   => $track,
		year    => $year,
	);

	my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
	$xml .= qq{<!DOCTYPE Tags SYSTEM "matroskatags.dtd">\n};
	$xml .= "<Tags>\n<Tag>\n<Targets/>\n";
	for my $field (sort keys %__tagMap) {
		next unless (defined($values{$field}) && length($values{$field}));
		$xml .= sprintf("<Simple><Name>%s</Name><String>%s</String></Simple>\n",
			$__tagMap{$field}, __xmlEscape($values{$field}));
	}
	$xml .= "</Tag>\n</Tags>\n";

	my ($fh, $temp) = tempfile(
		'.twitch-tag-mkvpropedit.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
		SUFFIX => '.xml',
		UNLINK => 0,
	);
	print $fh $xml;
	close($fh);

	$self->_system('mkvpropedit', '--tags', "global:${temp}", $file);
	unlink($temp);

	return;
}

=item C<__xmlEscape($str)>

Escapes C<&>, C<E<lt>>, C<E<gt>>, and C<"> in C<$str> for safe inclusion
in XML character data.  Returns the escaped string.

=cut

sub __xmlEscape {
	my ($str) = @_;
	$str =~ s/&/&amp;/g;
	$str =~ s/</&lt;/g;
	$str =~ s/>/&gt;/g;
	$str =~ s/"/&quot;/g;
	return $str;
}

=item C<__xmlUnescape($str)>

Reverses the escaping applied by C<__xmlEscape>: restores C<&amp;>,
C<&lt;>, C<&gt;>, and C<&quot;> to their literal characters.
Returns the unescaped string.

=cut

sub __xmlUnescape {
	my ($str) = @_;
	$str =~ s/&quot;/"/g;
	$str =~ s/&gt;/>/g;
	$str =~ s/&lt;/</g;
	$str =~ s/&amp;/&/g;
	return $str;
}

1;
