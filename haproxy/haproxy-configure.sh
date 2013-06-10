#!/bin/bash

ROLE_NAME="%role_name%"

if [ "${ROLE_NAME:0:7}" != "haproxy" ]; then
    exit 0
fi

# Can be just hard-coded or check prefix as above
WEBROLE="%web_role_name%"

HACONFIGTMPL="/etc/haproxy/haproxy.cfg.tmpl"

if [ ! -s $HACONFIGTMPL ]; then
	echo "haproxy config template doesn't exist." >&2

	exit 2
fi

if [ ! -x /usr/bin/xmlstarlet ]; then
	apt-get -q -q -y install xmlstarlet
fi

TMP_FILE=`mktemp`

szradm --queryenv listroles > $TMP_FILE

WEBSCOUNT=`xmlstarlet sel -t -v "count(/response/roles/role[@name='$WEBROLE']/hosts/host)" $TMP_FILE`
WEBSLIST=""

for WEBSID in `seq 1 $WEBSCOUNT`; do
	WEBSIP=`xmlstarlet sel -t -v "/response/roles/role[@name='$WEBROLE']/hosts/host[$WEBSID]/@internal-ip" $TMP_FILE`

	[ "$WEBSIP" ] && WEBSLIST="$WEBSLIST $WEBSIP"
done

echo "Web servers: $WEBSLIST"

WEBAPPSERVERS=""
WEBAPPSERVERSSSL=""
IND="1"

for WEBSERVER in $WEBSLIST; do
	WEBAPPSERVERS="$WEBAPPSERVERS\tserver web$IND $WEBSERVER:80 check inter 2000 fall 3\n"
	WEBAPPSERVERSSSL="$WEBAPPSERVERSSSL\tserver web$IND $WEBSERVER:443 check inter 2000 fall 3\n"

	IND=$[ $IND + 1 ]
done

cat $HACONFIGTMPL | sed -e "s/@@WEBAPPSERVERS@@/$WEBAPPSERVERS/g" -e "s/@@WEBAPPSERVERSSSL@@/$WEBAPPSERVERSSSL/g" > /etc/haproxy/haproxy.cfg

rm -f $TMP_FILE

if ! LOG=`/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -D -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid) 2>&1`; then
	echo "Can't restart haproxy: $LOG" >&2

	exit 2
fi

echo "HAproxy configuration successfully updated."
