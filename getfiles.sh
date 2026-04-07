#!/usr/bin/env bash

shopt -s globstar

{
tree -a -I .git --gitignore
echo
for f in ./.env* ./**/*.bash "${@}" ; do
  [[ -f "$f" ]] || continue
  echo "-------------------------------------------------------------------"
  echo "File: $f"
  echo "-------------------------------------------------------------------"
  cat -n "$f"
  echo "-------------------------------------------------------------------"
done
} | tee getfiles.txt | bat

