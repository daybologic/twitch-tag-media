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

package Daybo::Twitch::TagWrap::Backend::Opus;
use Moose;

extends 'Daybo::Twitch::TagWrap::Backend';

use English qw(-no_match_vars);

=item C<__readTagLines($file)>

Runs C<opustags -l> over C<$file> via
L<Daybo::Twitch::TagWrap::Backend/_openPipe> and returns an array ref of
output lines, or C<undef> if the pipe could not be opened.

=cut

sub __readTagLines {
	my ($self, $file) = @_;
	my $fh = $self->_openPipe('opustags', '-l', $file);
	return unless defined($fh);
	my @lines = <$fh>;
	close($fh) or die("close failed: $ERRNO");
	chomp(@lines);
	return \@lines;
}

=item C<deleteTags($file)>

No-op for Opus files; tag removal is handled implicitly by C<writeTags>
via C<opustags>'s C<-D> (delete-all) flag.

=cut

sub deleteTags {
	# no-op
}

=item C<readTags($file)>

Given C<$file>, runs C<opustags -l> over it and returns the Vorbis comment
tags as a hash ref, or C<undef> if no tags are present.  The C<DATE> key is
normalised to C<year> and C<TITLE> to C<track> to match the common tag
interface.  All keys are lowercased.

=cut

sub readTags {
	my ($self, $file) = @_;

	my $lines = $self->__readTagLines($file);
	return unless defined($lines);

	my %tags;
	for my $line (@{$lines}) {
		next unless $line =~ m/\A([^=]+)=(.*)\z/ms;
		my ($key, $value) = (lc($1), $2);
		$tags{$key} = $value;
	}

	if ($tags{date}) {
		$tags{year} = delete($tags{date});
	}

	if ($tags{title}) {
		$tags{track} = delete($tags{title});
	}

	return scalar(keys(%tags)) > 0 ? \%tags : undef;
}

=item C<writeTags($file, $artist, $album, $track, $year, $comment)>

Write Vorbis comment tags to the given Opus file in-place using C<opustags>.
All existing tags are removed via C<-D> before the new values are set.
Dies if C<opustags> exits non-zero.  No return value.

=cut

sub writeTags {
	my ($self, $file, $artist, $album, $track, $year, $comment) = @_;

	my $exitCode = $self->_system('opustags',
		'-i',
		'-D',
		'-s', "ARTIST=$artist",
		'-s', "ALBUM=$album",
		'-s', "TITLE=$track",
		'-s', "DATE=$year",
		'-s', "COMMENT=$comment",
		$file,
	);

	die("opustags failed for '$file'") if $exitCode != 0;

	return;
}

1;
