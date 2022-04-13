#!/bin/bash
### Constants

### Funcions
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

### Script
cd /etc/wireguard/configs || exit

if [[ ! -s clients.txt ]]; then
  err "::: There are no clients to list"
  exit 1
fi

setupVars="/etc/pivpn/wireguard/setupVars.conf"

# Parse input arguments
while test $# -gt 0
do
    _key="$1"
    case "$_key" in
        -co|--config)
            _val="${_key##--config=}"
            if test "$_val" = "$_key"; then
                test $# -lt 2 && echo "::: Missing value for the optional argument '$_key'." && exit 1
                _val="$2"
                shift
            fi
            setupVars="$_val"
            ;;
    esac
    shift
done

if [ ! -f "${setupVars}" ]; then
    echo "::: Missing setup vars file!"
    exit 1
fi

# shellcheck disable=SC1090
source "${setupVars}"

printf "\e[1m::: Clients Summary :::\e[0m\n"

# Present the user with a summary of the clients, fetching info from dates.
{
  echo -ne "\e[4mClient\e[0m  \t  \e[4mPublic key\e[0m  \t  "
  echo -e "\e[4mCreation date\e[0m"

  while read -r LINE; do
    CLIENT_NAME="$(awk '{print $1}' <<< "${LINE}")"
    PUBLIC_KEY="$(awk '{print $2}' <<< "${LINE}")"
    CREATION_DATE="$(awk '{print $3}' <<< "${LINE}")"
    # Dates are converted from UNIX time to human readable.
    CD_FORMAT="$(date -d @"${CREATION_DATE}" +'%d %b %Y, %H:%M, %Z')"
    echo -e "${CLIENT_NAME}  \t  ${PUBLIC_KEY}  \t  ${CD_FORMAT}"
  done < clients.txt
} | column -t -s $'\t'

cd /etc/wireguard || return

echo "::: Disabled clients :::"
# shellcheck disable=SC2154
grep '\[disabled\] ### begin' "${pivpnDEV}".conf | sed 's/#//g; s/begin//'
