#!/bin/bash
# Decrypt encrypted PDFs in current directory with progress bar and skip unencrypted files

OUTPUT_DIR="output"
mkdir -p "$OUTPUT_DIR"

read -sp "Enter PDF password: " PDF_PASSWORD
echo

shopt -s nullglob
pdf_files=( *.pdf )
total_files=${#pdf_files[@]}

if [ "$total_files" -eq 0 ]; then
    echo "No PDF files found."
    exit 1
fi

echo "Scanning and decrypting $total_files PDF file(s)..."

processed=0
skipped=0
counter=0

for filepath in "${pdf_files[@]}"; do
    ((counter++))
    filename=$(basename "$filepath")
    output_filename="un-encrypted-$filename"
    output_path="$OUTPUT_DIR/$output_filename"

    # Check if PDF is already unencrypted
    if qpdf --show-encryption "$filepath" 2>/dev/null | grep -q "not encrypted"; then
        ((skipped++))
        status="Skipped (already unencrypted)"
    else
        # Attempt decryption
        if qpdf --password="$PDF_PASSWORD" --decrypt "$filepath" "$output_path" 2>/dev/null; then
            ((processed++))
            status="Decrypted"
        else
            status="Failed (bad password?)"
        fi
    fi

    # Show progress
    progress=$((counter * 100 / total_files))
    printf "\r[%3d%%] %-30s -> %-30s (%s)" "$progress" "$filename" "$output_filename" "$status"
    echo
done

echo
echo "✅ Done."
echo "🔓 Decrypted: $processed"
echo "⏩ Skipped (already unencrypted): $skipped"
echo "📂 Output folder: '$OUTPUT_DIR'"
