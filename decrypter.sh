#!/bin/bash
# Written 2025, James Wintermute. Refined with ChatGPT.
# Decrypt all PDF files in the current directory using qpdf with a CLI progress bar
# Output files will be saved in 'output/' with a 'un-encrypted-' prefix

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

echo "Starting decryption of $total_files file(s)..."

counter=0
for filepath in "${pdf_files[@]}"; do
    ((counter++))
    filename=$(basename "$filepath")
    output_filename="un-encrypted-$filename"
    output_path="$OUTPUT_DIR/$output_filename"

    qpdf --password="$PDF_PASSWORD" --decrypt "$filepath" "$output_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        status="Success"
    else
        status="Failed"
    fi

    # Display progress
    progress=$((counter * 100 / total_files))
    printf "\r[%3d%%] %s -> %s (%s)" "$progress" "$filename" "$output_filename" "$status"
done

echo -e "\nDecryption process complete. Files saved to '$OUTPUT_DIR/'."
