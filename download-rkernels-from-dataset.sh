#!/usr/bin/env bash

SCRIPT_DIR="${0%/*}"

# @TODO: verify if Kaggle is properly setup as the command line API?
if ! kaggle --version >> /dev/null
then
  echo "Non-working kaggle API"
  exit 1
fi

DATA_KERNELS_DEST="$SCRIPT_DIR/Data"
KAGGLE_NO_KERNELS='No kernels found'

page=1
# Selects the kernels

while true # I regret nothing
do
	list_slugs=$(
	kaggle kernels list \
	  --language r \
	  --sort-by dateCreated \
	  --kernel-type script \
	  --page-size 50 \
	  -m \
	  --page "$page"
	)

	if [ "$list_slugs" = "$KAGGLE_NO_KERNELS" ] # || [ ! $? -eq 0 ]
	then
		echo "No more pages"
		break
	fi

	# Ignores first two rows, headers
	list_slugs=$(
	(cat <<END
$list_slugs
END
) | \
	awk 'NR>2{print $1}'
	)

	echo "Downloading kernels"

	for slug in $list_slugs; do
		generated_path="$DATA_KERNELS_DEST/$slug"
		echo "Downloading $slug to $generated_path"

		if ! kaggle kernels pull "$slug" \
			-p "$generated_path" \
			--metadata
		then
			echo "Failed downloading this kernel! Won't try again!"
		fi
	done

	let page=page+1

done

