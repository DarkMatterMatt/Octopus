#!/bin/bash
set -o errexit

DIR="$(dirname "$(greadlink -f ${BASH_SOURCE[0]} 2>/dev/null || readlink -f ${BASH_SOURCE[0]})")"

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment. Maybe install it with `brew install gnu-getopt`.'
    exit 1
fi

OPTIONS=b:T:d:D:O:p:P:u:U:yvh
LONGOPTS=basedomain:,tldsfile:,domain:,domainsfile:,outputdir:,portscanningdomainsfile:,ports:,portsfile:,udpports:,udpportsfile:,forceyes,verbose,help

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
forceYes=false
baseDomain=unset
domainsFile=unset
portScanningDomainsFile=unset
ports=unset
portsFile=unset
udpPorts=unset
udpPortsFile=unset
tldsFile=unset
outDir=./working

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            echo "Usage: $0 baseDomain"
            exit 0
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -b|--basedomain)
            baseDomain="$2"
            shift 2
            ;;
        -T|--tldsfile)
            tldsFile="$2"
            shift 2
            ;;
        -D|--domainsfile)
            domainsFile="$2"
            [[ domainsFile == "-" ]] && domainsFile=/dev/stdin
            shift 2
            ;;
        --portscanningdomainsfile)
            portScanningDomainsFile="$2"
            [[ portScanningDomainsFile == "-" ]] && portScanningDomainsFile=/dev/stdin
            shift 2
            ;;
        -p|--ports)
            ports="$2"
            shift 2
            ;;
        -P|--portsFile)
            portsFile="$2"
            shift 2
            ;;
        -u|--udpports)
            udpPorts="$2"
            shift 2
            ;;
        -U|--udpportsfile)
            udpPortsFile="$2"
            shift 2
            ;;
        -O|--outputdir)
            outDir="$2"
            shift 2
            ;;
        -y|--forceyes)
            forceYes=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error: uncaught processed arg: $1"
            exit 3
            ;;
    esac
done

# baseDomain is an (optional) positional arguement
if [[ $# -ge 1 ]]; then
    baseDomain=$1
fi

# check that baseDomain or domainsFile is set
if [[ $baseDomain == "unset" ]] && [[ $domainsFile == "unset" ]] && [[ $portScanningDomainsFile == "unset" ]]; then
    echo "You must supply a baseDomain for TLD discovery, a list of domains to find subdomains, or a list of domains to port-scan."
    exit 4
fi

#################################################

prompt() {
    if $forceYes; then
        return 0
    fi

    echo $1
    select yn in "Yes" "No"; do
        case $yn in
            Yes) return 0;;
            No ) return 1;;
        esac
    done
}

# tld discovery
if [[ $baseDomain != "unset" ]]; then
    if [[ $tldsFile == "unset" ]]; then
        echo "Please set --tldsfile"
        exit 5
    fi

    echo "Finding TLDs"
    "$DIR/tld_discovery/tld_discovery.sh" $baseDomain $tldsFile | tee "$outDir/domains.txt"

    if ! prompt "Do you perform subdomain discovery with these domains?"; then
        exit 0
    fi

    domainsFile="$outDir/domains.txt"
    echo "mattm.win" > $domainsFile
fi

# subdomain discovery
if [[ $domainsFile != "unset" ]]; then
    echo "Finding subdomains"
    "$DIR/subdomain_discovery/subdomain_discovery.sh" $domainsFile -o "$outDir/subdomains.txt" -O "$outDir/subdomain_discovery"
    echo "hey1"

    if ! prompt "Do you perform port scanning on these (sub)domains?"; then
        exit 0
    fi
    echo "hey2"
    cat "$outDir/domains.txt" "$outDir/subdomains.txt" > "$outDir/allDomains.txt"
    echo "hey3"
    portScanningDomainsFile="$outDir/allDomains.txt"
    echo "hey4"
fi

if [[ $portScanningDomainsFile != "unset" ]]; then
    echo "Scanning ports"
    "$DIR/port_scanning/port_scanning.sh" $portScanningDomainsFile --ports=$ports --udpports=$udpPorts --portsfile=$portsFile --udpportsfile=$udpPortsFile -O "$outDir/port_scanning"
fi

