#!/bin/bash
cd `dirname $0`
WORKDIR=$(cd $(dirname $0); pwd)
pid_file=$WORKDIR/pid/pid_mtproxy

check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

function pid_exists(){
  local exists=`ps aux | awk '{print $2}'| grep -w $1`
  if [[ ! $exists ]]
  then
    return 0;
  else
    return 1;
  fi
}

install(){
  if check_sys packageManager yum; then
    yum install openssl-devel zlib-devel
    yum groupinstall "Development Tools"
  elif check_sys packageManager apt; then
    apt-get -y update
    apt install git curl build-essential libssl-dev zlib1g-dev
  fi

  if [ ! -d 'MTProxy' ];then
    git clone https://github.com/TelegramMessenger/MTProxy
  fi;
  cd MTProxy
  make && cd objs/bin
  cp -f $WORKDIR/MTProxy/objs/bin/mtproto-proxy $WORKDIR
}



config_mtp(){
  cd $WORKDIR
  while true
  do
  default_port=443
  echo -e "请输入一个客户端连接端口 [1-65535]"
  read -p "(默认端口: ${default_port}):" input_port
  [ -z "${input_port}" ] && input_port=${default_port}
  expr ${input_port} + 1 &>/dev/null
  if [ $? -eq 0 ]; then
      if [ ${input_port} -ge 1 ] && [ ${input_port} -le 65535 ] && [ ${input_port:0:1} != 0 ]; then
          echo
          echo "---------------------------"
          echo "port = ${input_port}"
          echo "---------------------------"
          echo
          break
      fi
  fi
  echo -e "[\033[33m错误\033[0m] 请重新输入一个客户端连接端口 [1-65535]"
  done

  # 管理端口
  while true
  do
  default_manage=8888
  echo -e "请输入一个管理端口 [1-65535]"
  read -p "(默认端口: ${default_manage}):" input_manage_port
  [ -z "${input_manage_port}" ] && input_manage_port=${default_manage}
  expr ${input_manage_port} + 1 &>/dev/null
  if [ $? -eq 0 ] && [ $input_manage_port -ne $input_port ]; then
      if [ ${input_manage_port} -ge 1 ] && [ ${input_manage_port} -le 65535 ] && [ ${input_manage_port:0:1} != 0 ]; then
          echo
          echo "---------------------------"
          echo "manage port = ${input_manage_port}"
          echo "---------------------------"
          echo
          break
      fi
  fi
  echo -e "[\033[33m错误\033[0m] 请重新输入一个管理端口 [1-65535]"
  done

  # domain
  while true
  do
  default_domain="azure.microsoft.com"
  echo -e "请输入一个需要伪装的域名："
  read -p "(默认域名: ${default_domain}):" input_domain
  [ -z "${input_domain}" ] && input_domain=${default_domain}
  http_code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} $input_domain)
  echo "状态码：$http_code"
  if [ $http_code -eq "200" ] || [ $http_code -eq "302" ]; then
    echo
    echo "---------------------------"
    echo "伪装域名 = ${input_domain}"
    echo "---------------------------"
    echo
    break
  fi
  echo -e "[\033[33m错误\033[0m] 域名无法访问,请重新输入或更换域名!"
  done

  curl -s https://core.telegram.org/getProxySecret -o proxy-secret
  curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
  secret=$(head -c 16 /dev/urandom | xxd -ps)
  domain_hex=$(xxd -pu <<< $input_domain | sed 's/0a//g')
  client_secret="ee${secret}${domain_hex}"
  cat >./mtp_config <<EOF
#!/bin/bash
secret="${secret}"
port=${input_port}
web_port=${input_manage_port}
domain="${input_domain}"
EOF
  echo -e "配置已经生成完毕!"
}

status_mtp(){
  if [ -f $pid_file ];then
    pid_exists `cat $pid_file`
    if [[ $? == 1 ]];then
      return 1
    fi
  fi
  return 0
}

info_mtp(){
  status_mtp
  if [ $? == 1 ];then
    source ./mtp_config
    public_ip=`curl -s https://api.ip.sb/ip`
    echo -e "TMProxy+TLS代理: \033[32m运行中\033[0m"
    echo -e "服务器IP：\033[31m$public_ip\033[0m"
    echo -e "服务器端口：\033[31m$port\033[0m"
    echo -e "MTProxy Secret:  \033[31m$secret\033[0m"
    echo -e "TG一键链接: https://t.me/proxy?server=${ip}&port=${port}&secret=${secret}"
    echo -e "TG一键链接: tg://proxy?server=${ip}&port=${port}&secret=${secret}"
  else
    public_ip=`curl -s https://api.ip.sb/ip`
    echo -e "TMProxy+TLS代理: \033[33m已停止\033[0m"
  fi
}


run_mtp(){
  cd $WORKDIR
  status_mtp
  if [ $? == 1 ];then
    echo -e "提醒：\033[33mMTProxy已经运行，请勿重复运行!\033[0m"
  else
    source ./mtp_config
    ./mtproto-proxy -u nobody -p $web_port -H $port -S $secret --aes-pwd proxy-secret proxy-multi.conf -M 1 --domain $domain >/dev/null 2>&1 &
    echo $!>$pid_file
    sleep 2
    info_mtp
  fi
}

debug_mtp(){
  cd $WORKDIR
  source ./mtp_config
  echo "当前正在运行调试模式："
  echo -e "\t你随时可以通过 Ctrl+C 进行取消操作"
  echo " ./mtproto-proxy -u nobody -p $web_port -H $port -S $secret --aes-pwd proxy-secret proxy-multi.conf -M 1 --domain $domain"
  ./mtproto-proxy -u nobody -p $web_port -H $port -S $secret --aes-pwd proxy-secret proxy-multi.conf -M 1 --domain $domain
}

stop_mtp(){
  local pid=`cat $pid_file`
  kill -9 $pid
  pid_exists $pid
  if [[ $pid == 1 ]]
  then
    echo "停止任务失败"
  fi
}


param=$1
if [[ "start" == $param ]];then
  echo "即将：启动脚本";
  run_mtp
elif  [[ "stop" == $param ]];then
  echo "即将：停止脚本";
  stop_mtp;
elif  [[ "debug" == $param ]];then
  echo "即将：调试运行";
  debug_mtp;
elif  [[ "restart" == $param ]];then
  stop_mtp
  run_mtp
else
  if [ ! -f "$WORKDIR/mtp_config" ];then
    echo "MTProxyTLS一键安装运行绿色脚本"
    echo "================================="
    config_mtp
    run_mtp
  else
    echo "MTProxyTLS一键安装运行绿色脚本"
    echo "================================="
    info_mtp
    echo "================================="
    echo -e "配置文件: $WORKDIR/mtp_config"
    echo -e "卸载方式：直接删除当前目录下文件即可"
    echo "使用方式:"
    echo -e "\t启动服务 bash $0 start"
    echo -e "\t调试运行 bash $0 debug"
    echo -e "\t停止服务 bash $0 stop"
    echo -e "\t重启服务 bash $0 restart"
  fi
fi
