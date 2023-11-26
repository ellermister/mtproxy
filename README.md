# mtproxy

这是一个一键安装 MTProxy 代理的绿色脚本，脚本可以在官方版本的 MTProxy 程序和兼容性最强的第三方作者开发的 mtg 程序中进行选择静态安装或者编译，该版本默认支持 Fake TLS 以及 AdTag 配置。

在此基础上，提供了 Nginx 作为前端转发，MTProxy 作为后端代理的方式以实现安全的伪装，并且在 nginx 转发层进行配置了 IP 白名单，只有通过白名单认证过的 IP 才可以进行访问，此功能提供了 Docker 镜像以便开箱即用。

 [English](README-en.md)

## 交流群组

Telegram 群组：https://t.me/EllerHK

## 安装方式

提供了两种安装方式可供选择：

- 使用脚本 

  选择该方式一般是你在宿主机中进行直接安装或者编译，会或多或少需要安装一些系统基础依赖库。

- 使用 Docker

  **小白建议使用 Docker!** 不会对宿主机造成污染，如果你需要修改一些配置文件，需要你稍微学习一些基础Docker 使用技术。

### 使用脚本

> 如果你反复遇到段错误或者其他未知问题, 建议更换为 Debian 9+ 以上的系统或采用 Docker 方式运行.

执行如下代码进行安装

```bash
rm -rf /home/mtproxy && mkdir /home/mtproxy && cd /home/mtproxy
curl -sL -o mtproxy.sh https://github.com/ellermister/mtproxy/raw/master/mtproxy.sh
bash mtproxy.sh
```

 ![mtproxy.sh](https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.jpg)

### 使用Docker | 白名单 MTProxy Docker 镜像

The image integrates nginx and mtproxy+tls to disguise traffic, and uses a whitelist mode to deal with firewall detection.

该镜像集成了 nginx、mtproxy+tls 实现对流量的伪装，并采用**白名单**模式来应对防火墙的检测。

If you use this Docker image, you don't need to use the script, you can choose one of the two, don't mix it up.

若使用该 Docker 镜像, 就不需要用脚本了，二者二选一，不要搞混了。

**如果没有安装Docker**，一键安装方式：

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

**创建白名单镜像：**

 ```bash
docker run -d \
--name mtproxy \
--restart=always \
-e domain="cloudflare.com" \
-p 8080:80 \
-p 8443:443 \
ellermister/mtproxy
 ```
**镜像默认开启了 IP 段白名单**，如果你不需要可以配置 `ip_white_list="OFF"` 取消：

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

`ip_white_list` 选项:

- **OFF**  关闭白名单
- **IP** 开启 IP 白名单
- **IPSEG** 开启 IP 段白名单

`secret`指定密钥：如果你想创建已知的密钥，格式为：32位十六进制字符。

**在日志中查看链接的参数配置**：

```bash
docker logs -f mtproxy
```

连接端口记得修改为你映射后的外部端口，如上文例子中都是`8443`，在连接时修改端口。

更多使用请参考： https://hub.docker.com/r/ellermister/mtproxy

## 使用方式

运行服务

```bash
bash mtproxy.sh start
```

调试运行

```bash
bash mtproxy.sh debug
```

停止服务

```bash
bash mtproxy.sh stop
```

重启服务

```bash
bash mtproxy.sh restart
```

## 卸载安装

因为是绿色版卸载极其简单，直接删除所在目录即可。

```bash
rm -rf /home/mtproxy
```

## 开机启动

> 该脚本没有配置为系统服务的方式，你可以将其添加到开机启动脚本中。

开机启动脚本，如果你的 rc.local 文件不存在请检查开机自启服务。

通过编辑文件`/etc/rc.local`将如下代码加入到开机自启脚本中：

```bash
cd /home/mtproxy && bash mtproxy.sh start > /dev/null 2>&1 &
```

## 引用项目

- https://github.com/TelegramMessenger/MTProxy
- https://github.com/9seconds/mtg


