#!/bin/bash

# template from https://stackoverflow.com/a/29754866

# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment. Maybe install it with `brew install gnu-getopt`.'
    exit 1
fi

OPTIONS=t:o:vh
LONGOPTS=tld:,output:,verbose,help

# -regarding ! and PIPESTATUS see above
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    exit 2
fi
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

# default options
verbose=false
tldFile=unset
outFile=/dev/stdout

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            echo "Usage: $0 basename tldList.txt"
            exit 0
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -t|--tld)
            tldFile="$2"
            [[ tldFile == "-" ]] && tldFile=/dev/stdin
            shift 2
            ;;
        -o|--output)
            outFile="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

# basename is the first positional arguement
if [[ $# -lt 1 ]]; then
    echo "$0: A single basename is required."
    exit 4
fi
basename=$1

# tldFile is the second (optional) positional arguement
if [[ $# -ge 2 ]]; then
    tldFile=$2
fi

# check that tldFile is set
if [[ $tldFile == "unset" ]]; then
    echo "Missing TLD wordlist. Set using -t option."
    exit 5
fi

#################################################

PARKED_CHECK="checking_if_wildcard_parked"

# make output file directory
mkdir -p "${outFile%/*}"

while read ext; do
    # url to test
    hostname="$basename.$ext"

    $verbose && echo "Testing: $hostname" > /dev/stdout

    # check that url has an ip address
    if host $hostname 1>/dev/null 2>&1; then
        # check that the tld isn't wildcard parked
        if ! host "$PARKED_CHECK-$hostname" 1>/dev/null 2>&1; then
            echo $hostname > $outFile
        fi
    fi
done < $tldFile
