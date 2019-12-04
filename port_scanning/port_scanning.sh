#!/bin/bash

# -allow a command to fail with !’s side effect on errexit
# -use return value from ${PIPESTATUS[0]}, because ! hosed $?
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment. Maybe install it with `brew install gnu-getopt`.'
    exit 1
fi

OPTIONS=d:D:O:vhp:P:u:U:
LONGOPTS=domain:,domainsfile:,outputdir:,verbose,help,ports:,portsfile:,udpports:,udpportsfile:,rate:,wait:

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
ports=unset
portsFile=unset
udpPorts=unset
udpPortsFile=unset
masscanRate=500
masscanWait=3

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
        --rate)
            masscanRate="$2"
            shift 2
            ;;
        --wait)
            masscanWait="$2"
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

# check that there are some ports to scan
if [[ $ports == "unset" ]] && [[ $portsFile == "unset" ]] && [[ $udpPorts == "unset" ]] && [[ $udpPortsFile == "unset" ]]; then
    echo "Missing ports to scan."
    exit 5
fi

# load TCP ports from file
if [[ $portsFile != "unset" ]]; then
    ports=$(paste -s -d "," $portsFile)
fi

# load UDP ports from file
if [[ $udpPortsFile != "unset" ]]; then
    udpPorts=$(paste -s -d "," $udpPortsFile)
fi

#################################################

process_domain () {
    local domain=$1
    local dir="$outDir/$domain"
    mkdir -p $dir

    if [[ $domain =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        ip=$domain
    else
        ip=$(host $domain | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
        if [[ $ip == "" ]]; then
            echo "Failed resolving $domain"
            return
        fi
    fi

    # masscan
    [[ $ports != "unset" ]] && masscanTcpPorts="-p $ports" || masscanTcpPorts=""
    [[ $udpPorts != "unset" ]] && masscanUdpPorts="--udp-ports $udpPorts" || masscanUdpPorts=""

    masscan $ip $masscanTcpPorts $masscanUdpPorts --banners --source-port $masscanLocalPort -oG "$dir/masscan.txt" --wait $masscanWait --rate $masscanRate
    cat "$dir/masscan.txt" | grep http       | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/http:\/\/$domain:/"  | tee -a "$outDir/web_servers.txt"
    cat "$dir/masscan.txt" | grep ssl        | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/https:\/\/$domain:/" | tee -a "$outDir/web_servers.txt"
    cat "$dir/masscan.txt" | grep ftp        | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/$domain:/" | tee -a "$outDir/ftp_servers.txt"
    cat "$dir/masscan.txt" | grep ssh        | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/$domain:/" | tee -a "$outDir/ssh_servers.txt"
    cat "$dir/masscan.txt" | grep ' 23'$'\t' | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/$domain:/" | tee -a "$outDir/telnet_servers.txt"
    cat "$dir/masscan.txt" | grep smtp       | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/$domain:/" | tee -a "$outDir/smtp_servers.txt"
    cat "$dir/masscan.txt" | grep ' 53'$'\t' | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/$domain:/" | tee -a "$outDir/dns_servers.txt"
    cat "$dir/masscan.txt" | grep imap       | cut -f 2 | cut -f 2 -d ' ' | sed "s/^/$domain:/" | tee -a "$outDir/imap_servers.txt"

    # nmap
    #nmap -A -oA "$dir" $domain
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
