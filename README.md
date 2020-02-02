# mtproxy

MTProxyTLS一键安装绿色脚本



## 安装方式

执行如下代码进行安装

```bash
mkdir /home/mtproxy && cd /home/mtproxy
curl -s -o mtproxy.sh https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.sh && chmod +x mtproxy.sh && bash mtproxy.sh
```

 ![mtproxy.sh](https://raw.githubusercontent.com/ellermister/mtproxy/master/mtproxy.jpg)





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

