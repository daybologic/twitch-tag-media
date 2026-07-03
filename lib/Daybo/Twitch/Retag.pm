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

package Daybo::Twitch::Retag;
use English qw(-no_match_vars);
use IO::Dir;
use IO::File;
use JSON::PP qw(encode_json);
use List::Util qw(shuffle);
use Log::Log4perl qw(:levels);
use Sys::CPU qw();
use Time::HiRes qw(sleep time);
use Moose;
use POSIX qw(EXIT_FAILURE EXIT_SUCCESS);
use Daybo::Twitch::TagWrap;
use Daybo::Twitch::Transforms;
use Daybo::Twitch::BaseObject;
extends 'Daybo::Twitch::BaseObject';

our $VERSION = '1.0.0';

our $URL = 'github.com/daybologic/twitch-tag-media';

has jobs => (is => 'ro', isa => 'Int', lazy => 1, default => \&__makeJobs);

has [qw(atime ctime mtime)] => (is => 'ro', isa => 'Int', default => 0);

has delay => (is => 'ro', isa => 'Num', default => 0);

has [qw(force json noop random recursive stats)]
    => (is => 'ro', isa => 'Bool', default => 0);

has logLevel => (is => 'ro', isa => 'Str', default => 'INFO');

has _stats => (is => 'rw', isa => 'HashRef', default => sub { return {}; });

has __originalProgramName => (is => 'rw', isa => 'Str');

has _tagWrap => (is => 'ro', isa => 'Daybo::Twitch::TagWrap', default => sub { Daybo::Twitch::TagWrap->new() });

my @pids;
my $__interrupted = 0;

=item C<BUILD()>

Moose post-construction hook.  Registers this instance as the application
singleton on L<Daybo::Twitch::BaseObject> so that all other objects in the
hierarchy can reach it via C<< $obj->application() >>.

=cut

sub BUILD {
	my ($self) = @_;
	$self->application($self);
	return;
}

=item C<__acceptableDirName($dirName)>

Returns true unless C<$dirName> is C<@eaDir> (a Synology metadata
directory that should never be walked).

=cut

sub __acceptableDirName {
	my ($dirName) = @_;
	return ($dirName ne '@eaDir');
}

=item C<__acceptableFileName($filename)>

Returns false if C<$filename> has a C<.temp.> penultimate extension
(e.g. C<foo.temp.mp4>), which indicates a file still being downloaded
by yt-dlp.  Returns true otherwise.

=cut

sub __acceptableFileName {
	my ($filename) = @_;
	return ($filename !~ /\.temp\.[^.]+$/i);
}

=item C<__collect($dirname)>

Recursively walks C<$dirname>, returning an array ref of tuples
C<[$relPath, $filename, $size, $ext]> for every file whose extension is
supported by the tag backend.  Updates C<_stats> with C<seen_files>,
C<seen_bytes>, C<unqualified_files>, and C<unqualified_bytes> as it goes.
Returns C<-1> (not a ref) if the directory cannot be opened.

=cut

sub __collect {
	my ($self, $dirname) = @_;
	my @files;

	my $dir = IO::Dir->new($dirname);
	unless ($dir) {
		$self->logger->emit($ERROR, "Cannot open '$dirname': $ERRNO");
		return -1;
	}

	while (defined(my $filename = $dir->read())) {
		last if ($__interrupted);

		next if ($filename eq '.' || $filename eq '..');

		my $relPath = $dirname . '/' . $filename;

		if (-d $relPath) {
			if ($self->recursive && __acceptableDirName($filename)) {
				my $sub = $self->__collect($relPath);
				push(@files, @{$sub}) if (ref($sub));
				last if ($__interrupted);
			}
		} elsif (my $fh = IO::File->new($relPath, '<')) {
			my $ext = __getExt($filename);
			my $size = -s $relPath;
			$fh->close();
			$self->_stats->{seen_files}++;
			$self->_stats->{seen_bytes} += $size;

			if ($self->_tagWrap->isExtSupported($ext) && __acceptableFileName($filename)) {
				if (__parseFileName($filename)) {
					push(@files, [ $relPath, $filename, $size, $ext ]);
				} else {
					$self->logger->emit($WARN, $self->json ? {
						process => { type => 'unqualified' },
						reason  => 'unparseable filename',
						file    => $relPath,
					} : $self->__marker(0) . "Cannot parse filename structure: '$relPath'");
					$self->_stats->{unqualified_bytes} += $size;
					$self->_stats->{unqualified_files}++;
				}
			} else {
				$self->_stats->{unqualified_bytes} += $size;
				$self->_stats->{unqualified_files}++;
			}
		}
	}

	$dir->close();
	@files = shuffle(@files) if ($self->random);
	return \@files;
}


=item C<__fmtBytes($bytes)>

Formats a byte count as a human-readable string with the appropriate
binary unit (TiB, GiB, MiB, KiB, or bytes).  Checks from largest to
smallest unit.

=cut

sub __fmtBytes {
	my ($bytes) = @_;
	$bytes = 0 unless(defined($bytes));

	return sprintf('%.3f TiB (%d bytes)', $bytes / (1024 * 1024 * 1024 * 1024), $bytes) if ($bytes >= 1000 * 1024 * 1024 * 1024);
	return sprintf('%.3f GiB (%d bytes)', $bytes / (1024 * 1024 * 1024), $bytes) if ($bytes >= 1024 * 1024 * 1024);
	return sprintf('%.2f MiB (%d bytes)', $bytes / (1024 * 1024), $bytes) if ($bytes >= 1024 * 1024);
	return sprintf('%.1f KiB (%d bytes)', $bytes / 1024, $bytes) if ($bytes >= 1024);
	return sprintf('%d bytes', $bytes);
}

=item C<__fmtDuration($seconds)>

Formats a duration in seconds as a human-readable string.  Emits
C<Hh MMm S.Ss>, C<Mm S.Ss>, or C<S.Ss> depending on magnitude.

=cut

sub __fmtDuration {
	my ($seconds) = @_;

	my ($h, $m, $s) = (0, 0, 0);
	if ($seconds > 0) {
		$h = int($seconds / 3600);
		$m = int(($seconds - $h * 3600) / 60);
		$s = $seconds - $h * 3600 - $m * 60;
	}

	return sprintf('%dh %02dm %.1fs', $h, $m, $s) if ($h > 0);
	return sprintf('%dm %.1fs', $m, $s) if ($m > 0);
	return sprintf('%.1fs', $s);
}

=item C<__getExt($fn)>

Returns the lower-case file extension of C<$fn> (the part after the last
C<.>), or an empty string if the filename has no extension.

=cut

sub __getExt {
	my ($fn) = @_;
	my @arr = split(m/\./, $fn);
	my $ext = $arr[ scalar(@arr) - 1 ];
	return '' if ($fn eq $ext);
	return lc($ext);
}

=item C<__handleSignal($sig)>

Instance method bound to C<$SIG{INT}> and C<$SIG{TERM}> via a closure in
L</run>.  Increments C<$__interrupted>.  On the first call, logs that
active children will be allowed to finish their current retag before
stopping, but does B<not> forward the signal.  On the second and
subsequent calls, logs and forwards C<$sig> to each child immediately.
No return value.

=cut

sub __handleSignal {
	my ($self, $sig) = @_;
	++$__interrupted;
	my $count = scalar(@pids);
	if ($__interrupted == 1) {
		$self->logger->emit($WARN, $self->json ? {
			process  => { type => 'signal' },
			signal   => $sig,
			action   => $count ? 'draining' : 'exiting',
			children => $count,
		} : $count ? sprintf("Caught SIG%s; %d child%s will finish current retag before stopping...",
		    $sig, $count, $count == 1 ? '' : 'ren') : sprintf('Caught SIG%s; exiting...', $sig));
	} else {
		$self->logger->emit($WARN, $self->json ? {
			process  => { type => 'signal' },
			signal   => $sig,
			action   => 'terminating',
			children => $count,
		} : sprintf("Caught SIG%s again; terminating %d child%s immediately...",
		    $sig, $count, $count == 1 ? '' : 'ren'));
		kill($sig, $_->{pid}) for @pids;
	}
	return;
}

=item C<__initStats()>

Resets the per-run counters and captures the start time.

=cut

sub __initStats {
	my ($self) = @_;

	$self->_stats({
		total_files    => 0,
		modified_files => 0,
		skipped_files  => 0,
		total_bytes    => 0,
		modified_bytes => 0,
		skipped_bytes  => 0,
		tags_altered      => 0,
		unqualified_bytes => 0,
		unqualified_files => 0,
		seen_files        => 0,
		seen_bytes        => 0,
		start_time        => time(),
		end_time       => 0,
	});

	return;
}

=item C<__logTagChanges($file, $pct, $existing, $artist, $album, $track, $year, $comment)>

Compares each proposed tag field against C<$existing> and logs the
differences (or a "Tags unchanged, forced rewrite" message when nothing
changed).  Returns the number of fields that differ.

=cut

sub __logTagChanges {
	my ($self, $file, $pct, $existing, $artist, $album, $track, $year, $comment) = @_;

	my %JSON_changeLog;
	my $plain_changeLog = '';
	my $changeCount = 0;

	if ($self->json) {
		%JSON_changeLog = (
			file => $file,
			process => {
				type => 'changelog',
				pct => $pct,
				pid => $PID,
			},
			changes => [ ],
		);
	}

	foreach my $f (
		['artist',  $existing->{artist},  $artist],
		['album',   $existing->{album},   $album],
		['track',   $existing->{track},   $track],
		['year',    $existing->{year},    $year],
		['comment', $existing->{comment}, $comment],
	) {
		my ($name, $old, $new) = @{$f};
		$old //= '';
		if ($old ne $new) {
			$changeCount++;
			if ($self->json) {
				push(@{ $JSON_changeLog{changes} }, {
					field => $name,
					old => $old,
					new => $new,
				});
			} elsif ($old eq '') {
				$plain_changeLog .= "${name}: \"${new}\", ";
			} else {
				$plain_changeLog .= "${name}: \"${old}\" -> \"${new}\", ";
			}
		}
	}

	if ($self->json) {
		$JSON_changeLog{process}{message} = 'Tags unchanged, forced rewrite'
		    if ($changeCount == 0);

		$self->logger->emit($INFO, \%JSON_changeLog);
	} else {
		if ($changeCount == 0) {
			$plain_changeLog = sprintf("%sTags unchanged, forcing rewrite for '%s'", $self->__marker($pct), $file)
		} else {
			$plain_changeLog = "Tags altered for '$file': ${plain_changeLog}";
		}

		$self->logger->emit($INFO, $self->__marker($pct) . $plain_changeLog);
	}

	return $changeCount;
}

=item C<__makeJobs()>

Initializer for L</jobs>, if the user has not specified the number of concurrent jobs.
Returns int.

=cut

sub __makeJobs {
	my ($self) = @_;

	my $count = Sys::CPU::cpu_count();
	if ($count == 1) {
		$self->logger->emit($DEBUG, $self->__marker(0) . 'not an SMP system');
		return $count;
	}

	$self->logger->emit($DEBUG, sprintf('%s%d cores detected, max jobs set to %d (use --jobs to override)',
	    $self->__marker(0), $count, $count+1));

	return ++$count;
}

=item C<__marker($pct)>

Updates the Log4perl MDC keys C<stamp> (elapsed C<HH:MM:SS.mmm>) and
C<pct> (formatted percentage) so the C<ConversionPattern> can emit them
as the log prefix.  Returns an empty string so existing call sites that
concatenate the return value remain valid.

=cut

sub __marker {
	my ($self, $pct) = @_;
	Log::Log4perl::MDC->put('stamp', $self->__stamp());
	Log::Log4perl::MDC->put('pct',   sprintf('%6.2f%%', $pct));
	return '';
}


=item C<__parseFileName($filename)>

Parses a yt-dlp-style filename and returns a four-element array ref
C<[$artist, $album, $track, $year]>.  Results are memoized by filename.
Artist handles are normalised via L<Daybo::Twitch::Transforms/normalizeArtist>.
Three filename formats are recognised:

=over

=item *

C<ArtistHandle (type) YYYY-MM-DD HH_MM[-StreamID].mp3>

=item *

C<YYYY-MM-DD-HH-MM-SS-ArtistHandle.ext>

=item *

C<ArtistHandle-YYYY-MM-DD.ext>

=back

Returns C<undef> if none of the patterns match.

=cut

my %__filenameParserContext = ( );
sub __parseFileName {
	# Example: '1stdegreeproductions (live) 2021-10-18 11_05-40110166187.mp3'
	# Example: '2022-05-30-15-20-01-vlastimilvibes.mp3'
	# Example: 'AlessandraRoncone_music-20210613-184300.mkv'
	my ($filename) = @_;

	if (my $cached = $__filenameParserContext{$filename}) {
		return $cached;
	}

	if ($filename =~ m/^(\w+)\s\(\w+\)\s((\d{4})-\d{2}-\d{2})(?:\s(\d{2})_(\d{2})(?:\s\[(\d+)\]|-(\d+))?)?/) {
		my ($date, $year, $hh, $mm) = ($2, $3, $4 // '00', $5 // '00');
		my $streamId = $6 // $7;
		my $artistRaw = $1;
		my $artist = Daybo::Twitch::Transforms::normalizeArtist($artistRaw);

		my $track = "$artist $date ${hh}:${mm}:00";
		$track .= " $streamId" if (defined($streamId));
		my $album = "${artist} on Twitch";

		return $__filenameParserContext{$filename} = [ $artist, $album, $track, $year ];
	} elsif ($filename =~ m/^(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\w+)\.\w+$/) {
		my ($year, $mon, $day, $hh, $mm, $ss, $artistRaw) = ($1, $2, $3, $4, $5, $6, $7);
		my $date = "$year-$mon-$day";
		my $artist = Daybo::Twitch::Transforms::normalizeArtist($artistRaw);
		my $track = "$artist $date ${hh}:${mm}:${ss}";
		my $album = "${artist} on Twitch";

		return $__filenameParserContext{$filename} = [ $artist, $album, $track, $year ];
	} elsif ($filename =~ m/^(\w+)-(\d{4})-(\d{2})-(\d{2})\.\w+$/) {
		my ($artistRaw, $year, $mon, $day) = ($1, $2, $3, $4);
		my $date = "$year-$mon-$day";
		my $artist = Daybo::Twitch::Transforms::normalizeArtist($artistRaw);
		my $album = "${artist} on Twitch";
		my $track = "${artist} ${date} 00:00:00";

		return $__filenameParserContext{$filename} = [ $artist, $album, $track, $year ];
	} elsif ($filename =~ m/^(\w+)-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.(mkv)$/) {
		my ($artistRaw, $year, $mon, $day, $hh, $mm, $ss) = ($1, $2, $3, $4, $5, $6, $7);
		my $date = "$year-$mon-$day";
		my $artist = Daybo::Twitch::Transforms::normalizeArtist($artistRaw);
		my $album = "${artist} on Twitch";
		my $track = "${artist} ${date} ${hh}:${mm}:${ss}";

		return $__filenameParserContext{$filename} = [ $artist, $album, $track, $year ];
	}

	return;
}

=item C<__printStats()>

Emits a run summary via C<logger-E<gt>emit> after all files have been processed.
In JSON mode, outputs a single C<stats> event object; otherwise prints a
human-readable multi-line summary.  No return value.

If the --stats flag was not used, this method is a no-op.

=cut

sub __printStats {
	my ($self) = @_;
	return unless ($self->stats);

	my $s = $self->_stats;
	my $elapsed = $s->{end_time} - $s->{start_time};
	my $total_mib = $s->{total_bytes} / (1024 * 1024);

	if ($self->json) {
		$self->logger->emit($INFO, {
			process => { type => 'stats' },
			stats => {
				total_files         => $s->{total_files} + 0,
				modified_files      => $s->{modified_files} + 0,
				skipped_files       => $s->{skipped_files} + 0,
				total_bytes         => $s->{total_bytes} + 0,
				modified_bytes      => $s->{modified_bytes} + 0,
				skipped_bytes       => $s->{skipped_bytes} + 0,
				tags_altered        => $s->{tags_altered} + 0,
				unqualified_bytes   => $s->{unqualified_bytes} + 0,
				unqualified_files   => $s->{unqualified_files} + 0,
				seen_files          => $s->{seen_files} + 0,
				seen_bytes          => $s->{seen_bytes} + 0,
				elapsed_s           => $elapsed + 0,
				avg_time_per_file_s => $s->{total_files} > 0 ? $elapsed / $s->{total_files} : 0,
				avg_time_per_mib_s  => $total_mib > 0 ? $elapsed / $total_mib : 0,
			},
		});
		return;
	}

	my $plain = sprintf("Summary:\n");
	$plain .= sprintf("  Files seen:       %d\n",   $s->{seen_files});
	$plain .= sprintf("  Bytes seen:       %s\n",   __fmtBytes($s->{seen_bytes}));
	$plain .= sprintf("  Files processed:  %d\n",   $s->{total_files});
	$plain .= sprintf("  Files modified:   %d\n",   $s->{modified_files});
	$plain .= sprintf("  Files skipped:    %d\n",   $s->{skipped_files});
	$plain .= sprintf("  Total bytes:      %s\n",   __fmtBytes($s->{total_bytes}));
	$plain .= sprintf("  Modified bytes:   %s\n",   __fmtBytes($s->{modified_bytes}));
	$plain .= sprintf("  Skipped bytes:    %s\n",   __fmtBytes($s->{skipped_bytes}));
	$plain .= sprintf("  Tags altered:     %d\n",   $s->{tags_altered});
	$plain .= sprintf("  Unqualified files: %d\n",  $s->{unqualified_files});
	$plain .= sprintf("  Unqualified bytes: %s\n",  __fmtBytes($s->{unqualified_bytes}));
	$plain .= sprintf("  Total time:       %s\n", __fmtDuration($elapsed));
	$plain .= sprintf("  Avg time/file:    %s\n", __fmtDuration($elapsed / $s->{total_files}))
	    if ($s->{total_files} > 0);
	$plain .= sprintf("  Avg time/GiB:     %s\n", __fmtDuration($elapsed / ($total_mib / 1024)))
	    if ($total_mib > 0);
	$plain .= sprintf("  Concurrent jobs:  %d\n", $self->jobs);
	$self->logger->emit($INFO, $self->__marker(100) . $plain);

	return;
}

=item C<__reapChild($done_pid, $pct)>

Reads the result line written by a finished child process, updates
C<_stats> with its file and byte totals, logs the outcome, then removes
its entry from C<@pids>.  C<$pct> is used for the log marker.
No return value.

=cut

sub __reapChild {
	my ($self, $done_pid, $pct) = @_;

	my ($entry) = grep { $_->{pid} == $done_pid } @pids;
	if ($entry) {
		my $line = readline($entry->{rfh});
		close($entry->{rfh});
		if (defined($line)) {
			chomp($line);
			my ($modified, $changeCount) = split(/ /, $line);
			$modified //= 0;
			$changeCount //= 0;
			$self->_stats->{total_files}++;
			$self->_stats->{total_bytes} += $entry->{size};
			if ($modified) {
				$self->_stats->{modified_files}++;
				$self->_stats->{modified_bytes} += $entry->{size};
			} else {
				$self->_stats->{skipped_files}++;
				$self->_stats->{skipped_bytes} += $entry->{size};
			}
			$self->_stats->{tags_altered} += $changeCount;
			$self->logger->emit($TRACE, $self->json ? {
				process => { type => 'reaped', pid => $done_pid, pct => $pct },
				modified      => $modified + 0,
				tags_altered  => $changeCount + 0,
				still_running => scalar(@pids) - 1,
			} : $self->__marker($pct) . sprintf(
			    'PID %d reaped (modified=%d, tags altered=%d, %d still running)',
			    $done_pid, $modified, $changeCount, scalar(@pids) - 1,
			));
		} else {
			$self->logger->emit($TRACE, $self->json ? {
				process => { type => 'reaped', pid => $done_pid, pct => $pct },
				interrupted => 1,
			} : $self->__marker($pct) . sprintf(
			    'PID %d reaped (no result; likely interrupted)',
			    $done_pid,
			));
		}
	}

	@pids = grep { $_->{pid} != $done_pid } @pids;
	return;
}

=item C<run(@paths)>

Public entry point.  Initializes stats, then iterates over C<@paths>:
plain files are examined directly; directories are walked via
C<__collect> (recursing only when C<--recursive> is set).  Dispatches
each qualifying file to C<__tag>, waits for all child processes to
finish, then prints the run summary.  Returns C<EXIT_SUCCESS> or
C<EXIT_FAILURE>.

=cut

sub run {
	my ($self, @paths) = @_;

	$self->__originalProgramName($PROGRAM_NAME);
	local $PROGRAM_NAME = sprintf('%s: main loop', $self->__originalProgramName);
	local $SIG{INT}  = sub { $self->__handleSignal(@_) };
	local $SIG{TERM} = sub { $self->__handleSignal(@_) };
	$__interrupted = 0;

	$self->__initStats();

	my @files;
	for my $path (@paths) {
		last if ($__interrupted);

		if (-f $path) {
			my ($filename) = ($path =~ m{([^/]+)$});
			my $ext = __getExt($filename);
			my $size = -s $path;
			$self->_stats->{seen_files}++;
			$self->_stats->{seen_bytes} += $size;
			if ($self->_tagWrap->isExtSupported($ext) && __acceptableFileName($filename) && __parseFileName($filename)) {
				push(@files, [ $path, $filename, $size, $ext ]);
			} else {
				$self->_stats->{unqualified_bytes} += $size;
				$self->_stats->{unqualified_files}++;
			}
		} elsif (-d $path) {
			$self->logger->emit($DEBUG, $self->__marker(0) . "Walking '$path'");
			my $sub = $self->__collect($path);
			push(@files, @{$sub}) if ref($sub);
		} else {
			$self->logger->emit($WARN, "No such file or directory: '$path'");
		}
	}

	if ($__interrupted) {
		$self->_stats->{end_time} = time();
		$self->logger->emit($INFO, $self->__marker(100) . 'Interrupted before tagging');
		$self->__printStats();
		return EXIT_FAILURE;
	}

	my $total = scalar(@files);
	if ($total == 0) {
		$self->logger->emit($INFO, $self->__marker(0) . 'Nothing to do!');
		return EXIT_SUCCESS;
	}

	my $weighted = $ENV{EXPERIMENTAL_PROGRESS};
	my ($totalBytes, $doneBytes);
	if ($weighted) {
		$totalBytes += $_->[2] for @files;
		$doneBytes = 0;
	}

	for (my $i = 0; $i < scalar(@files) && !$__interrupted; $i++) {
		my ($relPath, $filename, $size, $ext) = @{ $files[$i] };
		my $pct;
		if ($weighted) {
			$doneBytes += $size;
			$pct = $totalBytes > 0 ? $doneBytes / $totalBytes * 100 : 100;
		} else {
			$pct = $total > 0 ? ($i + 1) / $total * 100 : 100;
		}
		my $now = time();
		my $elapsed = $now - $self->_stats->{start_time};
		my $eta;
		$eta = ($total - $i) * $elapsed / $i if ($i > 0 && $elapsed > 0);

		if ($self->json) {
			my %progress = (
				process   => { type => 'progress', pct => $pct },
				file      => $relPath,
				elapsed_s => $elapsed + 0,
			);
			$progress{eta_s} = $eta + 0 if (defined($eta));
			$self->logger->emit($DEBUG, \%progress);
		} else {
			my $timing = '';
			$timing = sprintf(', ETA: %s', __fmtDuration($eta))
			    if (defined($eta));

			$self->logger->emit($DEBUG, sprintf("%sReading '%s'%s", $self->__marker($pct), $relPath, $timing));
		}

		last if ($__interrupted);

		$self->__tag(
			$relPath,
			$pct,
			$size,
			$ext,
			@{ __parseFileName($filename) },
		);
		sleep($self->delay) if ($self->delay > 0);
	}

	if ($__interrupted && @pids) {
		$self->logger->emit($TRACE, $self->__marker(100) . sprintf(
		    'Interrupted; waiting for %d child%s to finish...',
		    scalar(@pids), scalar(@pids) == 1 ? '' : 'ren',
		));
	}

	while (@pids) {
		local $PROGRAM_NAME = sprintf('%s: %s, waitpid (%d remaining)',
		    $self->__originalProgramName,
		    $__interrupted ? 'interrupted' : 'no more files',
		    scalar(@pids),
		);
		my $done = waitpid(-1, 0);
		next if ($done <= 0);
		$self->__reapChild($done, 100);
	}

	$self->_stats->{end_time} = time();
	$self->logger->emit($INFO, $self->__marker(100) . 'Finished');
	$self->__printStats();

	return $__interrupted ? EXIT_FAILURE : EXIT_SUCCESS;
}

=item C<__stamp()>

Returns the elapsed wall-clock time since C<start_time> formatted as
C<HH:MM:SS> for use as the timestamp token in log markers.

=cut

sub __stamp {
	my ($self) = @_;
	my $elapsed = time() - $self->_stats->{start_time};
	my $h = int($elapsed / 3600);
	my $m = int(($elapsed - $h * 3600) / 60);
	my $s = $elapsed - $h * 3600 - $m * 60;
	return sprintf('%02d:%02d:%06.3f', $h, $m, $s);
}

=item C<__tag($file, $pct, $size, $ext, $artist, $album, $track, $year)>

Enforces the C<--jobs> concurrency limit (blocking on C<waitpid> if
needed), then forks a child.  The parent records the child's PID and pipe
handle; the child calls C<__tagPerProcess>, writes its result to the
pipe, and exits.  No return value.

=cut

sub __tag {
	my ($self, $file, $pct, $size, $ext, $artist, $album, $track, $year) = @_;

	if (scalar(@pids) >= $self->jobs) {
		local $PROGRAM_NAME = sprintf('%s: reached %d concurrent jobs, waitpid', $self->__originalProgramName, $self->jobs);
		my $done = waitpid(-1, 0);
		$self->__reapChild($done, $pct) if ($done > 0);
		return if ($__interrupted);
	}

	pipe(my $rfh, my $wfh) or die("Cannot create pipe: $ERRNO");

	my $pid = fork();
	die("Cannot fork! $ERRNO") unless (defined($pid));

	if ($pid) { # parent
		close($wfh);
		push(@pids, { pid => $pid, rfh => $rfh, size => $size });
	} else { # child
		local $SIG{INT}  = 'DEFAULT';
		local $SIG{TERM} = 'DEFAULT';
		close($rfh);
		my ($modified, $changeCount) = $self->__tagPerProcess($file, $ext, $pct, $artist, $album, $track, $year);
		$modified //= 0;
		$changeCount //= 0;
		print $wfh "$modified $changeCount\n";
		close($wfh);
		exit(EXIT_SUCCESS);
	}

	return;
}

=item C<__tagPerProcess($file, $ext, $pct, $artist, $album, $track, $year)>

Runs inside a forked child.  If any of C<--atime>, C<--ctime>, or C<--mtime> are set, the corresponding
file timestamp is checked first: values up to one week (604800 s) are
treated as a maximum file age in seconds; larger values are treated as an
absolute Unix timestamp cutoff.  Files that are too recent are skipped
with a log message regardless of C<--force>.  Otherwise reads existing tags, skips if all fields are already
up to date (unless C<--force>), otherwise deletes and rewrites tags via
the appropriate backend and restores the original GID.
Returns a two-element list C<($modified, $changeCount)>.

=cut

sub __tagPerProcess {
	my ($self, $file, $ext, $pct, $artist, $album, $track, $year) = @_;
	my $comment = "Generated by $URL";

	my @file_stat;
	for my $check (['atime', 8], ['mtime', 9], ['ctime', 10]) {
		my ($name, $idx) = @{$check};
		my $threshold = $self->$name();
		next unless $threshold;
		@file_stat = stat($file) unless @file_stat;
		my $cutoff = $threshold > 604800 ? $threshold : int(time()) - $threshold;
		if ($file_stat[$idx] >= $cutoff) {
			$self->logger->emit($INFO, sprintf("%s%s check: skipping '%s'", $self->__marker($pct), $name, $file));
			return (0, 0);
		}
	}

	if ($self->json) {
		$self->logger->emit($DEBUG, {
			process => {
				type => 'candidate',
				pct => $pct,
				pid => $PID,
			},
			fields => {
				artist => $artist,
				album => $album,
				track => $track,
				year => $year,
				comment => $comment,
			},
		});
	} else {
#		$self->logger->emit(sprintf('%sartist: "%s", album: "%s", track: "%s", year: "%s"',
#		    $self->__marker($pct), $artist, $album, $track, $year));
#FIXME
	}

	local $PROGRAM_NAME = sprintf('%s: reading "%s"', $self->__originalProgramName, $file);
	my $backendForExt = $self->_tagWrap->getBackendForExt($ext);
	my $existing = $backendForExt->readTags($file);

	if (!$self->force
	    && $existing
	    && ($existing->{artist}  // '') eq $artist
	    && ($existing->{album}   // '') eq $album
	    && ($existing->{track}   // '') eq $track
	    && ($existing->{year}    // '') eq $year
	    && ($existing->{comment} // '') eq $comment
	) {
		$self->logger->emit($DEBUG, $self->json ? {
			process => { type => 'skipped', pct => $pct, pid => $PID },
			file    => $file,
		} : sprintf("%sTags unchanged, skipping '%s'", $self->__marker($pct), $file));
		return (0, 0);
	}

	my $changeCount = 0;
	$existing //= {};
	$changeCount = $self->__logTagChanges($file, $pct, $existing, $artist, $album, $track, $year, $comment);

	my @stat = stat($file)
	    or die("Cannot stat '$file': $ERRNO");

	my $gid = $stat[5];

	if ($self->noop) {
		return (0, $changeCount);
	}

	local $PROGRAM_NAME = sprintf('%s: retagging "%s"', $self->__originalProgramName, $file);
	$backendForExt->deleteTags($file);
	$backendForExt->writeTags($file, $artist, $album, $track, $year, $comment);

	unless (chown(-1, $gid, $file) == 1) {
		$self->logger->emit($ERROR, $self->json ? {
			process => { type => 'error', pid => $PID, pct => $pct },
			error   => 'chown_failed',
			gid     => $gid + 0,
			file    => $file,
			reason  => "$ERRNO",
		} : "Cannot restore GID $gid on '$file': $ERRNO");
		local $SIG{__DIE__} = 'DEFAULT'; ## no critic (Variables::RequireLocalizedPunctuationVars)
		die("Cannot restore GID $gid on '$file': $ERRNO");
	}

	return (1, $changeCount);
}

=item C<usage()>

Prints a usage summary to stdout and returns 1.

=cut

sub usage {
	printf("twitch-tag-media %s usage:\n", $VERSION);
	print("twitch-tag-media [--atime <S>] [--ctime <S>] [--delay <S>] [--force] [--help] [--jobs <N>] [--json] [--log-level <LEVEL>] [--mtime <S>] [--noop] [--random] [--recursive] [--version] PATH [PATH...]\n");
	print("twitch-tag-media [-d <S>] [-f] [-h] [-j <N>] [-J] [-L <LEVEL>] [-n] [-R] [-r] [-V] PATH [PATH...]\n\n");
	printf("See https://%s for more information.\n", $URL);
	return 1;
}

1;
