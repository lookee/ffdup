#!/bin/bash

# ---------------------------------------------------------------------------
# make_test_repos - random file tree generator

# Copyright 2014, Luca Amore - luca.amore at gmail.com
# <http://www.lucaamore.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.
#
# ---------------------------------------------------------------------------

VERSION="0.1" 

ROOT_TEST_DIR='test_repos'
BASE_TEST_DIR="${ROOT_TEST_DIR}/BASE"
REPOS_TEST_DIR="${ROOT_TEST_DIR}/TEST"

BLOCK_LIST="ABCDEFG"
MAX_FILE_COPY=7
MAX_FILE_DUP_COPY=2

BLOCK_SIZE='1K'

ASK_CONFIRM=0
ASK_CONFIRM_TEXT="
This program create a new TEST repository for ffdup.
It create the root dir: ${ROOT_TEST_DIR}

   TEST DIRECTORIES : ${TEST_DIRECTORY_COUNT}
   BASE BLOCKS      : ${BLOCK_LIST}
   BLOCK_SIZE       : ${BLOCK_SIZE}
   MAX FILE COPY    : ${MAX_FILE_COPY}
   MAX FILE DUP     : ${MAX_FILE_DUP}

Warning: All files into root dir will be removed.

Are you sure? (y/n)
"

# generate all string permutations
perm() {
	local items="$1"
	local out="$2"
	local i
	[[ "$items" == "" ]] && echo $out && return 
	for (( i=0; i<${#items}; i++ )) ; do
		perm "${items:0:i}${items:i+1}" "$out${items:i:1}"
	done
}

# compose files permutating all passed blocks
create_file_by_perm() {
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

# WARNING: it removes all TEST repository directory tree
rm -rfv "${ROOT_TEST_DIR}"

# generate TEST repository directory tree
mkdir -pv "${ROOT_TEST_DIR}" 
mkdir -pv "${BASE_TEST_DIR}"

# generate random block files from BLOCK_LIST
for (( i=0; i<${#BLOCK_LIST}; i++ )); do
    blk_name=${BLOCK_LIST:$i:1}
	file_name="${BASE_TEST_DIR}/${blk_name}"
	dd if=/dev/urandom of="$file_name" bs="$BLOCK_SIZE" count=1
done

# compose block files permutating blocks to generate multiblock files
create_file_by_perm ${BLOCK_LIST:0:2}
create_file_by_perm ${BLOCK_LIST:0:3}
create_file_by_perm ${BLOCK_LIST:0:4}

# random copy blocks or multiblock files into TEST directory tree
for i in {1..10}; do
    new_dir="${REPOS_TEST_DIR}/D${i}"
    mkdir -p $new_dir
    file_copy_count=$(($RANDOM % $MAX_FILE_COPY))
    for src in $(find ${BASE_TEST_DIR} -type f | shuf -n "$file_copy_count"); do
        cp -v "$src" "$new_dir"
    done
done

# random duplicate files into TEST directory tree
for i in {1..10}; do
    new_dir="${REPOS_TEST_DIR}/D${i}"
    file_copy_dup_count=$(($RANDOM % $MAX_FILE_DUP_COPY))
    for src in $(find ${new_dir} -type f | shuf -n "$file_copy_dup_count"); do
        cp -v "$src" "$src.dup"
    done
done
