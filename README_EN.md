<div align="right">
  <a title="简体中文" href="README.md"><img src="https://img.shields.io/badge/-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-545759?style=for-the-badge" alt="简体中文" /></a>
  <a title="English" href="README_EN.md"><img src="https://img.shields.io/badge/-English-A31F34?style=for-the-badge" alt="English"></a>
</div>

# mtproxy

MTProxyTLS one-click install lightweight script.  
With Nginx as a Forward Proxy, access is only granted with an IP whitelist.

## Discussion

Telegram Group: <https://t.me/EllerHK>

## Install method

- Script

  This method generally requires you to install or compile directly on your machine, which may require the installation of some basic system dependency libraries.

- Docker

  **Recommended!** Will not broke your system or dependencies. Just need to know some basic Docker knowledge.

### Script

> If you repeatedly encounter errors or other unknown problems, it is recommended to switch to a Debian 9+ system or use Docker.

Execute the following code to install

```bash
rm -rf /home/mtproxy && mkdir /home/mtproxy && cd /home/mtproxy
curl -fsSL -o mtproxy.sh https://github.com/ellermister/mtproxy/raw/master/mtproxy.sh
bash mtproxy.sh
```

 ![mtproxy.sh](https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.jpg)

### Docker | Whitelist MTProxy Docker Image

The image integrates nginx and mtproxy+tls to disguise traffic, and uses a **white-list** mode to deal with firewall detection.

If you use this Docker image, you don't need to use the script anymore, you can choose one of the two, don't mix it up.

**If you didn't install Docker before**, below is the install script:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

**Start the container with whitelist:**

 ```bash
docker run -d \
--name mtproxy \
--restart=always \
-e domain="cloudflare.com" \
-p 8080:80 \
-p 8443:443 \
ellermister/mtproxy
 ```

**The image enabled the IP segment whitelist by default.**  
If you don't need it, you can cancel it:

```bash
docker run -d \
--name mtproxy \
--restart=always \
-e domain="cloudflare.com" \
-e secret="548593a9c0688f4f7d9d57377897d964" \
-e ip_white_list="OFF" \
-p 8080:80 \
-p 8443:443 \
ellermister/mtproxy
```

`ip_white_list` :

- **OFF** disable whitelist
- **IP** enable IP whitelist
- **IPSEG** enable IPSEG whitelist

`secret`:If you want to create a known key, the format is: 32 hexadecimal characters.

**View the parameter configuration of the link in the log**:

```bash
docker logs -f mtproxy
```

Please change the HOST_PORT which is for the connection, the HOST_PORT in the above example is `8443`.

For more usage: <https://hub.docker.com/r/ellermister/nginx-mtproxy>

## Usage

Configuration file `mtp_config`, pay attention to the format if you want to change secret manually.

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

Reinstall/Reconfigure

```bash
bash mtproxy.sh reinstall
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

## Crontab

Due to the bug in the official mtproxy, there are problems with process processing when the pid is over 65535, and the process is prone to necrosis and abnormal exit.

Therefore, it is recommended to monitor the process through scheduled tasks `crontab -e`:

Check the process and start it every minute

```bash
* * * * * cd /home/mtproxy && bash mtproxy.sh start > /dev/null 2>&1 &
```

## MTProxy Admin Bot

<https://t.me/MTProxybot>
> Sorry, an error has occurred during your request. Please try again later.(Code xxxxxx)

If you encounter such an error when applying for binding agent promotion, the official does not give a clear reason. According to feedback from netizens, such problems mostly occur due to insufficient account registration and 2 to 3 years.  
**It is recommended to use accounts that are more than 3 years old and accounts that have not been banned.**

## Open Source Used

- <https://github.com/TelegramMessenger/MTProxy>
- <https://github.com/9seconds/mtg>
