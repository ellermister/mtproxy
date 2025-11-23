#!/bin/bash
set -e
/usr/sbin/php-fpm* -R
chmod 777 /etc/nginx/ip_white.conf
chmod 777 /run/php/php-fpm.sock


config_default_path="/home/mtproxy/config.example"
config_path="/home/mtproxy/config"

function gen_rand_hex() {
    local result=$(dd if=/dev/urandom bs=1 count=500 status=none | od -An -tx1 | tr -d ' \n')
    echo "${result:0:$1}"
}


set_config(){
	if [ "$secret" ] && [[ "$secret" =~ ^[A-Za-z0-9]{32}$ ]]; then
		sed -i 's/secret="[0-9A-Za-z]*"/secret="'$secret'"/' $config_path
	fi
	if [ "$adtag" ] && [[ "$adtag" =~ ^[A-Za-z0-9]{32}$ ]]; then
		sed -i 's/adtag="[0-9A-Za-z]*"/adtag="'$adtag'"/' $config_path
	fi
	if [ "$domain" ]; then
		sed -i 's/domain="[0-9A-z\.\-]*"/domain="'$domain'"/' $config_path
	fi
	if [ "$provider" ] && [[ "$provider" =~ ^[1-3]$ ]]; then
		sed -i 's/provider=[0-9]\+/provider='$provider'/' $config_path
	fi
}

if [ ! -f $config_path ];then
	cp "${config_default_path}" "$config_path"

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
{
	bash /home/mtproxy/mtproxy.sh daemon
} &
