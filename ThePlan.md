# The Plan

## TLD Discovery
- **getent** `getent hosts example.com`

## Subdomain Discovery
- **amass** `amass enum -d example.com`
- **subfinder** `subfinder -d example.com`

## Port Scanning
- **nmap** `nmap example.com`

### Web Servers

#### Directory Discovery
- **gobuster** `gobuster dir -u example.com -w wordlist.txt`
- **dirsearch** `python3 dirsearch.py -u example.com -w wordlist.txt -e extensions.txt`

##### Screenshotting
- **aquatone** `cat targets.txt | aquatone`
