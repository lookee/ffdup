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

# ---------------------------------------------------------------------------
# TEST CONFIG PARAMETERS
# ---------------------------------------------------------------------------
TEST_DIRECTORY_COUNT=25 # number of test directory to create (ex D1, ..., DN)
BLOCK_LIST="ABCDEFGH"   # every char is a block name
MAX_FILE_COPY=7         # max file (random) copied from base
MAX_FILE_DUP_COPY=2     # max file duplicated (.dup) in each dir
SYMLINK_DIR_COUNT=3     # number of symlink directories
BLOCK_SIZE='8K'         # block size
MAX_BLOCKS_INTO_FILES=4 # number of max blocks into files
# ---------------------------------------------------------------------------

BLOCK_LIST_COUNT=${#BLOCK_LIST}
BASE_TEST_DIR="${ROOT_TEST_DIR}/BASE"
REPOS_TEST_DIR="${ROOT_TEST_DIR}/TEST"

ASK_CONFIRM=1
ASK_CONFIRM_TEXT="
---------------------------------------------------------------
FFDUP TEST REPOSITORY - ver. $VERSION
---------------------------------------------------------------

This program creates a new TEST random repository for ffdup.

The root dir: ${ROOT_TEST_DIR}

N. TEST DIRECTORIES    : ${TEST_DIRECTORY_COUNT}
BASE BLOCKS            : ${BLOCK_LIST}
N. BASE BLOCKS         : ${BLOCK_LIST_COUNT}
BLOCK_SIZE             : ${BLOCK_SIZE}
MAX FILE COPY          : ${MAX_FILE_COPY}
MAX FILE DUP           : ${MAX_FILE_DUP_COPY}
MAX BLOCKS into FILES  : ${MAX_BLOCKS_INTO_FILES}
N. SYMLINK DIRECTORIES : ${SYMLINK_DIR_COUNT}

---------------------------------------------------------------

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
for (( i=0; i<${BLOCK_LIST_COUNT}; i++ )); do
    blk_name=${BLOCK_LIST:$i:1}
	file_name="${BASE_TEST_DIR}/${blk_name}"
	dd if=/dev/urandom of="$file_name" bs="$BLOCK_SIZE" count=1
done

# compose block files permutating blocks to generate multiblock files
for i in $(seq 1 ${MAX_BLOCKS_INTO_FILES}); do
    create_file_by_perm ${BLOCK_LIST:0:$i}
done

# random copy blocks or multiblock files into TEST directory tree
for i in $(seq 1 ${TEST_DIRECTORY_COUNT}); do
    new_dir="${REPOS_TEST_DIR}/D${i}"
    mkdir -p $new_dir
    file_copy_count=$(($RANDOM % $MAX_FILE_COPY))
    for src in $(find ${BASE_TEST_DIR} -type f | shuf -n "$file_copy_count"); do
        cp -v "$src" "$new_dir"
    done
done

# random duplicate files into TEST directory tree
for i in $(seq 1 ${TEST_DIRECTORY_COUNT}); do
    new_dir="${REPOS_TEST_DIR}/D${i}"
    file_copy_dup_count=$(($RANDOM % $MAX_FILE_DUP_COPY))
    for src in $(find ${new_dir} -type f | shuf -n "$file_copy_dup_count"); do
        cp -v "$src" "$src.dup"
    done
done

# create symlink directories
for i in $(seq 1 ${SYMLINK_DIR_COUNT}); do
    cd ${REPOS_TEST_DIR}
    ln -sv "D${i}" "SD${i}"
    cd -
done
