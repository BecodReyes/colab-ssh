#!/bin/bash -e

runfrp(){
echo "[Info] SSH已启动，请使用下面创建成功的连接信息和密码 "$passwd" 登录到服务器"
for i in `cat /tmp/servers.conf`;do
	ip=`echo $i|awk -F',' '{print $1}'`
	port=`echo $i|awk -F',' '{print $2}'`
	token=`echo $i|awk -F',' '{print $3}'`
cat << EOF > /tmp/frp/conf/$ip.conf
[common]
server_addr = $ip
server_port = $port
token = $token
pool_count = 5
tcp_mux = true
user = $username
login_fail_exit = true
protocol = tcp
tls_enable = true

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = $randomport
use_compression = true
EOF
	nohup /tmp/frp/frpc -c /tmp/frp/conf/$ip.conf > frp_${ip}_log.out 2>&1 &
	echo "[Info] "$ip":"$randomport"创建成功"
done

while true
do
	cat /proc/uptime | awk '{printf("单次运行剩余时间 : %.2f", 12-$1/60/60)}'
	echo -e "\n"
	sleep 60s
done
}

testconfig(){
if [[ `grep -o ',' /tmp/servers.conf|wc -l` -lt "3" ]];then
	echo "[Error] 配置文件疑似损坏，请重试"
else
	echo "[Info] 配置文件验证成功"
	runfrp
fi
}

getconfig(){
echo "[Info] 正在获取服务器配置"
echo "[Info] 配置文件格式：<服务器IP>,<服务器端口>,<认证密码>"

if [ -z "$1" ];then
	if [ -f ".env" ];then
		cp .env /tmp/servers.conf -rf
		testconfig
	else
		echo "[Error] 配置文件未引用，请重试"
	fi
else
	confurl=$1
	if [[ $confurl == http* ]];then
		echo "[Info] 正在获取服务器配置"
		wget -qO /tmp/servers.conf $confurl
		testconfig
	else
		echo "[Error] 配置文件链接不正确!"
	fi
fi
}

run(){
echo '    ____                      ______                      '
echo '   / __ )___  _________  ____/ / __ \___  __  _____  _____'
echo '  / __  / _ \/ ___/ __ \/ __  / /_/ / _ \/ / / / _ \/ ___/'
echo ' / /_/ /  __/ /__/ /_/ / /_/ / _, _/  __/ /_/ /  __(__  ) '
echo '/_____/\___/\___/\____/\__,_/_/ |_|\___/\__, /\___/____/  '
echo '                                       /____/             '
echo '    Github: https://github.com/BecodReyes/colab-ssh       '
echo '                Powered by BecodReyes                     '

echo "[Info] 正在初始化中"
username=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6`
sleep 0.1s
passwd=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12`
randomport=`shuf -i 10240-50000 -n 1`

killall sshd
killall frpc
rm -rf /tmp/frp

#获取服务器IP
server_local=`curl -s http://ip-api.com/line/?lang=zh-CN|sed -n -e 2p -e 5p -e 6p`

echo "[Info] 正在获取openssh"
apt-get install -qq -o=Dpkg::Use-Pty=0 openssh-server pwgen -y > /dev/null

echo "[Info] 正在修改ssh设置"
echo root:$passwd | chpasswd
mkdir -p /var/run/sshd
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

echo "[Info] 正在启动ssh"
nohup /usr/sbin/sshd -D > sshd_log.out 2>&1 &

echo "[Info] 正在获取frpc"
mkdir -p /tmp/frp/conf
wget -qO /tmp/frpc.tar.gz "https://github.com/fatedier/frp/releases/download/v0.38.0/frp_0.38.0_linux_amd64.tar.gz"
echo "[Info] 正在解压frpc"
tar --strip-components 1 -zxf /tmp/frpc.tar.gz -C /tmp/frp
getconfig
}

run

bash $1
