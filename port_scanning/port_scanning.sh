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

OPTIONS=d:D:O:vhp:
LONGOPTS=domain:,domainsfile:,outputdir:,verbose,help,ports

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
outDir=./working/port_scanning
ports=80,81,300,443,591,593,832,981,1010,1311,2082,2087,2095,2096,2480,3000,3128,3333,4243,4567,4711,4712,4993,5000,5104,5108,5800,6543,7000,7396,7474,8000,8001,8008,8014,8042,8069,8080,8081,8088,8090,8091,8118,8123,8172,8222,8243,8280,8281,8333,8443,8500,8834,8880,8888,8983,9000,9043,9060,9080,9090,9091,9200,9443,9800,9981,12443,16080,18091,18092,20720,28017

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
            domainsFile="$2"
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
        -p|--ports)
            ports="$2"
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

# domainsFile is an (optional) positional arguement
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
    local dir="$outDir/$domain"
    mkdir -p $dir

    ip=$(host $domain | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)

    # masscan
    masscan $ip -p $ports --banners --source-port $masscanLocalPort -oG "$dir/masscan.txt" --wait 3
    cat "$dir/masscan.txt" | grep http | grep -o "Port:[^0-9]*[0-9]*" | grep -o "[0-9]*"  | sed -e "s/^/http:\/\/$domain:/"  >> "$outDir/web_servers.txt"
    cat "$dir/masscan.txt" | grep ssl  | grep -o "Port:[^0-9]*[0-9]*" | grep -o "[0-9]*"  | sed -e "s/^/https:\/\/$domain:/" >> "$outDir/web_servers.txt"

    # nmap
    #nmap -A -oA "$dir" $domain

    # check if it is running a web server
    #cat "$dir.gnmap" | grep "http" | cut -f3 -d: | grep -o "[0-9]*" | sed -e "s/^/$domain:/" >> "$outDir/web_servers.txt"
}

# find an unused port for masscan
highestLocalPort=$(cat /proc/sys/net/ipv4/ip_local_port_range | cut -d $'\t' -f 2)
masscanLocalPort=$((highestLocalPort + 1))

# don't process masscan packets
iptables -A INPUT -p tcp --dport $masscanLocalPort -j DROP

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

# undo iptables changes
iptables -D INPUT -p tcp --dport $masscanLocalPort -j DROP
