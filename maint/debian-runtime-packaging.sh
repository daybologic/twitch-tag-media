#!/bin/sh
# Twitch MP3 tagger.
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

# Segregate installed Perl modules into the private twitch-tag-media paths.
# Called from debian/rules override_dh_auto_install after dh_auto_install.
#
# Pure Perl (.pm) files  -> /usr/share/twitch-tag-media/perl5/
# Arch-dependent (.so/.bs) files -> /usr/lib/twitch-tag-media/perl5/

set -eu

STAGING=debian/twitch-tag-media

mkdir -p "$STAGING/usr/share/twitch-tag-media/perl5"
mkdir -p "$STAGING/usr/lib/twitch-tag-media/perl5"

# Move our own package's module directories out of the system perl5 tree.
find "$STAGING/usr/share/perl5" -maxdepth 1 -mindepth 1 -not -name 'auto' -type d | while read dir; do
	mv "$dir" "$STAGING/usr/share/twitch-tag-media/perl5/"
done

# Move any top-level .pm files our package installed.
find "$STAGING/usr/share/perl5" -maxdepth 1 -mindepth 1 -name '*.pm' -type f | while read f; do
	mv "$f" "$STAGING/usr/share/twitch-tag-media/perl5/"
done

# Move any arch-dependent files our package installed (unlikely for a pure-Perl
# project, but handled for completeness).
find "$STAGING/usr/share/perl5/auto" -type f \( -name '*.so' -o -name '*.bs' \) 2>/dev/null | while read f; do
	relpath="$(echo "$f" | sed -E 's|.*/perl[^/]*/([0-9]+\.[0-9]+/)?||')"
	destdir="$STAGING/usr/lib/twitch-tag-media/perl5/$(dirname "$relpath")"
	mkdir -p "$destdir"
	mv "$f" "$destdir/"
done
rm -rf "$STAGING/usr/share/perl5/auto"

# Copy all lib*-perl build dependencies into the private tree.
# In an sbuild chroot only our declared Build-Depends (and their transitive
# deps) are installed, so dpkg-query returns exactly the right set.
for pkg in $(dpkg-query -W -f '${Package}\n' 'lib*-perl' 2>/dev/null); do
	# Pure Perl modules — preserve directory hierarchy.
	dpkg -L "$pkg" 2>/dev/null | grep '\.pm$' | grep -v '/auto/' | while read f; do
		relpath="$(echo "$f" | sed -E 's|.*/perl[^/]*/([0-9]+\.[0-9]+/)?||')"
		destdir="$STAGING/usr/share/twitch-tag-media/perl5/$(dirname "$relpath")"
		mkdir -p "$destdir"
		cp -p "$f" "$destdir/"
	done
	# Arch-dependent files.
	dpkg -L "$pkg" 2>/dev/null | grep -E '/auto/.*\.(so|bs)$' | while read f; do
		relpath="$(echo "$f" | sed -E 's|.*/perl[^/]*/([0-9]+\.[0-9]+/)?||')"
		destdir="$STAGING/usr/lib/twitch-tag-media/perl5/$(dirname "$relpath")"
		mkdir -p "$destdir"
		cp -p "$f" "$destdir/"
	done
done
