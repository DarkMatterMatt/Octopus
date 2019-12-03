# The Plan

## TLD Discovery
Output: one file, one domain per line
- **host** `host example.com`

## Subdomain Discovery
Output: one file, one subdomain per line
- **amass** `amass enum -d example.com`
- **subfinder** `subfinder -d example.com`
- **fierce** `fierce -dns example.com`
- **assetfinder** `assetfinder --subs-only example.com`

## Port Scanning
Output: one file per subdomain
- **nmap** `nmap -A -oA outputDir example.com`
- **masscan** `masscan -p 80,443 --banners example.com`

## Web Scanning
Output: one file per subdomain:webport
- **nikto** `nikto -host example.com -port 80`

## Directory Discovery
Output: one file per subdomain:webport
- **gobuster** `gobuster dir -u example.com -w wordlist.txt`
- **dirsearch** `python3 dirsearch.py -u example.com -w wordlist.txt -e extensions.txt`

## Screenshotting
Output: one folder per subdomain:webport
- **aquatone** `cat targets.txt | aquatone`
