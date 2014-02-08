#!/bin/bash

ROOT_TEST_DIR='test_repos'
BASE_TEST_DIR="${ROOT_TEST_DIR}/BASE"

BLOCK_LIST="ABCDEFG"
MAX_FILE_COPY=7

BLOCKS=10
BLOCK_SIZE='1K'

ASK_CONFIRM=0
ASK_CONFIRM_TEXT="
This program create a new test repository for ffdup.
It create the root dir: ${ROOT_TEST_DIR}

Are you sure? (y/n)
"

perm() {
	local items="$1"
	local out="$2"
	local i
	[[ "$items" == "" ]] && echo $out && return 
	for (( i=0; i<${#items}; i++ )) ; do
		perm "${items:0:i}${items:i+1}" "$out${items:i:1}"
	done
}

make_perm() {
    local blocks="$1"
    local base_dir="${BASE_TEST_DIR}"
 
    for f in $(perm "$blocks"); do
        dest_file="${base_dir}/${f}"
        for (( i=0; i<${#f}; i++ )); do
            cat "${base_dir}/${f:$i:1}" >> "$dest_file"
        done
    done
}

### MAIN ###

if [[ $ASK_CONFIRM -eq 1 ]]
then

	read -p "${ASK_CONFIRM_TEXT}" -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
    		exit 1
	fi
fi

rm -rfv "${ROOT_TEST_DIR}"
mkdir -pv "${ROOT_TEST_DIR}" 

mkdir -pv "${BASE_TEST_DIR}"

for (( i=0; i<${#BLOCK_LIST}; i++ )); do
    blk_name=${BLOCK_LIST:$i:1}
	file_name="${BASE_TEST_DIR}/${blk_name}"
	dd if=/dev/urandom of="$file_name" bs="$BLOCK_SIZE" count=1
done

make_perm ${BLOCK_LIST:0:2}
make_perm ${BLOCK_LIST:0:3}
make_perm ${BLOCK_LIST:0:4}

for i in {1..10}; do
    new_dir="${ROOT_TEST_DIR}/D${i}"
    mkdir -p $new_dir
    file_copy_count=$(($RANDOM % $MAX_FILE_COPY))
    for src in $(find ${BASE_TEST_DIR} -type f | shuf -n "$file_copy_count"); do
        cp -v "$src" "$new_dir"
    done
done
