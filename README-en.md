# mtproxy

MTProxyTLS one-click install script



## Discussion

Telegram Group: https://t.me/EllerHK



## Install

Execute the following code to install

```bash
mkdir /home/mtproxy && cd /home/mtproxy
curl -s -o mtproxy.sh https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.sh && chmod +x mtproxy.sh && bash mtproxy.sh
```

 ![mtproxy.sh](https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.jpg)

## Whitelist MTProxy Docker Image

The image integrates nginx and mtproxy+tls to disguise traffic, and uses a white-list mode to deal with firewall detection.

If you use this Docker image, you don't need to use the script, you can choose one of the two, don't mix it up.

```bash
secret=$(head -c 16 /dev/urandom | xxd -ps)
domain="cloudflare.com"
docker run --name nginx-mtproxy -d -e secret="$secret" -e domain="$domain" -p 8080:80 -p 8443:443 ellermister/nginx-mtproxy:latest
```

The image enabled the IP segment whitelist  by default. If you don't need it, you can cancel it:

```bash
docker run --name nginx-mtproxy -d -e secret="$secret" -e domain="$domain" -e ip_white_list="IP" -p 8080:80 -p 8443:443 ellermister/nginx-mtproxy:latest
```

For more usage: https://hub.docker.com/r/ellermister/nginx-mtproxy



## Usage

Start service

```bash
 bash mtproxy.sh start
```

Debug service

```bash
bash mtproxy.sh debug
```

Stop service

```bash
bash mtproxy.sh stop
```

Restart service

```bash
bash mtproxy.sh restart
```



## Uninstall

Just delete the directory where it is located.

```bash
rm -rf /home/mtproxy
```



## Run on Startup

Edit `/etc/rc.local` and add the following code to the script:

```bash
cd /home/mtproxy && bash mtproxy.sh start > /dev/null 2>&1 &
```

## Open Source Used

- https://github.com/TelegramMessenger/MTProxy
- https://github.com/9seconds/mtg
