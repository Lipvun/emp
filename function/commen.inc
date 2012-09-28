#主要基本函数
#本文件不建议修改

#更新系统
function update_upgrade {
	apt-get -q -y update
	apt-get -q -y upgrade
}
#检查后安装 带两个参数
function check_install {
	if [ -z "`which "$1" 2>/dev/null`" ]
	then
		executable=$1
		shift
		while [ -n "$1" ]
		do
			DEBIAN_FRONTEND=noninteractive apt-get -q -y install "$1"
			print_info "$1 installed for $executable"
			shift
		done
	else
		print_warn "$2 already installed"
	fi
}
#检查后卸载 带两个参数
function check_remove {
	if [ -n "`which "$1" 2>/dev/null`" ]
	then
		DEBIAN_FRONTEND=noninteractive apt-get -q -y remove --purge "$2"
		print_info "$2 removed"
	else
		print_warn "$2 is not installed"
	fi
}
#检查用户及系统版本是否适用本脚本
function check_sanity {
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die 'Must be run by root user'
	fi
	if [ ! -f /etc/debian_version ]
	then
		die "Distribution is not supported"
	fi
}
#错误中断
function die {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}
#获取域名
function get_domain_name() {
	# Getting rid of the lowest part.
	domain=${1%.*}
	lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
	case "$lowest" in
	com|net|org|gov|edu|co|me|info|name)
		domain=${domain%.*}
		;;
	esac
	lowest=`expr "$domain" : '.*\.\([a-z][a-z]*\)'`
	[ -z "$lowest" ] && echo "$domain" || echo "$lowest"
}
#获取随机13位密码，主要用于mysql密码
function get_password() {
	# Check whether our local salt is present.
	SALT=/var/lib/radom_salt
	if [ ! -f "$SALT" ]
	then
		head -c 512 /dev/urandom > "$SALT"
		chmod 400 "$SALT"
	fi
	password=`(cat "$SALT"; echo $1) | md5sum | base64`
	echo ${password:0:13}
}
#输出信息
function print_info {
	echo -n -e '\e[1;36m'
	echo -n $1
	echo -e '\e[0m'
}
#输出警告
function print_warn {
	echo -n -e '\e[1;33m'
	echo -n $1
	echo -e '\e[0m'
}
#设置时区
function update_timezone {
	dpkg-reconfigure tzdata
}
#发行版检测：
function check_lsb {
	# Detect distribution. Debian or Ubuntu
	DISTRO=`lsb_release -i -s`
	# Distribution's release. Squeeze, wheezy, precise etc
	RELEASE=`lsb_release -c -s`
	if [ $DISTRO = "" ]; then
		echo -e "\033[35;1mPlease run 'aptitude -y install lsb-release' before using this script.\033[0m"
  	exit 1
	fi
}

#安装部分有用工具：

#dash
function install_dash {
	check_install dash dash
	rm -f /bin/sh
	ln -s dash /bin/sh
}
#nano
function install_nano {
	check_install nano nano
}
#htop
function install_htop {
	check_install htop htop
}
#mc
function install_mc {
	check_install mc mc
}
#iotop
function install_iotop {
	check_install iotop iotop
}
#iftop
function install_iftop {
	check_install iftop iftop
	print_warn "Run IFCONFIG to find your net. device name"
	print_warn "Example usage: iftop -i venet0"
}
#vim
function install_vim {
	check_install vim vim
}