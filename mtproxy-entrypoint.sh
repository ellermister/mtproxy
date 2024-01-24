#!/bin/bash
set -e
/usr/sbin/php-fpm7.4 -R
chmod 777 /etc/nginx/ip_white.conf
chmod 777 /run/php/php7.4-fpm.sock


default_config="/home/mtproxy/mtp_config.example"
mtp_config="/home/mtproxy/mtp_config"

function gen_rand_hex() {
    local result=$(dd if=/dev/urandom bs=1 count=500 status=none | od -An -tx1 | tr -d ' \n')
    echo "${result:0:$1}"
}


set_config(){
	if [ "$secret" ] && [[ "$secret" =~ ^[A-Za-z0-9]{32}$ ]]; then
		sed -i 's/secret="[0-9A-Za-z]*"/secret="'$secret'"/' $mtp_config
	fi
	if [ "$tag" ] && [[ "$tag" =~ ^[A-Za-z0-9]{32}$ ]]; then
		sed -i 's/proxy_tag="[0-9A-Za-z]*"/proxy_tag="'$tag'"/' $mtp_config
	fi
	if [ "$domain" ]; then
		sed -i 's/domain="[0-9A-z\.\-]*"/domain="'$domain'"/' $mtp_config
	fi
	if [ "$provider" ] && [[ "$provider" =~ ^[1-2]$ ]]; then
		sed -i 's/provider=[0-9]\+/provider='$provider'/' $mtp_config
	fi
}

if [ ! -f $mtp_config ];then
	cp "${default_config}" "$mtp_config"

  # if params is empty, then generate random values
	if [ ! "$secret" ]; then
		secret=$(gen_rand_hex 32)
	fi

	if [ ! "$ip_white_list" ]; then
		ip_white_list='IPSEG'
	fi

	if [ $ip_white_list == "OFF" ]; then
		echo "0.0.0.0/0 1;" >> /etc/nginx/ip_white.conf
	fi

	echo $ip_white_list > /var/ip_white_list
fi;

set_config
echo "=================================================="
echo -e "Default port is \033[31m443\033[0m by docker started mtproxy!!!"
echo "=================================================="
cd /home/mtproxy
bash /home/mtproxy/mtproxy.sh daemon
