#!/bin/bash
# Kind of no brain standalone splunk installation

INSTALLDIR=/home/splunk/
mkdir -p "$INSTALLDIR" || exit 1
cd "$INSTALLDIR" || exit 1

# stop a still running splunk
[[ -f ./bin/splunk ]] && ./bin/splunk stop
# clean old install by default
[[ -f README-splunk.txt ]] && rm -rf ./bin/ ./etc/ ./var/ ./include/ ./lib/ ./openssl/ ./share/ license-eula.txt  README-splunk.txt copyright.txt  splunk-*-x86_64-manifest

read version release <<< $(curl -s https://www.splunk.com/en_us/download/sem.html | awk -F\- '/Linux-x86_64.tgz/{print $2" "$3}')
[[ -z "$version" || -z "$release" ]] && exit 1
wget -c https://download.splunk.com/products/splunk/releases/"${version}"/linux/splunk-"${version}"-"${release}"-Linux-x86_64.tgz || exit 1
tar xfz splunk-"${version}"-"${release}"-Linux-x86_64.tgz --strip-components=1
touch ./etc/.ui_login

RANDPASS=$(date +%s | sha256sum | base64 | head -c 20 ; echo)

printf '[user_info]\nUSERNAME = splunkadmin\nPASSWORD = %s\n' "${RANDPASS}" > ./etc/system/local/user-seed.conf
printf '[settings]\nenableSplunkWebSSL = true\n' > ./etc/system/local/web.conf
# if local cert exists 
[[ -f splunk-cert.pem && -f splunk-key.pem ]] && cp splunk-cert.pem ./etc/auth/splunkweb/cert.pem ; cp splunk-key.pem ./etc/auth/splunkweb/privkey.pem 

./bin/splunk start --accept-license --answer-yes --no-prompt 
echo "Have fun, user is splunkadmin and password is ${RANDPASS}"
