#!/bin/bash

# options parsing template from https://stackoverflow.com/a/29754866

# saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail -o noclobber -o nounset

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment. Maybe install it with `brew install gnu-getopt`.'
    exit 1
fi

OPTIONS=d:D:O:vhS
LONGOPTS=domain:,domainsFile:,outputdir:,verbose,help,ssl

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
domain=unset
domainsFile=unset
ssl=false
outDir=./working/scanning

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            echo "Usage: $0 domainsFile"
            exit 0
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -D|--domainsfile)
            domainFile="$2"
            [[ domainsFile == "-" ]] && domainsFile=/dev/stdin
            shift 2
            ;;
        -d|--domain)
            domain="$2"
            shift 2
            ;;
        -O|--outputdir)
            outDir="$2"
            shift 2
            ;;
        -S|--ssl)
            ssl=true
            shift
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

# domainsFile is an (optional) positional argument
if [[ $# -ge 1 ]]; then
    domainsFile=$1
fi

# check that domain or domainsFile is set
if [[ $domainsFile == "unset" ]] && [[ $domain == "unset" ]]; then
    echo "Missing domains to process. Set using -D <file> or -d <domain> options."
    exit 4
fi

#################################################

process_domain () {
    local domain=$1

    # add http/https prefix if needed
    if [[ $domain != *://* ]]; then
        if $ssl; then
            url="https://$domain"
        else
            url="http://$domain"
        fi
    fi

    # nikto
    nikto -h $url -o "$outDir/$domain.txt"
}

mkdir -p $outDir

# process domain
if [[ $domain != "unset" ]]; then
    process_domain $domain
fi

# process domains file
if [[ $domainsFile != "unset" ]]; then
    while read domain; do
        process_domain $domain
    done < $domainsFile
fi
