#!/usr/bin/env bash
# Decrypt encrypted PDFs in the current directory; skip unencrypted files.
# Requires qpdf >= 10.2 (for --password-file=-).
#
# Usage:   ./decrypter.sh
#          OUTPUT_DIR=~/decrypted ./decrypter.sh
# Exit:    0 = no failures, 1 = one or more files failed (or no PDFs found)

set -u

OUTPUT_DIR="${OUTPUT_DIR:-output}"

if ! command -v qpdf >/dev/null 2>&1; then
    echo "qpdf not found (e.g. sudo apt install qpdf)" >&2
    exit 1
fi

shopt -s nullglob nocaseglob
pdf_files=( *.pdf )
shopt -u nocaseglob
total_files=${#pdf_files[@]}

if (( total_files == 0 )); then
    echo "No PDF files found in $(pwd)."
    exit 1
fi

# -r keeps backslashes literal; IFS= preserves leading/trailing whitespace.
IFS= read -rsp "Enter PDF password: " PDF_PASSWORD
echo

if ! mkdir -p -- "$OUTPUT_DIR"; then
    echo "Cannot create output directory '$OUTPUT_DIR'." >&2
    exit 1
fi

echo "Scanning $total_files PDF file(s)..."

processed=0
skipped=0
failed=0
denied=0
counter=0

for filename in "${pdf_files[@]}"; do
    counter=$((counter + 1))
    output_filename="un-encrypted-$filename"
    output_path="$OUTPUT_DIR/$output_filename"
    detail=""

    # --is-encrypted: exit 0 = encrypted, 2 = not encrypted (or unreadable).
    # Capture stderr so an unreadable file is reported, not silently skipped.
    # "./" prefix stops a filename beginning with '-' being parsed as an option.
    enc_err=$(qpdf --is-encrypted "./$filename" 2>&1)
    enc_rc=$?

    if (( enc_rc != 0 )) && grep -qi "permission denied" <<< "$enc_err"; then
        failed=$((failed + 1))
        denied=$((denied + 1))
        status="Failed (permission denied opening input)"
        detail=$(head -n 1 <<< "$enc_err")
    elif (( enc_rc != 0 )); then
        skipped=$((skipped + 1))
        status="Skipped (not encrypted)"
    else
        # Password goes in on stdin so it never appears in the process list.
        # qpdf exit codes: 0 = success, 2 = error, 3 = success with warnings.
        err=$(printf '%s\n' "$PDF_PASSWORD" \
              | qpdf --password-file=- --decrypt "./$filename" "$output_path" 2>&1 >/dev/null)
        rc=$?

        case $rc in
            0)
                processed=$((processed + 1))
                status="Decrypted"
                ;;
            3)
                processed=$((processed + 1))
                status="Decrypted (qpdf repaired warnings)"
                ;;
            *)
                failed=$((failed + 1))
                rm -f -- "$output_path"
                if grep -qi "invalid password" <<< "$err"; then
                    status="Failed (invalid password)"
                elif grep -qi "permission denied" <<< "$err"; then
                    denied=$((denied + 1))
                    status="Failed (permission denied)"
                    detail=$(head -n 1 <<< "$err")
                else
                    status="Failed (qpdf exit $rc)"
                    detail=$(head -n 1 <<< "$err")
                fi
                ;;
        esac
    fi

    progress=$((counter * 100 / total_files))
    printf "[%3d%%] %-30s -> %-30s (%s)\n" "$progress" "$filename" "$output_filename" "$status"
    [[ -n $detail ]] && printf "       %s\n" "$detail"
done

unset PDF_PASSWORD

echo
echo "✅ Done."
echo "🔓 Decrypted: $processed"
echo "⏩ Skipped (not encrypted): $skipped"
echo "❌ Failed: $failed"
echo "📂 Output folder: '$OUTPUT_DIR'"

if (( denied > 0 )); then
    echo
    echo "⚠️  $denied file(s) failed with 'Permission denied'."
    if [[ -e /etc/apparmor.d/qpdf ]]; then
        cat <<'EOF'
   qpdf runs under an AppArmor profile on this system, which may block
   paths such as GVFS network mounts (/run/user/<uid>/gvfs/...).
   Check for denials:
       sudo journalctl -k --since "-5min" | grep 'profile="qpdf"'
   If present, either copy the PDFs under your home directory and re-run,
   or add a local override (see README, Troubleshooting):
       echo 'owner /run/user/[0-9]*/gvfs/** rw,' | sudo tee -a /etc/apparmor.d/local/qpdf
       sudo apparmor_parser -r /etc/apparmor.d/qpdf
EOF
    else
        cat <<'EOF'
   Check file and directory permissions, and any mandatory access control
   (AppArmor/SELinux) confining qpdf. Copying the PDFs to a local directory
   and re-running is a quick way to isolate the cause.
EOF
    fi
fi

(( failed == 0 ))
