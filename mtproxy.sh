#!/bin/bash
WORKDIR=$(dirname $(readlink -f $0))
cd $WORKDIR
SYSTEM_ARCH=$(uname -m)
SYSTEM_PYTHON=$(which python3 || which python)

IS_DOCKER=$( [ -f /.dockerenv ] && echo "true" || echo "false" )

PID_FILE=$WORKDIR/pid/pid_mtproxy
CONFIG_PATH=$WORKDIR/config

URL_MTG="https://github.com/ellermister/mtproxy/releases/download/v0.04/$(uname -m)-mtg"
URL_MTPROTO="https://github.com/ellermister/mtproxy/releases/download/v0.04/mtproto-proxy"
URL_PY_MTPROTOPROXY="https://github.com/alexbers/mtprotoproxy/archive/refs/heads/master.zip"
BINARY_MTG_PATH=$WORKDIR/bin/mtg
BINARY_MTPROTO_PROXY_PATH=$WORKDIR/bin/mtproto-proxy
BINARY_PY_MTPROTOPROXY_PATH=$WORKDIR/bin/mtprotoproxy.py

PUBLIC_IP=""


check_sys() {
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

function abs() {
    echo ${1#-};
}

function get_ip_public() {
    local public_ip=""

    # 尝试 Cloudflare trace API
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -4 -s --connect-timeout 5 --max-time 10 https://1.1.1.1/cdn-cgi/trace -A Mozilla 2>/dev/null | grep "^ip=" | cut -d'=' -f2)
    fi
    
    # 尝试 ip.sb API获取公网IP
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s --connect-timeout 5 --max-time 10 https://api.ip.sb/ip -A Mozilla --ipv4 2>/dev/null)
    fi
    
    # 尝试 ipinfo.io API
    if [ -z "$public_ip" ]; then
        public_ip=$(curl -s --connect-timeout 5 --max-time 10 https://ipinfo.io/ip -A Mozilla --ipv4 2>/dev/null)
    fi
    
    # 如果所有API都失败，退出
    if [ -z "$public_ip" ]; then
        print_error_exit "Failed to get public IP address. Please check your network connection."
    fi
    echo "$public_ip"
}

function get_ip_private() {
    echo $(ip a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | cut -d "/" -f1 | awk 'NR==1 {print $1}')
}

function get_local_ip(){
  ip a | grep inet | grep 127.0.0.1 > /dev/null 2>&1
  if [[ $? -eq 1 ]];then
    echo $(get_ip_private)
  else
    echo "127.0.0.1"
  fi
}

function get_nat_ip_param() {
    nat_ip=$(get_ip_private)
    nat_info=""
    if [[ $nat_ip != $PUBLIC_IP ]]; then
        nat_info="--nat-info ${nat_ip}:${PUBLIC_IP}"
    fi
    echo $nat_info
}

function get_cpu_core() {
    echo $(cat /proc/cpuinfo | grep "processor" | wc -l)
}

function get_architecture() {
    local architecture=""
    case $(uname -m) in
    i386) architecture="386" ;;
    i686) architecture="386" ;;
    x86_64) architecture="amd64" ;;
    arm | aarch64 | aarch) dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="armv6l" ;;
    *) echo "Unsupported system architecture "$(uname -m) && exit 1 ;;
    esac
    echo $architecture
}

function build_mtproto() {
    cd $WORKDIR

    local platform=$(uname -m)
    if [[ -z "$1" ]]; then
        print_error_exit "缺少参数"
    fi

    do_install_build_dep

    rm -rf build
    mkdir build && cd build

    if [[ "1" == "$1" ]]; then
         if [ -d 'MTProxy' ]; then
            rm -rf 'MTProxy'
        fi

        git clone https://github.com/ellermister/MTProxyC --depth=1 MTProxy
        cd MTProxy && make && cd objs/bin &&  chmod +x mtproto-proxy

        if [ ! -f "./mtproto-proxy" ]; then
            print_error_exit "mtproto-proxy 编译失败"
        fi

        cp -f mtproto-proxy $WORKDIR
        

        # clean
        rm -rf 'MTProxy'

    elif [[ "2" == "$1" ]]; then
        # golang
        local arch=$(get_architecture)

        #  https://go.dev/dl/go1.18.4.linux-amd64.tar.gz
        local golang_url="https://go.dev/dl/go1.18.4.linux-$arch.tar.gz"
        wget $golang_url -O golang.tar.gz
        rm -rf go && tar -C . -xzf golang.tar.gz
        export PATH=$PATH:$(pwd)/go/bin

        go version
        if [[ $? != 0 ]]; then
            local uname_m=$(uname -m)
            local architecture_origin=$(dpkg --print-architecture)
            print_error_exit "golang download failed, please check!!! arch: $arch, platform: $platform,  uname: $uname_m, architecture_origin: $architecture_origin download url: $golang_url"
        fi

        rm -rf build-mtg
        git clone https://github.com/9seconds/mtg.git -b v1 build-mtg
        cd build-mtg && git reset --hard 9d67414db633dded5f11d549eb80617dc6abb2c3  && make static

        if [[ ! -f "./mtg" ]]; then
            print_error_exit "Build fail for mtg, please check!!! $arch"
        fi

        cp -f mtg $WORKDIR && chmod +x $WORKDIR/mtg
    fi

    # clean
    cd $WORKDIR
    rm -rf build

}

function get_mtg_provider() {
    source $CONFIG_PATH

    local arch=$(get_architecture)
    if [[ "$arch" != "amd64" && $provider -eq 1 ]]; then
        provider=2
    fi

    if [ $provider -eq 1 ]; then
        echo "official-MTProxy"
    elif [ $provider -eq 2 ]; then
        echo "mtg"
    elif [ $provider -eq 3 ]; then
        echo "python-mtprotoproxy"
    else
        print_error_exit "Invalid configuration, please reinstall"
    fi
}

function is_installed() {
    if [ ! -f "$CONFIG_PATH" ]; then
        return 1
    fi
    return 0
}


function kill_process_by_port() {
    pids=$(get_pids_by_port $1)
    if [ -n "$pids" ]; then
        kill -9 $pids
    fi
}

function get_pids_by_port() {
    echo $(netstat -tulpn 2>/dev/null | grep ":$1 " | awk '{print $7}' | sed 's|/.*||')
}

function is_port_open() {
    pids=$(get_pids_by_port $1)

    if [ -n "$pids" ]; then
        return 0
    else
        return 1
    fi
}


function is_running_mtp() {
    if [ -f $PID_FILE ]; then

        if is_pid_exists $(cat $PID_FILE); then
            return 0
        fi
    fi
    return 1
}

function is_pid_exists() {
    # check_ps_not_install_to_install
    local exists=$(ps aux | awk '{print $2}' | grep -w $1)
    if [[ ! $exists ]]; then
        return 1
    else
        return 0
    fi
}

do_install_proxy() {
    local mtg_provider=$1

    if [ ! -d "$WORKDIR/bin" ]; then
        mkdir -p $WORKDIR/bin
    fi

    if [[ "$mtg_provider" == "mtg" ]]; then
        wget $URL_MTG -O $BINARY_MTG_PATH -q
        chmod +x $BINARY_MTG_PATH
        $BINARY_MTG_PATH
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
            print_error_exit "Install mtg failed"
        fi
        print_info "Installed for mtg"
    elif [[ "$mtg_provider" == "official-MTProxy" ]]; then
        wget $URL_MTPROTO -O $BINARY_MTPROTO_PROXY_PATH -q
        chmod +x $BINARY_MTPROTO_PROXY_PATH
        $BINARY_MTPROTO_PROXY_PATH
        exit_code=$?
        if [ $exit_code -ne 0 ] && [ $exit_code -ne 2 ]; then
            print_error_exit "Install mtproto-proxy failed"
        fi
        print_info "Installed for mtproto-proxy"
    
    elif [[ "$mtg_provider" == "python-mtprotoproxy" ]]; then
        wget $URL_PY_MTPROTOPROXY -O mtprotoproxy-master.zip
        unzip mtprotoproxy-master.zip
        cp -rf mtprotoproxy-master/*.py mtprotoproxy-master/pyaes $WORKDIR/bin/
        rm -rf mtprotoproxy-master mtprotoproxy-master.zip
        print_info "Installed for mtprotoproxy"
    fi
}

do_install() {
    cd $WORKDIR

    mtg_provider=$(get_mtg_provider)

    do_install_proxy $mtg_provider

    if [ ! -d "./pid" ]; then
        mkdir "./pid"
    fi
}

print_line() {
    echo -e "========================================="
}

print_error_exit() {
    print_line
    echo -e "[\033[95mERROR\033[0m] $1"
    print_line
    exit 1
}

print_warning() {
    echo -e "[\033[33mWARNING\033[0m] $1"
}

print_info() {
    echo -e "[\033[32mINFO\033[0m] $1"
}

print_subject() {
    echo -e "\n\033[32m> $1\033[0m"
}


do_kill_process() {
    cd $WORKDIR
    if [ ! -f "$CONFIG_PATH" ]; then
        print_error_exit "配置文件不存在,请重新安装"
    fi
    source $CONFIG_PATH

    if is_port_open $port; then
        print_info "Detected port $port is occupied, preparing to kill process!"
        kill_process_by_port $port
    fi
    
    if is_port_open $statport; then
        print_info "Detected port $statport is occupied, preparing to kill process!"
        kill_process_by_port $statport
    fi
}

do_check_system_datetime_and_update() {
    dateFromLocal=$(date +%s)
    dateFromServer=$(date -d "$(curl -v --silent ip.sb 2>&1 | grep Date | sed -e 's/< Date: //')" +%s)
    offset=$(abs $(( "$dateFromServer" - "$dateFromLocal")))
    tolerance=60
    if [ "$offset" -gt "$tolerance" ];then
        print_info "Detected system time is not synchronized with world time, preparing to update"
        ntpdate -u time.google.com
        if [ $? -ne 0 ]; then
            if [[ "$IS_DOCKER" == "true" ]]; then
                print_warning "Update system time failed, please manually update the system time"
            else
                print_error_exit "Update system time failed, please manually update the system time"
            fi
        fi
    fi
}

do_install_basic_dep() {
    print_info "Checking and installing basic dependencies..."
    if check_sys packageManager yum; then
        yum update && yum install -y iproute curl wget procps-ng.x86_64 net-tools ntp
    elif check_sys packageManager apt; then
        apt update
        # 先安装必需的包
        apt install -y iproute2 curl wget procps net-tools unzip || true
        # 尝试安装时间同步工具（可选，允许失败）
        apt install -y ntpsec-ntpdate 2>/dev/null || apt install -y ntpdate 2>/dev/null || true
    fi

    return 0
}

do_install_build_dep() {
    print_info "Checking and installing build dependencies..."
    if check_sys packageManager yum; then
        yum install -y git  openssl-devel zlib-devel
        yum groupinstall -y "Development Tools"
    elif check_sys packageManager apt; then
        apt install -y git curl  build-essential libssl-dev zlib1g-dev
    fi
    return 0
}

do_config_mtp() {
    cd $WORKDIR

    while true; do
        default_provider=1
        print_subject "请输入要安装的程序版本"
        echo ""
        
        if [ "$SYSTEM_ARCH" == "x86_64" ]; then
            echo -e "  \033[36m1.\033[0m MTProxy (TelegramMessenger)"
            echo -e "     └─ Telegram官方版本,只支持 x86_64, 存在很多问题"
        else
            echo -e "  \033[90m1.\033[0mMTProxy (TelegramMessenger) \033[33m[不支持当前架构]\033[0m"
            echo -e "     └─ Telegram官方版本,只支持 x86_64, 存在很多问题"
        fi
        
        echo -e "  \033[36m2.\033[0m mtg (9seconds)"
        echo -e "     └─ Golang 版本, 兼容性强, 推荐使用"
        
        echo -e "  \033[36m3.\033[0m mtprotoproxy (alexbers)"
        echo -e "     └─ Python 版本, 兼容性强"
        echo ""

        [ "$SYSTEM_ARCH" != "x86_64" ] && default_provider=2

        read -p "(默认版本: ${default_provider}):" input_provider
        [ -z "${input_provider}" ] && input_provider=${default_provider}
        expr ${input_provider} + 1 &>/dev/null
        if [ $? -eq 0 ]; then
            [ "$SYSTEM_ARCH" != "x86_64" ] && [ ${input_provider} -eq 1 ] && print_warning "你的系统不支持该版本, 请重新输入" && continue
            if [ ${input_provider} -ge 1 ] && [ ${input_provider} -le 3 ] && [ ${input_provider:0:1} != 0 ]; then
                echo
                echo "---------------------------"
                echo "provider = ${input_provider}"
                echo "---------------------------"
                echo
                break
            fi
        fi
        print_warning "请重新输入程序版本 [1-3]"
    done

    while true; do
        default_port=443
        print_subject "请输入一个客户端连接端口 [1-65535]"
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
        print_warning "请重新输入一个客户端连接端口 [1-65535]"
    done

    # 管理端口
    while true; do
        default_manage=8888
        print_subject "请输入一个管理端口 [1-65535]"
        echo -e "管理端口仅用于查看一些统计数据, 只监听本地网卡不会对外暴露"
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
        print_warning "请重新输入一个管理端口 [1-65535]"
    done

    # domain
    while true; do
        default_domain="azure.microsoft.com"
        print_subject "请输入一个需要伪装的域名："
        read -p "(默认域名: ${default_domain}):" input_domain
        [ -z "${input_domain}" ] && input_domain=${default_domain}
        http_code=$(curl -I -m 10 -o /dev/null -s -w %{http_code} $input_domain)
        if [ $http_code -eq "200" ] || [ $http_code -eq "302" ] || [ $http_code -eq "301" ]; then
            echo
            echo "---------------------------"
            echo "伪装域名 = ${input_domain}"
            echo "---------------------------"
            echo
            break
        fi
        print_warning "域名无法访问,请重新输入或更换域名!"
    done

    # config info
    secret=$(gen_rand_hex 32)

    # proxy tag
    while true; do
        default_tag=""
        print_subject "请输入你需要推广的TAG："
        echo -e "若没有,请联系 @MTProxybot 进一步创建你的TAG, 可能需要信息如下："
        echo -e "IP: ${PUBLIC_IP}"
        echo -e "PORT: ${input_port}"
        echo -e "SECRET(可以随便填): ${secret}"
        read -p "(留空则跳过):" input_tag
        [ -z "${input_tag}" ] && input_tag=${default_tag}
        if [ -z "$input_tag" ] || [[ "$input_tag" =~ ^[A-Za-z0-9]{32}$ ]]; then
            echo
            echo "---------------------------"
            echo "PROXY TAG = ${input_tag}"
            echo "---------------------------"
            echo
            break
        fi
        print_warning "TAG格式不正确!"
    done

    cat >$CONFIG_PATH <<EOF
#!/bin/bash
secret="${secret}"
port=${input_port}
statport=${input_manage_port}
domain="${input_domain}"
adtag="${input_tag}"
provider=${input_provider}
EOF
    print_info "配置已经生成完毕!"
}

function str_to_hex() {
    string=$1
    hex=$(printf "%s" "$string" | od -An -tx1 | tr -d ' \n')
    echo $hex
}

function gen_rand_hex() {
    local result=$(dd if=/dev/urandom bs=1 count=500 status=none | od -An -tx1 | tr -d ' \n')
    echo "${result:0:$1}"
}

info_mtp() {
    if [[ "$1" == "ingore" ]] || is_running_mtp; then
        source $CONFIG_PATH

        domain_hex=$(str_to_hex $domain)

        client_secret="ee${secret}${domain_hex}"
        echo -e "TMProxy+TLS代理: \033[32m运行中\033[0m"
        echo -e "服务器IP：\033[31m$PUBLIC_IP\033[0m"
        echo -e "服务器端口：\033[31m$port\033[0m"
        echo -e "MTProxy Secret:  \033[31m$client_secret\033[0m"
        echo -e "TG一键链接: https://t.me/proxy?server=${PUBLIC_IP}&port=${port}&secret=${client_secret}"
        echo -e "TG一键链接: tg://proxy?server=${PUBLIC_IP}&port=${port}&secret=${client_secret}"
    else
        echo -e "TMProxy+TLS代理: \033[33m已停止\033[0m"
    fi
}

function get_run_command(){
  cd $WORKDIR
  mtg_provider=$(get_mtg_provider)
  source $CONFIG_PATH
  if [[ "$mtg_provider" == "mtg" ]]; then
      domain_hex=$(str_to_hex $domain)
      client_secret="ee${secret}${domain_hex}"
      local local_ip=$(get_local_ip)
      
      # ./mtg simple-run -n 1.1.1.1 -t 30s -a 512kib 0.0.0.0:$port $client_secret >/dev/null 2>&1 &
      [[ -f "$BINARY_MTG_PATH" ]] || (print_warning "MTProxy 代理程序不存在请重新安装!" && exit 1)
      echo "$BINARY_MTG_PATH run $client_secret $adtag -b 0.0.0.0:$port --multiplex-per-connection 500 --prefer-ip=ipv4 -t $local_ip:$statport" -4 "$PUBLIC_IP:$port"
  elif [[ "$mtg_provider" == "python-mtprotoproxy" ]]; then
        cat >$WORKDIR/bin/config.py <<EOF
PORT = ${port}
USERS = {
    "tg":  "${secret}",
}
MODES = {
    "classic": False,
    "secure": False,
    "tls": True
}
TLS_DOMAIN = "${domain}"
AD_TAG = "${adtag}"
EOF
      echo "$SYSTEM_PYTHON $BINARY_PY_MTPROTOPROXY_PATH $WORKDIR/bin/config.py"
  elif [[ "$mtg_provider" == "official-MTProxy" ]]; then
      curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
      curl -s https://core.telegram.org/getProxySecret -o proxy-secret
      nat_info=$(get_nat_ip_param)
      workerman=$(get_cpu_core)
      tag_arg=""
      [[ -n "$adtag" ]] && tag_arg="-P $adtag"
      echo "$BINARY_MTPROTO_PROXY_PATH -u nobody -p $statport -H $port -S $secret --aes-pwd proxy-secret proxy-multi.conf -M $workerman $tag_arg --domain $domain $nat_info --ipv6"
  else
      print_warning "Invalid configuration, please reinstall"
      exit 1
  fi
}

run_mtp() {
    cd $WORKDIR

    if is_running_mtp; then
        print_warning "MTProxy已经运行，请勿重复运行!"
    else
        do_kill_process
        do_check_system_datetime_and_update

        local command=$(get_run_command)
        echo $command
        $command >/dev/null 2>&1 &

        echo $! >$PID_FILE
        sleep 2
        info_mtp
    fi
}


daemon_mtp() {
    cd $WORKDIR

    if is_running_mtp; then
        print_warning "MTProxy已经运行，请勿重复运行!"
    else
        do_kill_process
        do_check_system_datetime_and_update

        local command=$(get_run_command)
        echo $command
        while true
        do
            {
                sleep 2
                info_mtp "ingore"
            } &
            $command >/dev/null 2>&1
            print_warning "进程检测到被关闭,正在重启中!!!"
            sleep 2
        done
    fi
}

debug_mtp() {
    cd $WORKDIR

    print_info "当前正在运行调试模式："
    print_warning "\t你随时可以通过 Ctrl+C 进行取消操作"

    do_kill_process
    do_check_system_datetime_and_update

    local command=$(get_run_command)
    echo $command
    $command

}

stop_mtp() {
    local pid=$(cat $PID_FILE)
    kill -9 $pid

    if is_pid_exists $pid; then
        print_warning "停止任务失败"
    fi
}

reinstall_mtp() {
    cd $WORKDIR
    if [ -f "$CONFIG_PATH" ]; then
        while true; do
            default_keep_config="y"
            print_subject "是否保留配置文件? "
            read -p "y: 保留 , n: 不保留 (默认: ${default_keep_config}):" input_keep_config
            [ -z "${input_keep_config}" ] && input_keep_config=${default_keep_config}

            if [[ "$input_keep_config" == "y" ]] || [[ "$input_keep_config" == "n" ]]; then
                if [[ "$input_keep_config" == "n" ]]; then
                    rm -f $CONFIG_PATH
                fi
                break
            fi
            print_warning "输入错误， 请输入 y / n"
        done
    fi

    if [ ! -f "$CONFIG_PATH" ]; then 
        do_install_basic_dep
        do_config_mtp
    fi

    do_install
    run_mtp
}

param=$1

if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(get_ip_public) || print_error_exit "Failed to get public IP address. Please check your network connection."
fi

if [[ "start" == $param ]]; then
    print_info "即将：启动脚本"
    run_mtp
elif [[ "daemon" == $param ]]; then
    print_info "即将：启动脚本(守护进程)"
    daemon_mtp
elif [[ "stop" == $param ]]; then
    print_info "即将：停止脚本"
    stop_mtp
elif [[ "debug" == $param ]]; then
    print_info "即将：调试运行"
    debug_mtp
elif [[ "restart" == $param ]]; then
    stop_mtp
    run_mtp
elif [[ "reinstall" == $param ]]; then
    reinstall_mtp
elif [[ "build" == $param ]]; then
    do_install_proxy "python-mtprotoproxy"
    exit 0
    arch=$(get_architecture)
    if [[ "$arch" == "amd64" ]]; then
        # build_mtproto 1
        do_install_proxy "official-MTProxy"
    fi
    
    # build_mtproto 2
    do_install_proxy "mtg"
    do_install_proxy "python-mtprotoproxy"
else
    if ! is_installed; then
        echo "MTProxyTLS一键安装运行绿色脚本"
        print_line
        print_warning "检测到您的配置文件不存在, 为您指引生成!" && print_line

        do_install_basic_dep
        do_config_mtp
        do_install
        run_mtp
    else
        [ ! -f "$CONFIG_PATH" ] && do_config_mtp
        echo "MTProxyTLS一键安装运行绿色脚本"
        print_line
        info_mtp
        print_line
        echo -e "脚本源码：https://github.com/ellermister/mtproxy"
        echo -e "配置文件: $CONFIG_PATH"
        echo -e "卸载方式：直接删除当前目录下文件即可"
        echo "使用方式:"
        echo -e "\t启动服务\t bash $0 start"
        echo -e "\t调试运行\t bash $0 debug"
        echo -e "\t停止服务\t bash $0 stop"
        echo -e "\t重启服务\t bash $0 restart"
        echo -e "\t重新安装代理程序 bash $0 reinstall"
    fi
fi
