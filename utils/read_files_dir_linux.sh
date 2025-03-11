#!/bin/bash

INFO_FILE="INFO.txt"
BASE_DIR="$(pwd)"

rm -f "$INFO_FILE"

find . -type f | while read -r FILE; do
    REL_PATH="${FILE#./}"
    echo "$REL_PATH" >> "$INFO_FILE"
done

echo "Success"
