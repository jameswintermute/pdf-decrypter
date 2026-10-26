# pdf-decrypter

Simple Bash script to batch-decrypt password-protected PDFs from the command line.

- Example: you have a large number of encrypted PDFs on your NAS and want to remove the password to make long-term storage and viewing easy.
- Processes the PDFs in the **current directory** (not recursive).
- Unencrypted PDFs are skipped; originals are never modified.
- Decrypted copies are written to `output/` as `un-encrypted-<original name>.pdf`.

## Dependencies

- [qpdf](https://qpdf.readthedocs.io/en/stable/overview.html) **10.2 or later** ([source on GitHub](https://github.com/qpdf/qpdf)) — widely available FOSS on Linux.
- Install with `sudo apt install qpdf` or the equivalent for your distro. Check with `qpdf --version`.

## Usage

```bash
cd /path/to/pdfs
/path/to/decrypter.sh
```

Or, with the script in the same directory as the PDFs:

```bash
./decrypter.sh
```

You are prompted once for the password, which is applied to every encrypted PDF in the directory.

To write the decrypted copies somewhere else (for example, to keep unprotected files off a shared NAS):

```bash
OUTPUT_DIR=~/decrypted /path/to/decrypter.sh
```

### Output

Each file reports one of:

| Status | Meaning |
|---|---|
| `Decrypted` | Success. |
| `Decrypted (qpdf repaired warnings)` | Success; qpdf fixed minor structural faults in the PDF (qpdf exit code 3). The output is valid. |
| `Skipped (not encrypted)` | Nothing to do. |
| `Failed (invalid password)` | qpdf rejected the password. |
| `Failed (permission denied …)` | qpdf could not open the input or write the output. See Troubleshooting. |
| `Failed (qpdf exit N)` | Any other qpdf error; the first line of qpdf's message is printed underneath. |

The script exits `0` if nothing failed and `1` otherwise, so it can be chained in other scripts.

### Security notes

- The password is read with `read -rs` (no echo, backslashes and spaces preserved) and passed to qpdf on stdin, so it never appears in the process list (`ps`, `/proc`).
- If you test qpdf by hand with `--password=...`, the password lands in your shell history. Remove it with `history -d <n>`, or set `HISTCONTROL=ignorespace` and prefix such commands with a space.
- Decrypted output is unprotected — store it accordingly.

## Troubleshooting

### `Permission denied` on files you can read (AppArmor)

Some distributions, including recent Ubuntu releases, ship an enforced AppArmor profile for qpdf (`/etc/apparmor.d/qpdf`). It does not permit GVFS network mounts, i.e. SMB/NAS shares opened from the file manager, which appear under `/run/user/<uid>/gvfs/...`. Symptoms:

- Every encrypted file fails, regardless of password.
- `qpdf` reports `open <file>: Permission denied`, while `head -c 8 <file>` prints `%PDF-1.x` normally.
- `ls -l` shows you own the file — on GVFS this is synthesised and proves nothing.

Confirm:

```bash
sudo journalctl -k --since "-5min" | grep 'profile="qpdf"'
```

Lines with `apparmor="DENIED" operation="open"` confirm it. The `name=` field is hex-encoded when the path contains spaces; decode with `echo <hex> | xxd -r -p`.

Fix — either copy the PDFs under your home directory and run there, or add a local override (survives package upgrades):

```bash
grep -n 'local/' /etc/apparmor.d/qpdf        # expect: include if exists <local/qpdf>
echo 'owner /run/user/[0-9]*/gvfs/** rw,' | sudo tee -a /etc/apparmor.d/local/qpdf
sudo apparmor_parser -r /etc/apparmor.d/qpdf
```

The rule grants read/write (the script writes `output/` on the same mount) and is limited by `owner` to your own GVFS mounts.

### `Failed (invalid password)` with a password you know is correct

- Test a single file by hand: `qpdf --password='...' --decrypt in.pdf /tmp/out.pdf; echo "exit=$?"`.
- Passwords with non-ASCII characters can be affected by encoding differences between PDF encryption revisions. `qpdf --show-encryption file.pdf` shows the revision (`R` value); qpdf's `--password-mode` option controls how the password is encoded.

## Licence

GPL-3.0 — see [LICENSE](LICENSE).
