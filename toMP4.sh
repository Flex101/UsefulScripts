#!/bin/bash

old_file=$1
new_file=$(echo $old_file | rev | cut -f 2- -d '.' | rev).mp4

CONV_FILES=()

function getfiles()
{
	for item in $1/*; do
		if [ -d "$item" ]; then
			getfiles $item
		elif [ -f "$item" ]; then
			if [[ $item != *.mp4 ]]; then
				CONV_FILES+=("$item")
			fi
		fi
	done
}

if [ -d "${old_file}" ]; then
	echo ""
	echo "Batch mode..."
	
	getfiles ${old_file}
	
	for old_file in "${CONV_FILES[@]}"; do
		new_file=$(echo $old_file | rev | cut -f 2- -d '.' | rev).mp4
		
		if [ -f "$new_file" ]; then
			continue
		fi
		
		echo ""
		echo "Converting..."
		echo "$old_file -> $new_file"
		
		avidemux2.7_qt5 --load "$old_file" --audio-codec LavAC3 --output-format MP4 --save "$new_file" --quit
	done

elif [ -f "${old_file}" ]; then
	echo ""
	echo "Converting..."
	echo "$old_file -> $new_file"

	avidemux2.7_qt5 --load "$old_file" --audio-codec LavAC3 --output-format MP4 --save "$new_file" --quit
fi
