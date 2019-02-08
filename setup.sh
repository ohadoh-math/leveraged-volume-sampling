#!/usr/bin/env bash

set -eu

# This script performs environment setup.
# It fetches the required data sets as configured in the datasets file
# and places them in the .data/ directory.

readonly PROJECT_BASE=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
readonly SCRIPT=$(basename "${BASH_SOURCE[0]}")

readonly DEFAULT_DATASETS_FILE="${PROJECT_BASE}/datasets"
readonly DEFAULT_DATASETS_DIR="${PROJECT_BASE}/.data/"
readonly DEFAULT_DATASETS_CACHE="${PROJECT_BASE}/.datasets-cache"

readonly CACHE_FIELD_SEPARATOR="$(echo -ne '\t')"

function perror()
{
    echo "${SCRIPT}: error: ${@}" >&2
    exit 1
}

function trace()
{
    echo "${@}" >&2
}

function help()
{
    echo "
        usage: ${SCRIPT} [-h] [-x] [-s DATASETS-FILE] [-c DATASETS-CACHE-FILE] [-o OUTPUT-DIRECTORY]

        Performs basic setup of the execution environment.
        Fetches datasets listed in a dataset configuration file.
        | * -h - print this help.
        | * -x - enable bash's -x flag.
        | * -s DATASET-FILE - use the configuration listed in DATASET-FILE (default: ${DEFAULT_DATASETS_FILE}).
        | * -c DATASETS-CACHE-FILE - use DATASETS-CACHE-FILE to store the hashes of the downloaded data sets (default: ${DEFAULT_DATASETS_CACHE}).
        | * -o OUTPUT-DIRECTORY - use OUTPUT-DIRECTORY to store the data sets (default: ${DEFAULT_DATASETS_DIR}).
    " | sed -r 's/^\s*|?//g'
}

datasets_dir="${DEFAULT_DATASETS_DIR}"
datasets_list="${DEFAULT_DATASETS_FILE}"
datasets_cache="${DEFAULT_DATASETS_CACHE}"

while getopts ":hxs:c:o:" option
do
    case "${option}" in
        h)  help
            exit 0
            ;;

        x)  set -x
            ;;

        s)  datasets_list=$(readlink -f "${OPTARG}")
            ;;

        c)  datasets_cache=$(readlink -f "${OPTARG}")
            ;;

        o)  datasets_dir=$(readlink -f "${OPTARG}")
            ;;

        \?) perror "invalid option -${option} - use -h for help."
            ;;
    esac
done

# create output directory and cache file
mkdir -p "${datasets_dir}"
touch "${datasets_cache}"

# download datasets
sed 's,/+,/,g' "${datasets_list}" | while read dataset_url
do
    # extract file name from URL by treating it as a UNIX path
    dataset_file=$(readlink -f "${datasets_dir}/"$(basename "${dataset_url}"))
    trace "fetching ${dataset_url} to ${dataset_file}..."

    # first, consult the cache file to see if we've already downloaded the file
    already_downloaded_dataset=false
    downloaded_dataset_file=""
    downloaded_dataset_hash=""

    trace "    consulting cache file ${datasets_cache}..."
    if grep -qF "${dataset_url}" "${datasets_cache}"
    then
        # there's a relevant entry in the downloaded datasets cache!
        # check if the cached file exists and is consistent with the cached hash.
        IFS="${CACHE_FIELD_SEPARATOR}" read _ cached_file cached_hash < <(grep -F "${dataset_url}" "${datasets_cache}" | head -1)
        if [ -f "${cached_file}" ]
        then
            trace "        found a cache entry for ${dataset_url} - ${cached_file}"
            real_hash=$(sha1sum "${cached_file}" | cut -d' ' -f1)

            # compare actual hash with cached hash
            if [ "${real_hash}" == "${cached_hash}" ]
            then
                # the cached file is consistent
                trace "        cached file ${cached_file} is valid"
                already_downloaded_dataset=true
                downloaded_dataset_file="${cached_file}"
                downloaded_dataset_hash="${cached_hash}"
            else
                # the cached file is corrupt
                trace "        cached file ${cached_file} is invalid - removing it from cache."
                sed -i "/${cached_hash}/ d" "${datasets_cache}"
            fi
        else
            # the cached file doesn't exist
            trace "        cached file ${cached_file} doesn't exist - removing it from cache."
            sed -i "/${cached_hash}/ d" "${datasets_cache}"
        fi
    else
        # the dataset doesn't appear in the cache
        trace "        ${dataset_url} not found in cache"
    fi

    # if the dataset was already downloaded (though it might not be in the requested output directory) then use it
    if ${already_downloaded_dataset}
    then
        trace "    using downloaded file ${downloaded_dataset_file}"
        # check if the expected output file exists.
        if [ -f "${dataset_file}" ]
        then
            # the expected output file exists but it may not be the same as the cached file and comparing paths
            # can be tricky (directory hard links etc...) so we'll just compare hashes to determine if it needs replacement.
            trace "        checking pre-existing file ${dataset_file}..."
            existing_file_hash=$(sha1sum "${dataset_file}" | cut -d' ' -f1)

            if [ "${existing_file_hash}" != "${downloaded_dataset_hash}" ]
            then
                # the existing file is corrupt - replace it
                trace "        invalid hash. overriding pre-exisiting file ${dataset_file} (${existing_file_hash}) with cached file ${downloaded_dataset_file}"
                cp "${downloaded_dataset_file}" "${dataset_file}"

                # remove any references to the pre-existing file from the cache
                sed -i "/${existing_file_hash}/ d" "${datasets_cache}"
            else
                # the existing file is valid - let it be.
                trace "        valid hash."
            fi

            # update the cache with the correct path
            trace "        updating cache."
            sed -i "/${downloaded_dataset_hash}/ d" "${datasets_cache}"
            echo "${dataset_url}${CACHE_FIELD_SEPARATOR}${dataset_file}${CACHE_FIELD_SEPARATOR}${downloaded_dataset_hash}" >> ${datasets_cache}

            # next dataset please
            continue
        fi

    else
        # dataset is not listed in the cache in this case
        trace "    dataset not present in cache - proceeding to download it."
    fi

    # make sure that we have the proper decompressor if decompression is needed
    if echo "${dataset_url}" | grep -qiP '\.bz2$' && ! which bzip2 &>/dev/null
    then
        trace "error: can't find bzip2 decompressor - skipping ${dataset_url}"
    fi

    # download the dataset file
    if ! curl -o "${dataset_file}" "${dataset_url}"
    then
        trace "    error: couldn't fetch ${dataset_url}"
        rm -f "${dataset_file}"
        continue
    fi

    # check if decompression is required
    if echo "${dataset_file}" | grep -qiP '\.bz2$'
    then
        trace "    decompressing ${dataset_file}..."
        bzip2 -d "${dataset_file}"
        dataset_file=$(echo "${dataset_file}" | sed -r 's/\.bz2$//gi')
        trace "        -> decompressed to ${dataset_file}"
    fi

    # remove column indicator notation from the datasets as these seem to confuse GNU Octave.
    trace "    removing column indicators from ${dataset_file}..."
    sed -i -r 's/[0-9]+://g' "${dataset_file}"

    # write dataset to cache file
    trace "    adding ${dataset_file} to cache file ${datasets_cache}"
    dataset_hash=$(sha1sum "${dataset_file}" | cut -d' ' -f1)
    echo "${dataset_url}${CACHE_FIELD_SEPARATOR}${dataset_file}${CACHE_FIELD_SEPARATOR}${dataset_hash}" >> ${datasets_cache}

done
