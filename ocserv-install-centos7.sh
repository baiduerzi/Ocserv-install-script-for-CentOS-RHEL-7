#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

####################################################
#                                                  #
# This is a ocserv installation for CentOS 7       #
# Version: 0.1.3 2017-02-03
# Author: Travis Lee                               #
# Website: https://www.stunnel.info                #
#                                                  #
####################################################

#sh_ver="1.1.3"
#file="/usr/local/sbin/ocserv"
confdir="/etc/ocserv"
conf="/etc/ocserv/ocserv.conf"
#passwd_file="/etc/ocserv/ocpasswd"
log_file="/tmp/ocserv.log"
#ocserv_ver="1.0.0"
#PID_FILE="/var/run/ocserv.pid"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"


# 检测是否是root用户
if [[ $(id -u) != "0" ]]; then
    printf "\e[42m\e[31mError: You must be root to run this install script.\e[0m\n"
    exit 1
fi

# 检测是否是CentOS 7或者RHEL 7
if [[ $(grep "release 7." /etc/redhat-release 2>/dev/null | wc -l) -eq 0 ]]; then
    printf "\e[42m\e[31mError: Your OS is NOT CentOS 7 or RHEL 7.\e[0m\n"
    printf "\e[42m\e[31mThis install script is ONLY for CentOS 7 and RHEL 7.\e[0m\n"
    exit 1
fi



function ConfigEnvironmentVariable {
    #ocserv版本
    ocserv_version="1.0.0"
    version=${1-${ocserv_version}}
    libtasn1_version=4.16.0	
	# 变量设置				 
    # 单IP最大连接数，默认是2
    maxsameclients=10
    # 最大连接数，默认是16
    maxclients=1024
    # 服务器的证书和key文件，放在本脚本的同目录下，key文件的权限应该是600或者400
    servercert=${1-server-cert.pem}
    serverkey=${2-server-key.pem}
    # VPN 内网 IP 段
    vpnnetwork="192.168.8.0/21"
    # DNS
    dns1="8.8.8.8"
    dns2="8.8.4.4"
    # 配置目录
    confdir="/etc/ocserv"

    #安装系统组件
    yum install -y -q net-tools NetworkManager bind-utils
    # 获取网卡接口名称
    systemctl start NetworkManager.service
    ethlist=$(nmcli --nocheck d | grep -v -E "(^(DEVICE|lo)|unavailable|^[^e])" | awk '{print $1}')
	eth=$(printf "${ethlist}\n" | head -n 1)
    if [[ $(printf "${ethlist}\n" | wc -l) -gt 1 ]]; then
        echo ======================================
        echo "Network Interface list:"
        printf "\e[33m${ethlist}\e[0m\n"
        echo ======================================
        echo "Which network interface you want to listen for ocserv?"
        printf "Default network interface is \e[33m${eth}\e[0m, let it blank to use this network interface: "
        read ethtmp
        if [[ -n "${ethtmp}" ]]; then
            eth=${ethtmp}
        fi
    fi

    # 端口，默认是443
    port=443
    echo -e "\nPlease input the port ocserv listen to."
    printf "Default port is \e[33m${port}\e[0m, let it blank to use this port: "
    read porttmp
    if [[ -n "${porttmp}" ]]; then
        port=${porttmp}
    fi

    # 用户名，默认是user
    username=user
    echo -e "\nPlease input ocserv user name."
    printf "Default user name is \e[33m${username}\e[0m, let it blank to use this user name: "
    read usernametmp
    if [[ -n "${usernametmp}" ]]; then
        username=${usernametmp}
    fi

    # 随机密码
    randstr() {
        index=0
        str=""
        for i in {a..z}; do arr[index]=$i; index=$(expr ${index} + 1); done
        for i in {A..Z}; do arr[index]=$i; index=$(expr ${index} + 1); done
        for i in {0..9}; do arr[index]=$i; index=$(expr ${index} + 1); done
        for i in {1..10}; do str="$str${arr[$RANDOM%$index]}"; done
        echo ${str}
    }
    password=$(randstr)
    printf "\nPlease input \e[33m${username}\e[0m's password.\n"
    printf "Random password is \e[33m${password}\e[0m, let it blank to use this password: "
    read passwordtmp
    if [[ -n "${passwordtmp}" ]]; then
        password=${passwordtmp}
    fi
}

function PrintEnvironmentVariable {
    # 打印配置参数
    clear

    ipv4=$(ip -4 -f inet addr show ${eth} | grep 'inet' | sed 's/.*inet \([0-9\.]\+\).*/\1/')
    ipv6=$(ip -6 -f inet6 addr show ${eth} | grep -v -P "(::1\/128|fe80)" | grep -o -P "([a-z\d]+:[a-z\d:]+)")
    echo -e "IPv4:\t\t\e[34m$(echo ${ipv4})\e[0m"
    if [ ! "$ipv6" = "" ]; then
        echo -e "IPv6:\t\t\e[34m$(echo ${ipv6})\e[0m"
    fi
    echo -e "Port:\t\t\e[34m${port}\e[0m"
    echo -e "Username:\t\e[34m${username}\e[0m"
    echo -e "Password:\t\e[34m${password}\e[0m"
    echo
    echo "Press any key to start install ocserv."

    get_char() {
        SAVEDSTTY=$(stty -g)
        stty -echo
        stty cbreak
        dd if=/dev/tty bs=1 count=1 2> /dev/null
        stty -raw
        stty echo
        stty ${SAVEDSTTY}
    }
    char=$(get_char)
    clear
}

function InstallOcserv {
    # 升级系统
    #yum update -y -q
    #升级系统
    #yum update -y -q
    yum install -y -q epel-release
    #安装ocserv依赖组件
    yum install -y gnutls gnutls-utils gnutls-devel readline readline-devel libseccomp-devel http-parser-devel pcllib-devel protobuf-c net-tools\
    libnl-devel libtalloc libtalloc-devel libnl3-devel wget gawk readline-devel gperf\
    pam pam-devel libtalloc-devel xz libseccomp-devel gnutls-devel libnl3-devel lockfile-progs nuttcp lcov uid_wrapper pam_wrapper nss_wrapper socket_wrapper\
    tcp_wrappers-devel autogen autogen-libopts-devel tar libev-devel krb5-devel\
    gcc pcre-devel openssl openssl-devel curl-devel tcp_wrappers-devel radcli-devel\
    freeradius-client-devel freeradius-client lz4-devel lz4 pam-devel lz4-devel protobuf-c-devel gssntlmssp haproxy iputils freeradius yajl libtasn1\
    http-parser-devel http-parser protobuf-c-devel protobuf-c libtalloc-devel\
    pcllib-devel pcllib cyrus-sasl-gssapi dbus-devel policycoreutils gperf


    #下载ocserv并编译安装
	#ocserv_version="1.0.0"
    #version=${1-${ocserv_version}}
	mkdir "ocserv" && cd "ocserv"
	wget "ftp://ftp.infradead.org/pub/ocserv/ocserv-${version}.tar.xz"
	[[ ! -s "ocserv-${version}.tar.xz" ]] && echo -e "${Error} ocserv 源码文件下载失败 !" && rm -rf "ocserv-${version}.tar.xz" && exit 1
	tar -xJf ocserv-${version}.tar.xz && cd ocserv-${version}
	./configure && make && make install
	#cp "doc/systemd/standalone/ocserv.service" "/usr/lib/systemd/system/ocserv.service"
	cp "doc/systemd/socket-activated/ocserv.service" "/usr/lib/systemd/system/ocserv.service"
	cp "doc/systemd/socket-activated/ocserv.socket" "/var/run/ocserv.socket"
	#cd .. && cd ..
	
	
	
    #wget -t 0 -T 60 "ftp://ftp.infradead.org/pub/ocserv/ocserv-${version}.tar.xz"
    #tar axf ocserv-${version}.tar.xz
    #cd ocserv-${version}
    #sed -i 's/#define MAX_CONFIG_ENTRIES.*/#define MAX_CONFIG_ENTRIES 200/g' src/vpn.h
    #./configure && make && make install		


    #复制配置文件样本
    confdir="/etc/ocserv"
	mkdir -p "${confdir}"
	cd ${confdir}
		wget -t 0 -T 60 "https://github.com/baiduerzi/Ocserv-install-script-for-CentOS-RHEL-7/raw/master/ocserv.conf"
		[[ ! -s "${conf}" ]] && echo -e "${Error} ocserv 配置文件下载失败 !" && rm -rf "${confdir}" && exit 1
    

    # 安装 epel-release
   # if [ $(grep epel /etc/yum.repos.d/*.repo | wc -l) -eq 0 ]; then
   #     yum install -y -q epel-release && yum clean all && yum makecache fast
    #fi
    # 安装ocserv
    #yum install -y ocserv
}

#rand(){
#	min=10000
#	max=$((60000-$min+1))
#	num=$(date +%s%N)
#	echo $(($num%$max+$min))
#}
function ConfigOcserv {
#	lalala=$(rand)
	mkdir /tmp/ssl && cd /tmp/ssl
	echo -e 'cn = "'HUA-ZTE'"
organization = "'HUA-ZTE'"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key' > ca.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(ca.tmpl) !" && over
	certtool --generate-privkey --outfile ca-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(ca-key.pem) !" && over
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(ca-cert.pem) !" && over
	
#	Get_ip
#	if [[ -z "$wget -qO- -t1 -T2 ipinfo.io/ip" ]]; then
#		echo -e "${Error} 检测外网IP失败 !"
#		stty erase '^H' && read -p "请手动输入你的服务器外网IP:" ip
#		[[ -z "${ip}" ]] && echo "取消..." && over
#	fi
ip="wget -qO- -t1 -T2 ipinfo.io/ip"
	echo -e 'cn = "'${ip}'"
organization = "'HUA-ZTE'"
expiration_days = 3650
signing_key
encryption_key
tls_www_server' > server.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(server.tmpl) !" && over
	certtool --generate-privkey --outfile server-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(server-key.pem) !" && over
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(server-cert.pem) !" && over
	
	mkdir /etc/ocserv/ssl
	mv ca-cert.pem /etc/ocserv/ssl/ca-cert.pem
	mv ca-key.pem /etc/ocserv/ssl/ca-key.pem
	mv server-cert.pem /etc/ocserv/ssl/server-cert.pem
	mv server-key.pem /etc/ocserv/ssl/server-key.pem

    # 编辑配置文件
    (echo "${password}"; sleep 1; echo "${password}") | ocpasswd -c "${confdir}/ocpasswd" ${username}
    sed -i 's@auth = "pam"@#auth = "pam"\nauth = "plain[passwd=/etc/ocserv/ocpasswd]"@g' "${confdir}/ocserv.conf"
    sed -i "s/max-same-clients = 2/max-same-clients = ${maxsameclients}/g" "${confdir}/ocserv.conf"
    sed -i "s/max-clients = 16/max-clients = ${maxclients}/g" "${confdir}/ocserv.conf"
    sed -i "s/tcp-port = 443/tcp-port = ${port}/g" "${confdir}/ocserv.conf"
    sed -i "s/udp-port = 443/udp-port = ${port}/g" "${confdir}/ocserv.conf"
    sed -i 's/^ca-cert = /#ca-cert = /g' "${confdir}/ocserv.conf"
    sed -i 's/^cert-user-oid = /#cert-user-oid = /g' "${confdir}/ocserv.conf"
    sed -i "s/default-domain = example.com/#default-domain = example.com/g" "${confdir}/ocserv.conf"
    sed -i "s@#ipv4-network = 192.168.1.0/24@ipv4-network = ${vpnnetwork}@g" "${confdir}/ocserv.conf"
    sed -i "s/#dns = 192.168.1.2/dns = ${dns1}\ndns = ${dns2}/g" "${confdir}/ocserv.conf"
	sed -i "s/cookie-timeout = 300/cookie-timeout = 86400/g" "${confdir}/ocserv.conf"
	sed -i 's/user-profile = profile.xml/#user-profile = profile.xml/g' "${confdir}/ocserv.conf"

										  
}

function ConfigFirewall {

    firewalldisactive=$(systemctl is-active firewalld.service)
    iptablesisactive=$(systemctl is-active iptables.service)

    # 添加防火墙允许列表
    if [[ ${firewalldisactive} = 'active' ]]; then

        echo "Adding firewall ports."
        firewall-cmd --permanent --add-port=${port}/tcp
        firewall-cmd --permanent --add-port=${port}/udp
        echo "Allow firewall to forward."
        firewall-cmd --permanent --add-masquerade
        echo "Reload firewall configure."
        firewall-cmd --reload
    elif [[ ${iptablesisactive} = 'active' ]]; then
        iptables -I INPUT -p tcp --dport ${port} -j ACCEPT
        iptables -I INPUT -p udp --dport ${port} -j ACCEPT
        iptables -I FORWARD -s ${vpnnetwork} -j ACCEPT
        iptables -I FORWARD -d ${vpnnetwork} -j ACCEPT
        iptables -t nat -A POSTROUTING -s ${vpnnetwork} -o ${eth} -j MASQUERADE
        #iptables -t nat -A POSTROUTING -j MASQUERADE
        service iptables save
    else
        printf "\e[33mWARNING!!! Either firewalld or iptables is NOT Running! \e[0m\n"
    fi
}

function Install-http-parser {
    if [[ $(rpm -q http-parser | grep -c "http-parser-2.0") = 0 ]]; then
        mkdir -p /tmp/http-parser-2.0 /opt/lib
        cd /tmp/http-parser-2.0
        wget "https://cbs.centos.org/kojifiles/packages/http-parser/2.7.1/5.el7/x86_64/http-parser-2.7.1-5.el7.x86_64.rpm"
        rpm2cpio http-parser-2.7.1-5.el7.x86_64.rpm | cpio -div
        mv usr/lib64/libhttp_parser.so.2* /opt/lib
        sed -i 'N;/Type=forking/a\Environment=LD_LIBRARY_PATH=/opt/lib' /lib/systemd/system/ocserv.service
        sed -i 'N;/Type=forking/a\ExecStartPost=/bin/sleep 0.1' /lib/systemd/system/ocserv.service
        systemctl daemon-reload
        cd ~
        rm -rf /tmp/http-parser-2.0
    fi
}

function ConfigSystem {
    #关闭selinux
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    setenforce 0
    #修改系统
    echo "Enable IP forward."
    sysctl -w net.ipv4.ip_forward=1
    echo net.ipv4.ip_forward = 1 >> "/etc/sysctl.conf"
    systemctl daemon-reload
    echo "Enable ocserv service to start during bootup."
    systemctl enable ocserv.service
    #开启ocserv服务
    systemctl start ocserv.service
    echo
}

function PrintResult {
    #检测防火墙和ocserv服务是否正常
    clear
    printf "\e[36mChenking Firewall status...\e[0m\n"
    iptables -L -n | grep --color=auto -E "(${port}|${vpnnetwork})"
    line=$(iptables -L -n | grep -c -E "(${port}|${vpnnetwork})")
    if [[ ${line} -ge 2 ]]
    then
        printf "\e[34mFirewall is Fine! \e[0m\n"
    else
        printf "\e[33mWARNING!!! Firewall is Something Wrong! \e[0m\n"
    fi

    echo
    printf "\e[36mChenking ocserv service status...\e[0m\n"
    netstat -anptu | grep ":${port}" | grep ocserv-main | grep --color=auto -E "(${port}|ocserv-main|tcp|udp)"
    linetcp=$(netstat -anp | grep ":${port}" | grep ocserv | grep tcp | wc -l)
    lineudp=$(netstat -anp | grep ":${port}" | grep ocserv | grep udp | wc -l)
    if [[ ${linetcp} -ge 1 && ${lineudp} -ge 1 ]]
    then
        printf "\e[34mocserv service is Fine! \e[0m\n"
    else
        printf "\e[33mWARNING!!! ocserv service is NOT Running! \e[0m\n"
    fi

    #打印VPN参数
    printf "
    if there are NO WARNING above, then you can connect to
    your ocserv VPN Server with the user and password below:
    ======================================\n\n"
    echo -e "IPv4:\t\t\e[34m$(echo ${ipv4})\e[0m"
    if [ ! "$ipv6" = "" ]; then
        echo -e "IPv6:\t\t\e[34m$(echo ${ipv6})\e[0m"
    fi
    echo -e "Port:\t\t\e[34m${port}\e[0m"
    echo -e "Username:\t\e[34m${username}\e[0m"
    echo -e "Password:\t\e[34m${password}\e[0m"
}

ConfigEnvironmentVariable $@
PrintEnvironmentVariable
InstallOcserv
ConfigOcserv
ConfigFirewall
#Install-http-parser
ConfigSystem
PrintResult

exit 0
