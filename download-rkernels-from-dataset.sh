#!/usr/bin/env bash

SCRIPT_DIR="${0%/*}"

# @TODO: verify if Kaggle is properly setup as the command line API?
kaggle --version >> /dev/null
if [[ ! $? -eq 0 ]]; then
  echo "Non-working kaggle API"
  exit 1
fi

# Downloads the first 20 R and Rmd kernels for a given dataset
DATA_KERNELS_DEST="$SCRIPT_DIR/Data"
DATASET_SLUG=""

# Selects the kernels
# TODO: work with a single script?
#TODO: only doing for the top 20 for now, to test it.
list_slugs=$(
kaggle kernels list \
  --language r \
  --sort-by relevance \
  --kernel-type script \
  --page 1 | \
  awk 'NR>2{print $1}'
) # Ignores first two rows, headers

#???
#list_slugs=$("$list_slugs" |awk 'NR>2{print $1}'

echo "Downloading kernels"

for slug in $list_slugs; do
  generated_path="$DATA_KERNELS_DEST/$slug"
  echo "Downloading $slug to $generated_path"

  kaggle kernels pull "$slug" \
    -p "$generated_path" \
    --metadata

  if [[ ! $? -eq 0 ]]; then
    echo "Failed downloading a kernel!"
  fi

done

# Saves the dataset kernels files to the Data directory

