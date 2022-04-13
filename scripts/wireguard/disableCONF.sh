#!/bin/bash

helpFunc(){
    echo "::: Disable client conf profiles"
    echo ":::"
    echo "::: Usage: pivpn <-off|off> [-h|--help] [-v] [<client-1> ... [<client-2>] ...] "
    echo ":::"
    echo "::: Commands:"
    echo ":::  [none]               Interactive mode"
    echo ":::  <client>             Client"
    echo ":::  -y,--yes             Disable client(s) without confirmation"
    echo ":::  -v                   Show disabled clients only"
    echo ":::  -h,--help            Show this help dialog"
    echo ":::  -co, --config        Use a custom setupVar config"
}

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
        -h|--help)
            helpFunc
            exit 0
            ;;
        -y|--yes)
            CONFIRM=true
            ;;
        -v)
            DISPLAY_DISABLED=true
            ;;
	*)
            CLIENTS_TO_CHANGE+=("$1")
            ;;
    esac
    shift
done

setupVars="/etc/pivpn/wireguard/setupVars.conf"

if [ ! -f "${setupVars}" ]; then
    echo "::: Missing setup vars file!"
    exit 1
fi

# shellcheck disable=SC1090
source "${setupVars}"

cd /etc/wireguard || exit
if [ ! -s configs/clients.txt ]; then
    echo "::: There are no clients to change"
    exit 1
fi


if [ "$DISPLAY_DISABLED" ]; then
    # shellcheck disable=SC2154
    grep '\[disabled\] ### begin' "${pivpnDEV}".conf | sed 's/#//g; s/begin//'
    exit 1
fi


mapfile -t LIST < <(awk '{print $1}' configs/clients.txt)
if [ "${#CLIENTS_TO_CHANGE[@]}" -eq 0 ]; then
    echo -e "::\e[4m  Client list  \e[0m::"
    len=${#LIST[@]}
    COUNTER=1
    while [ $COUNTER -le "${len}" ]; do
        printf "%0${#len}s) %s\r\n" "${COUNTER}" "${LIST[(($COUNTER-1))]}"
        ((COUNTER++))
    done

    read -r -p "Please enter the Index/Name of the Client to be removed from the list above: " CLIENTS_TO_CHANGE

    if [ -z "${CLIENTS_TO_CHANGE}" ]; then
        echo "::: You can not leave this blank!"
        exit 1
    fi
fi

CHANGED_COUNT=0

for CLIENT_NAME in "${CLIENTS_TO_CHANGE[@]}"; do

    re='^[0-9]+$'
    if [[ ${CLIENT_NAME} =~ $re ]] ; then
        CLIENT_NAME=${LIST[$((CLIENT_NAME -1))]}
    fi

    if ! grep -q "^${CLIENT_NAME} " configs/clients.txt; then
        echo -e "::: \e[1m${CLIENT_NAME}\e[0m does not exist"
    elif grep -q "#\[disabled\] ### begin ${CLIENT_NAME}" "${pivpnDEV}".conf; then
        echo -e "::: \e[1m${CLIENT_NAME}\e[0m is already disabled"
    else
        if [ -n "$CONFIRM" ]; then
            REPLY="y"
        else
            read -r -p "Confirm you want to disable $CLIENT_NAME? [Y/n] "
        fi

        if [[ $REPLY =~ ^[Yy]$ ]]; then

            # Disable the peer section from the server config
	    echo "${CLIENT_NAME}"
            sed -e "/### begin ${CLIENT_NAME}/,/end ${CLIENT_NAME}/ s/^/#\[disabled\] /" -i "${pivpnDEV}".conf
            echo "::: Updated server config"

            ((CHANGED_COUNT++))
            echo "::: Successfully disabled ${CLIENT_NAME}"

        fi
    fi

done

# Restart WireGuard only if some clients were actually deleted
if [ "${CHANGED_COUNT}" -gt 0 ]; then
    if systemctl reload wg-quick@"${pivpnDEV}"; then
        echo "::: WireGuard reloaded"
    else
        echo "::: Failed to reload WireGuard"
    fi
fi
