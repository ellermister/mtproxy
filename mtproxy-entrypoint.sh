#!/bin/bash
set -e
/usr/sbin/php-fpm7.4 -R
chmod 777 /etc/nginx/ip_white.conf
chmod 777 /run/php/php7.4-fpm.sock

mtp_config="/home/mtproxy/mtp_config"
init_lock="/home/mtproxy/mtp_config.lock"

set_config(){
	if [ "$secret" ] && [[ "$secret" =~ ^[A-Za-z0-9]{32}$ ]]; then
		sed -i 's/secret="[0-9A-Za-z]*"/secret="'$secret'"/' $mtp_config
	fi
	if [ "$tag" ] && [[ "$tag" =~ ^[A-Za-z0-9]{32}$ ]]; then
		sed -i 's/proxy_tag="[0-9A-Za-z]*"/proxy_tag="'$tag'"/' $mtp_config
	fi
	if [ "$domain" ]; then
		sed -i 's/domain="[A-z\.\-\d]*"/domain="'$domain'"/' $mtp_config
	fi
}

if [ ! -f $init_lock ];then
	cp "${mtp_config}.bak" "$mtp_config"
		echo 1>"$init_lock"
	if [ ! "$secret" ]; then
		secret=$(head -c 16 /dev/urandom | xxd -ps)
	fi

	if [ ! "$ip_white_list" ]; then
		ip_white_list='IPSEG'
	fi

	if [ $ip_white_list == "OFF" ]; then
		echo "0.0.0.0/0 1;" >> /etc/nginx/ip_white.conf
	fi

	echo $ip_white_list > /var/ip_white_list
	set_config
fi;

set_config
echo "=================================================="
echo -e "Default port is \033[31m443\033[0m by docker started mtproxy!!!"
echo "=================================================="
cd /home/mtproxy
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
bash /home/mtproxy/mtproxy.sh start
