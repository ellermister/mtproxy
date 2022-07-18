#!/bin/bash
WORKDIR=$(dirname $(readlink -f $0))
cd $WORKDIR
pid_file=$WORKDIR/pid/pid_mtproxy

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

function get_ip_public() {
    public_ip=$(curl -s https://api.ip.sb/ip -A Mozilla --ipv4)
    [ -z "$public_ip" ] && public_ip=$(curl -s ipinfo.io/ip -A Mozilla --ipv4)
    echo $public_ip
}

function get_ip_private() {
    echo $(ip a | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | cut -d "/" -f1 | awk 'NR==1 {print $1}')
}

function get_nat_ip_param() {
    nat_ip=$(get_ip_private)
    public_ip=$(get_ip_public)
    nat_info=""
    if [[ $nat_ip != $public_ip ]]; then
        nat_info="--nat-info ${nat_ip}:${public_ip}"
    fi
    echo $nat_info
}

function get_cpu_core() {
    echo $(cat /proc/cpuinfo | grep "processor" | wc -l)
}

function get_architecture(){
    local architecture=""
    case $(uname -m) in
        i386)   architecture="386" ;;
        i686)   architecture="386" ;;
        x86_64) architecture="amd64" ;;
        arm|aarch64|aarch)    dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="armv6l" ;;
        *)  echo "Unsupported system architecture "$(uname -m) && exit 1 ;;
    esac
    echo $architecture
}

function check_ps_not_install_to_install(){
    if type ps >/dev/null 2>&1; then
        return 1
    else 
        if check_sys packageManager yum; then
            yum install -y procps-ng.x86_64
        elif check_sys packageManager apt; then
            apt-get -y update
            apt install -y procps
        fi
        return 0
    fi
}

function pid_exists() {
    check_ps_not_install_to_install
    local exists=$(ps aux | awk '{print $2}' | grep -w $1)
    if [[ ! $exists ]]; then
        return 0
    else
        return 1
    fi
}


function build_mtproto() {
    cd $WORKDIR
    local platform=$(uname -m)

    if [[ "$platform" == "x86_64" ]];then
        if [ ! -d 'MTProxy' ]; then
            git clone https://github.com/TelegramMessenger/MTProxy --depth=1
        fi
        cd MTProxy
        sed -i 's/CFLAGS\s*=[^\r]\+/& -fcommon\r/' Makefile
        make && cd objs/bin
        cp -f $WORKDIR/MTProxy/objs/bin/mtproto-proxy $WORKDIR
        cd $WORKDIR
    else
        if [[ -f "WORKDIR/mtg" ]];then
            return
        fi

        # golang 
        local arch=$(get_architecture)
        rm -f golang.tar.gz
        #  https://go.dev/dl/go1.18.4.linux-amd64.tar.gz
        local golang_url="https://go.dev/dl/go1.18.4.linux-$arch.tar.gz"
        wget $golang_url -O golang.tar.gz
        rm -rf $WORKDIR/go && tar -C $WORKDIR -xzf golang.tar.gz
        export PATH=$PATH:$WORKDIR/go/bin

        go version
        if [[ $? != 0 ]];then
            local uname_m=$(uname -m)
            local architecture_origin=$(dpkg --print-architecture)
            echo -e "[\033[33mError\033[0m] golang download failed, please check!!! arch: $arch, platform: $platform,  uname: $uname_m, architecture_origin: $architecture_origin download url: $golang_url"
            exit 1
        fi

        rm -rf build-mtg
        git clone https://github.com/9seconds/mtg.git -b v1 build-mtg --depth=1
        cd build-mtg && make static
        
        if [[ ! -f "$WORKDIR/build-mtg/mtg" ]];then
            echo -e "[\033[33mError\033[0m] Build fail for mtg, please check!!! $arch"
            exit 1
        fi

        cp -f $WORKDIR/build-mtg/mtg $WORKDIR && chmod +x $WORKDIR/mtg

        # clean
        rm -rf $WORKDIR/build-mtg  $WORKDIR/golang.tar.gz  $WORKDIR/go
    fi
}

function get_mtg_provider(){
    local arch=$(uname -m)
    if [[ "$arch" == "x86_64" ]];then
        echo "mtproto-proxy"
    else
        echo "mtg"
    fi
}

install() {
    cd $WORKDIR
    if [ ! -d "./pid" ]; then
        mkdir "./pid"
    fi

    xxd_status=1
    echo a | xxd -ps &>/dev/null
    if [ $? != "0" ]; then
        xxd_status=0
    fi

    if [[ "$(uname -m)" != "x86_64" ]]; then
        if check_sys packageManager yum; then
            yum install -y openssl-devel zlib-devel iproute wget
            yum groupinstall -y "Development Tools"
            if [ $xxd_status == 0 ]; then
                yum install -y vim-common
            fi
        elif check_sys packageManager apt; then
            apt-get -y update
            apt install -y git curl build-essential libssl-dev zlib1g-dev iproute2 wget
            if [ $xxd_status == 0 ]; then
                apt install -y vim-common
            fi
        fi
    else
        if check_sys packageManager yum && [ $xxd_status == 0 ]; then
            yum install -y vim-common
        elif check_sys packageManager apt && [ $xxd_status == 0 ]; then
            apt-get -y update
            apt install -y vim-common
        fi
    fi

    if [[ "$(uname -m)" != "x86_64" ]]; then
        build_mtproto
    else
        wget https://github.com/ellermister/mtproxy/releases/download/0.02/mtproto-proxy -O mtproto-proxy -q
        chmod +x mtproto-proxy
    fi
}

print_line() {
    echo -e "========================================="
}

config_mtp() {
    cd $WORKDIR
    echo -e "检测到您的配置文件不存在, 为您指引生成!" && print_line
    while true; do
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
    while true; do
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
    while true; do
        default_domain="azure.microsoft.com"
        echo -e "请输入一个需要伪装的域名："
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
        echo -e "[\033[33m状态码：${http_code}错误\033[0m] 域名无法访问,请重新输入或更换域名!"
    done

    # config info
    public_ip=$(get_ip_public)
    secret=$(head -c 16 /dev/urandom | xxd -ps)

    # proxy tag
    while true; do
        default_tag=""
        echo -e "请输入你需要推广的TAG："
        echo -e "若没有,请联系 @MTProxybot 进一步创建你的TAG, 可能需要信息如下："
        echo -e "IP: ${public_ip}"
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
        echo -e "[\033[33m错误\033[0m] TAG格式不正确!"
    done

    curl -s https://core.telegram.org/getProxySecret -o proxy-secret
    curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
    cat >./mtp_config <<EOF
#!/bin/bash
secret="${secret}"
port=${input_port}
web_port=${input_manage_port}
domain="${input_domain}"
proxy_tag="${input_tag}"
EOF
    echo -e "配置已经生成完毕!"
}

status_mtp() {
    if [ -f $pid_file ]; then
        pid_exists $(cat $pid_file)
        if [[ $? == 1 ]]; then
            return 1
        fi
    fi
    return 0
}

info_mtp() {
    status_mtp
    if [ $? == 1 ]; then
        source ./mtp_config
        public_ip=$(get_ip_public)
        domain_hex=$(xxd -pu <<<$domain | sed 's/0a//g')
        client_secret="ee${secret}${domain_hex}"
        echo -e "TMProxy+TLS代理: \033[32m运行中\033[0m"
        echo -e "服务器IP：\033[31m$public_ip\033[0m"
        echo -e "服务器端口：\033[31m$port\033[0m"
        echo -e "MTProxy Secret:  \033[31m$client_secret\033[0m"
        echo -e "TG一键链接: https://t.me/proxy?server=${public_ip}&port=${port}&secret=${client_secret}"
        echo -e "TG一键链接: tg://proxy?server=${public_ip}&port=${port}&secret=${client_secret}"
    else
        echo -e "TMProxy+TLS代理: \033[33m已停止\033[0m"
    fi
}

run_mtp() {
    cd $WORKDIR
    status_mtp
    if [ $? == 1 ]; then
        echo -e "提醒：\033[33mMTProxy已经运行，请勿重复运行!\033[0m"
    else
        mtg_provider=$(get_mtg_provider)
        source ./mtp_config
        if [[ "$mtg_provider" == "mtg" ]];then
            domain_hex=$(xxd -pu <<<$domain | sed 's/0a//g')
            client_secret="ee${secret}${domain_hex}"
            # ./mtg simple-run -n 1.1.1.1 -t 30s -a 512kib 0.0.0.0:$port $client_secret >/dev/null 2>&1 &
            ./mtg run $client_secret $proxy_tag -b 0.0.0.0:$port --multiplex-per-connection 500 >/dev/null 2>&1 &
        else
            curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf
            nat_info=$(get_nat_ip_param)
            workerman=$(get_cpu_core)
            tag_arg=""
            [[ -n "$proxy_tag" ]] && tag_arg="-P $proxy_tag"
            ./mtproto-proxy -u nobody -p $web_port -H $port -S $secret --aes-pwd proxy-secret proxy-multi.conf -M $workerman $tag_arg --domain $domain $nat_info >/dev/null 2>&1 &    
        fi

        echo $! >$pid_file
        sleep 2
        info_mtp
    fi
}

debug_mtp() {
    cd $WORKDIR
    source ./mtp_config
    nat_info=$(get_nat_ip_param)
    workerman=$(get_cpu_core)
    tag_arg=""
    [[ -n "$proxy_tag" ]] && tag_arg="-P $proxy_tag"
    echo "当前正在运行调试模式："
    echo -e "\t你随时可以通过 Ctrl+C 进行取消操作"
    if [[ "$mtg_provider" == "mtg" ]];then
        domain_hex=$(xxd -pu <<<$domain | sed 's/0a//g')
        client_secret="ee${secret}${domain_hex}"
        #echo " ./mtg simple-run -n 1.1.1.1 -t 30s -a 512kib 0.0.0.0:$port $client_secret"
        #./mtg simple-run -n 1.1.1.1 -t 30s -a 512kib 0.0.0.0:$port $client_secret
        echo " ./mtg run $client_secret $proxy_tag -b 0.0.0.0:$port --multiplex-per-connection 500"
        ./mtg run $client_secret $proxy_tag -b 0.0.0.0:$port --multiplex-per-connection 500
    else
        echo " ./mtproto-proxy -u nobody -p $web_port -H $port -S $secret --aes-pwd proxy-secret proxy-multi.conf -M $workerman $tag_arg --domain $domain $nat_info"
        ./mtproto-proxy -u nobody -p $web_port -H $port -S $secret --aes-pwd proxy-secret proxy-multi.conf -M $workerman $tag_arg --domain $domain $nat_info
    fi
    
}

stop_mtp() {
    local pid=$(cat $pid_file)
    kill -9 $pid
    pid_exists $pid
    if [[ $pid == 1 ]]; then
        echo "停止任务失败"
    fi
}

fix_mtp() {
    if [ $(id -u) != 0 ]; then
        echo -e "> ※ (该功能仅限 root 用户执行)"
        exit 1
    fi

    print_line
    echo -e "> 开始清空防火墙规则/停止防火墙/卸载防火墙..."
    print_line

    if check_sys packageManager yum; then
        systemctl stop firewalld.service
        systemctl disable firewalld.service
        systemctl stop iptables
        systemctl disable iptables
        service stop iptables
        yum remove -y iptables
        yum remove -y firewalld
    elif check_sys packageManager apt; then
        iptables -F
        iptables -t nat -F
        iptables -P ACCEPT
        iptables -t nat -P ACCEPT
        service stop iptables
        apt-get remove -y iptables
        ufw disable
    fi

    print_line
    echo -e "> 开始安装/更新iproute2..."
    print_line

    if check_sys packageManager yum; then
        yum install -y epel-release
        yum update -y
        yum install -y iproute
    elif check_sys packageManager apt; then
        apt-get install -y epel-release
        apt-get update -y
        apt-get install -y iproute2
    fi

    echo -e "< 处理完毕，如有报错忽略即可..."
    echo -e "< 如遇到端口冲突，请自行关闭相关程序"
}

param=$1
if [[ "start" == $param ]]; then
    echo "即将：启动脚本"
    run_mtp
elif [[ "stop" == $param ]]; then
    echo "即将：停止脚本"
    stop_mtp
elif [[ "debug" == $param ]]; then
    echo "即将：调试运行"
    debug_mtp
elif [[ "restart" == $param ]]; then
    stop_mtp
    run_mtp
elif [[ "fix" == $param ]]; then
    fix_mtp
elif [[ "build" == $param ]]; then
    build_mtproto
else
    if [ ! -f "$WORKDIR/mtp_config" ] && [ ! -f "$WORKDIR/mtproto-proxy" ]; then
        echo "MTProxyTLS一键安装运行绿色脚本"
        print_line
        install
        config_mtp
        run_mtp
    else
        [ ! -f "$WORKDIR/mtp_config" ] && config_mtp
        echo "MTProxyTLS一键安装运行绿色脚本"
        print_line
        info_mtp
        print_line
        echo -e "脚本源码：https://github.com/ellermister/mtproxy"
        echo -e "配置文件: $WORKDIR/mtp_config"
        echo -e "卸载方式：直接删除当前目录下文件即可"
        echo "使用方式:"
        echo -e "\t启动服务 bash $0 start"
        echo -e "\t调试运行 bash $0 debug"
        echo -e "\t停止服务 bash $0 stop"
        echo -e "\t重启服务 bash $0 restart"
        echo -e "\t修复常见问题 bash $0 fix"
    fi
fi
