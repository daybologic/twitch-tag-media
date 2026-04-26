# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`twitch-tag-media` is a Perl utility that reads Twitch stream recording filenames (downloaded via yt-dlp) and writes tags to MP3 (ID3v1/v2 via `id3v2`) and MP4 (metadata via `ffmpeg`) files. It processes files concurrently via forking.

## Build & Test Commands

```sh
perl Makefile.PL   # Generate Makefile
make               # Build
make test          # Run tests (parallelised by Sys::CPU)
make install       # Install
```

Debian packaging:
```sh
dpkg-buildpackage -b
```

## Architecture

**Entry point:** `bin/twitch-tag-media` — instantiates `Daybo::Twitch::Retag` and calls `->run($dir)`.

**Single module:** `lib/Daybo/Twitch/Retag.pm` (Moose-based) contains all logic:

- `run($dirname)` — recursively walks directories, skips `@eaDir`, forks a child for each supported media file found.
- `__tag(...)` — forks a child process; parent collects PIDs, child calls `__tagPerProcess` then exits.
- `__tagPerProcess(...)` — reads existing tags, writes new ones via the appropriate backend (MP3: `id3v2`; MP4: `ffmpeg`).
- `__parseFileName($filename)` — extracts artist, album (`"$artist on Twitch"`), track, and year from the yt-dlp filename convention: `ArtistHandle (type) YYYY-MM-DD HH_MM-StreamID.mp3`. Contains hardcoded artist handle→display name mappings.
- `__acceptableDirName($name)` — returns false for `@eaDir` (Synology index dirs).

## Coding Style

All `sub` definitions must use cuddled braces — opening brace on the same line as `sub`:

```perl
sub foo {   # correct
sub foo{    # wrong
```

Subroutines prefixed with `__` are private (internal to the module). Subroutines without that prefix (`run`, `usage`) are public and form the API called from `bin/twitch-tag-media`.

All subroutines must be in lexical (case-insensitive alphabetical) order, ignoring the `__` prefix when determining position. This applies to new subs and any time existing subs are renamed.
Calls to subroutines must always include parentheses, so they are visually distinct from access to Moose attributes.

## Code Quality Rules

A pre-commit hook (`maint/trap-goose-corruption.sh`, configured in `.pre-commit-config.yaml`) rejects commits if `lib/` contains:
- Markdown fences (` ``` `)
- File path headers (`### /path/file`)
- Line-number prefixes (`123: `)

**Never rewrite entire files.** Make minimal, targeted edits verifiable via `git diff`. Do not introduce formatting changes outside the scope of a requested change.

After any modification, run `git diff` and confirm only the intended lines changed. Do not commit automatically unless explicitly instructed.

## Unit Tests (`t/*.t`)

Unit tests use `Test::Module::Runnable` (vendored under `externals/libtest-module-runnable-perl/`), a Moose-based framework that auto-discovers and runs all methods whose names match `^test`.

**Structure of each test file:**

Each `.t` file defines two packages:

1. A test class (e.g. `MP3_deleteTags_Tests`) that `extends 'Test::Module::Runnable'` and contains:
   - `setUp` — instantiates the system under test into `$self->sut(...)`. Must return `EXIT_SUCCESS`.
   - One or more `test*` methods — each calls `plan tests => N`, exercises `$self->sut`, and returns `EXIT_SUCCESS`.

2. `package main` — a one-liner: `exit(ClassName->new->run)`.

**Mocking:**

External calls (e.g. `_system` on the backend base class) are mocked via `$self->mock($package, $method)`, which uses `Test::MockModule` internally and records all calls. Use `$self->mockCallsWithObject($package, $method)` to retrieve the call log as an arrayref of arrayrefs (each including `$self` as the first element). Use `$self->mockCalls(...)` when the object reference is not needed. Assertions are made with `Test::Deep::cmp_deeply`.

**Test data:**

Use `$self->uniqueStr()` to generate unique, predictable alphanumeric strings for filenames and other inputs. Do not hardcode values where `uniqueStr` can be used instead.

**Philosophy:**

Tests are unit-level: each file covers one method of one class. External processes (`id3v2`, `ffmpeg`, `mkvpropedit`) are never actually invoked — they are always mocked at the `_system` boundary. The test name mirrors the file being tested: `MP3_deleteTags.t` tests `Backend::MP3::deleteTags`.

## Filename Convention

Expected input filename pattern:
```
ArtistHandle (type) YYYY-MM-DD HH_MM-StreamID.mp3
```
Example: `1stdegreeproductions (live) 2021-10-18 11_05-40110166187.mp3`

`parseFileName` strips `-trim`, `-tempo`, `-untempo` suffixes from the track name and normalises artist handles (removes "Official"/"Music"/"dj", replaces `_` with space, trims whitespace, and maps specific handles to display names).
