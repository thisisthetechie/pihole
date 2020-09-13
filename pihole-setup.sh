#!/bin/bash

# Option Flags:
#   -i : Server IP (e.g. -f 192.168.0.253)

# Get paramethers
while getopts i: option
do
    case "${option}"
        in
        i) USESERVERIP=${OPTARG};;
    esac
done

# Elevate script
if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Install & Configure Docker from Ubuntu Repositories
if ! command -v docker &> /dev/null
then
    apt update && _
        apt install docker.io -y
fi

if ! getent group docker &> /dev/null
then
    groupadd docker
    gpasswd -a $USER docker
fi

# Download and run PiHole Container
# https://github.com/pi-hole/docker-pi-hole/blob/master/README.md

PIHOLE_BASE="${PIHOLE_BASE:-$(pwd)}"
[[ -d "$PIHOLE_BASE" ]] || mkdir -p "$PIHOLE_BASE" || { echo "Couldn't create storage directory: $PIHOLE_BASE"; exit 1; }

# Note: ServerIP should be replaced with your external ip.
docker run -d \
    --name pihole \
    -p 53:53/tcp -p 53:53/udp \
    -p 80:80 \
    -p 443:443 \
    -e TZ="Europe/London" \
    -v "${PIHOLE_BASE}/etc-pihole/:/etc/pihole/" \
    -v "${PIHOLE_BASE}/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
    --dns=127.0.0.1 --dns=1.1.1.1 \
    --restart=unless-stopped \
    --hostname pi.hole \
    -e VIRTUAL_HOST="pi.hole" \
    -e PROXY_LOCATION="pi.hole" \
    -e ServerIP="${SERVERIP}" \
    pihole/pihole:latest

printf 'Starting up pihole container '
for i in $(seq 1 20); do
    if [ "$(docker inspect -f "{{.State.Health.Status}}" pihole)" == "healthy" ] ; then
        printf ' OK'
        echo -e "\n$(docker logs pihole 2> /dev/null | grep 'password:') for your pi-hole: https://${SERVERIP}/admin/"
        exit 0
    else
        sleep 3
        printf '.'
    fi

    if [ $i -eq 20 ] ; then
        echo -e "\nTimed out waiting for Pi-hole start, consult check your container logs for more info (\`docker logs pihole\`)"
        exit 1
    fi
done;
