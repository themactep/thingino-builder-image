#!/usr/bin/env bash
# prune-dl.sh — Remove git repos and metadata from dl/ to reduce image size
# Removes: */git/ directories and */git.readme files
# Keeps: tarballs, bundles, lock files, patches

set -euo pipefail

DL_DIR="${1:-.}"

if [ ! -d "$DL_DIR" ]; then
  echo "Error: $DL_DIR is not a directory"
  exit 1
fi

BEFORE=$(du -sb "$DL_DIR" | cut -f1)

echo "Pruning git directories from $DL_DIR ..."
find "$DL_DIR" -maxdepth 2 -type d -name "git" -exec rm -rf {} + 2>/dev/null || true
find "$DL_DIR" -maxdepth 2 -name "git.readme" -type f -delete 2>/dev/null || true

AFTER=$(du -sb "$DL_DIR" | cut -f1)
SAVED=$(( BEFORE - AFTER ))

echo "Before: $(( BEFORE / 1024 / 1024 ))MB"
echo "After:  $(( AFTER / 1024 / 1024 ))MB"
echo "Saved:  $(( SAVED / 1024 / 1024 ))MB"
