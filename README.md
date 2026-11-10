![ffdup — cinematic cover with twin data monoliths and a cyan scan beam](docs/images/ffdup-cover.png)

# ffdup

**A lightweight, portable duplicate file finder written in Perl.**

ffdup scans directory trees and reports groups of files with matching content, even when their names differ. It narrows down candidates by file size and sampled checksums before calculating full-file hashes.

Built with Perl core modules, ffdup is suitable for local storage, archives, and NAS devices with Perl support.

## Highlights

- **Recursive scanning:** search one or more directories in a single run.
- **Efficient comparisons:** filter candidates before reading entire files for hashing.
- **No CPAN dependencies:** uses modules included with Perl.
- **Flexible reports:** print duplicate groups to the terminal or save them to a file.
- **Report-only operation:** scanned files are not modified or deleted.

## Requirements

- Perl with its standard modules, including `Digest::MD5`.
- `Digest::SHA` when using the SHA hash options.
- Read access to the directories and files you want to scan.

The examples below use a Unix-like shell. On NAS devices, make sure Perl is installed and available.

## Installation

### Download the script

```sh
wget https://raw.githubusercontent.com/lookee/ffdup/master/ffdup.pl
chmod +x ffdup.pl
```

### Clone the repository

```sh
git clone https://github.com/lookee/ffdup.git
cd ffdup
chmod +x ffdup.pl
```

Run the script with `./ffdup.pl`, or use `perl ffdup.pl` to invoke Perl explicitly.

## Quick start

Scan a directory and its subdirectories:

```sh
./ffdup.pl "/path/to/directory"
```

Compare files across multiple directories:

```sh
./ffdup.pl "/path/to/photos" "/path/to/backup"
```

Save duplicate groups to a report, suppressing progress messages and statistics:

```sh
./ffdup.pl --quiet --out duplicates.txt "/path/to/directory"
```

By default, ffdup compares files of **1,024 bytes or larger**. To include smaller files, set `--size_min 0`:

```sh
./ffdup.pl --size_min 0 "/path/to/directory"
```

## Reading the output

Each group lists absolute file paths, one per line. A blank line separates groups. Groups are ordered by file size, largest first; paths within each group are sorted alphabetically.

Illustrative output:

```text
/storage/photos/image.jpg
/storage/backup/image-copy.jpg

/storage/documents/report.pdf
/storage/archive/report-final.pdf
```

Every path in a group is a matching copy; the first path is not designated as an original.

Duplicate groups go to standard output, or to the file specified by `--out`. Progress messages and statistics go to standard error unless `--quiet` is enabled. An existing output file is overwritten; keep reports outside the directories being scanned.

## Options

Usage: `./ffdup.pl [OPTIONS] DIRECTORY [DIRECTORY ...]`

| Option | Description |
| --- | --- |
| `--out FILE` | Write duplicate groups to a file instead of standard output. |
| `--cwd` | Add the current working directory to the scan. |
| `--home` | Add the user's home directory to the scan. |
| `--size_min BYTES` | Minimum file size to compare, inclusive. Default: `1024`. |
| `--size_max BYTES` | Maximum file size to compare, inclusive. No limit by default. |
| `--print_size` | Print a size heading before the groups for each file size. |
| `--hash ALGORITHM` | Select `MD5` (default), `SHA256`, or the legacy `SHA1` value; see below. |
| `--progress` | Print progress messages; enabled by default. |
| `--verbose` | Request diagnostic messages. In the current implementation, the default progress setting takes precedence. |
| `--quiet` | Suppress progress messages, diagnostics, and statistics. |
| `--version` | Print the version. |
| `--help` | Print command-line help. |

Size values are integer byte counts, without unit suffixes.

For example, scan the current directory for files of at least 1 MiB using SHA-256, and include sizes in the report:

```sh
./ffdup.pl --cwd --size_min 1048576 --hash SHA256 --print_size
```

## How matching works

1. Recursively collect readable files within the configured size range.
2. Group files by size; ignore sizes that occur only once.
3. Compare sampled checksums from the beginning, middle, and end of candidate files. Files smaller than 8 KiB skip this filtering step.
4. Calculate full-file hashes for the remaining candidates and report matching groups.

### Current behavior

- Matches are based on file size and hash equality; ffdup does not perform a final byte-by-byte comparison.
- Directory symlinks are not followed during traversal.
- The legacy `--hash SHA1` value currently selects SHA-256 internally. Use `--hash SHA256` when you want SHA-256 explicitly.
- `--help` and `--version` currently exit with status `2`, even when they print successfully.

## Development

The [`t/`](t/) directory contains a random directory-tree generator for manual testing, rather than an automated unit test suite.

To generate sample data from a cloned repository:

```sh
bash t/make_test_repos.sh
./ffdup.pl test_repos/TEST
```

The generator requires Bash and utilities including `shuf`. It asks for confirmation, then removes and recreates `test_repos/` relative to the current working directory.

For bug reports or suggestions, [open an issue](https://github.com/lookee/ffdup/issues). Include your Perl version, operating system, command, and a small reproducible example.

## License

Free software released under the **GNU General Public License, version 3 or later**. See [LICENSE](LICENSE) for the full license text.

## Author

**Luca Amore**  
[Website](https://www.lucaamore.com) · [Email](mailto:luca.amore@gmail.com)
