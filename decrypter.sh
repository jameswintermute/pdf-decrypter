#!/usr/bin/env bash
# Decrypt encrypted PDFs in the current directory; skip unencrypted files.
# Requires qpdf >= 10.2 (for --password-file=-).

set -u

OUTPUT_DIR="output"

if ! command -v qpdf >/dev/null 2>&1; then
    echo "qpdf not found (e.g. sudo apt install qpdf)" >&2
    exit 1
fi

shopt -s nullglob nocaseglob
pdf_files=( *.pdf )
shopt -u nocaseglob
total_files=${#pdf_files[@]}

if (( total_files == 0 )); then
    echo "No PDF files found."
    exit 1
fi

# -r keeps backslashes literal; IFS= preserves leading/trailing whitespace.
IFS= read -rsp "Enter PDF password: " PDF_PASSWORD
echo

mkdir -p "$OUTPUT_DIR"
echo "Scanning and decrypting $total_files PDF file(s)..."

processed=0
skipped=0
failed=0
counter=0

for filename in "${pdf_files[@]}"; do
    counter=$((counter + 1))
    output_filename="un-encrypted-$filename"
    output_path="$OUTPUT_DIR/$output_filename"
    detail=""

    # --is-encrypted: exit 0 = encrypted, 2 = not encrypted. No password needed.
    # "./" prefix stops a filename beginning with '-' being parsed as an option.
    if ! qpdf --is-encrypted "./$filename" 2>/dev/null; then
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

(( failed == 0 ))
