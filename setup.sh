#!/bin/bash
#本文件可修改后使用

source ./function/commen.inc
source ./function/remove.inc

#dropbear安装端口为参数
function install_dropbear {
	if [ -z "$1" ]
	then
		die "Usage: `basename $0` dropbear [ssh-port-#]"
	fi
	#安装dropbear和xinetd
	check_install dropbear dropbear
	check_install /usr/sbin/xinetd xinetd
	# Disable SSH
	touch /etc/ssh/sshd_not_to_be_run
	invoke-rc.d ssh stop
	# 把droopbear加入xinetd,xinetd还可用于其它
	mv ./dropbear/dropbear /etc/xinetd.d
	invoke-rc.d xinetd restart
}
#exim4安装，并开启internet配置
function install_exim4 {
	check_install mail exim4
	if [ -f /etc/exim4/update-exim4.conf.conf ]
	then
		sed -i \
			"s/dc_eximconfig_configtype='local'/dc_eximconfig_configtype='internet'/" \
			/etc/exim4/update-exim4.conf.conf
		invoke-rc.d exim4 restart
	fi
}
#配置dotdeb源
function apt_dotdeb {
	#备份
	cp /etc/apt/{sources.list,sources.list.bak}

	# Need to add Dotdeb repo for installing PHP5-FPM when using Debian 6.0 (squeeze)
	cat >> /etc/apt/sources.list <<EOF
#Dotdeb
deb http://packages.dotdeb.org stable all
deb-src http://packages.dotdeb.org stable all
	
EOF
	wget -q -O - http://www.dotdeb.org/dotdeb.gpg | apt-key add -
	aptitude update
}

#配置nginx最新源
function apt_nginx {
	cat >> /etc/apt/sources.list <<EOF
#nginx	
deb http://nginx.org/packages/debian/ squeeze nginx
deb-src http://nginx.org/packages/debian/ squeeze nginx

EOF
	wget -q -O - http://nginx.org/keys/nginx_signing.key | apt-key add -
}

function install_syslogd {
	# We just need a simple vanilla syslogd. Also there is no need to log to
	# so many files (waste of fd). Just dump them into
	# /var/log/(cron/mail/messages)
	check_install /usr/sbin/syslogd inetutils-syslogd
	invoke-rc.d inetutils-syslogd stop

	for file in /var/log/*.log /var/log/mail.* /var/log/debug /var/log/syslog
	do
		[ -f "$file" ] && rm -f "$file"
	done
	for dir in fsck news
	do
		[ -d "/var/log/$dir" ] && rm -rf "/var/log/$dir"
	done

	cat > /etc/syslog.conf <<END
*.*;mail.none;cron.none -/var/log/messages
cron.*				  -/var/log/cron
mail.*				  -/var/log/mail
END

	[ -d /etc/logrotate.d ] || mkdir -p /etc/logrotate.d
	cat > /etc/logrotate.d/inetutils-syslogd <<END
/var/log/cron
/var/log/mail
/var/log/messages {
	rotate 4
	weekly
	missingok
	notifempty
	compress
	sharedscripts
	postrotate
		/etc/init.d/inetutils-syslogd reload >/dev/null
	endscript
}
END

	invoke-rc.d inetutils-syslogd start
}

function install_mysql {

	# Install the MySQL packages
	check_install mysqld mysql-server
	check_install mysql mysql-client

	# Install a low-end copy of the my.cnf to disable InnoDB
	invoke-rc.d mysql stop
	#
	#lowendmemory.cnf和innodb.cnf
	mv ./mysql/* /etc/mysql/conf.d/	
	invoke-rc.d mysql start

	# Generating a new password for the root user.
	passwd=`get_password root@mysql`
	mysqladmin -u root password $passwd
	cat > ~/.my.cnf <<END
[client]
user = root
password = $passwd
END
	chmod 600 ~/.my.cnf
}

function install_php {
	# PHP core
	check_install php5-fpm php5-fpm
	check_install php5-cli php5-cli

	# PHP modules
	DEBIAN_FRONTEND=noninteractive apt-get -y install php-apc php5-suhosin php5-curl php5-gd php5-intl php5-mcrypt php-gettext php5-mysql php5-sqlite

	echo 'Using PHP-FPM to manage PHP processes'
	echo ' '

	mv /etc/php5/conf.d/apc.ini /etc/php5/conf.d/orig.apc.ini

	mv ./php/apc.ini /etc/php5/conf.d/

	mv /etc/php5/conf.d/suhosin.ini /etc/php5/conf.d/orig.suhosin.ini

	mv ./php/suhosin.ini /etc/php5/conf.d/

	if [ -f /etc/php5/fpm/php.ini ]
		then
			sed -i \
				"s/upload_max_filesize = 2M/upload_max_filesize = 200M/" \
				/etc/php5/fpm/php.ini
			sed -i \
				"s/post_max_size = 8M/post_max_size = 200M/" \
				/etc/php5/fpm/php.ini
			sed -i \
				"s/memory_limit = 128M/memory_limit = 36M/" \
				/etc/php5/fpm/php.ini
	fi
	
	#unix socket,not tcp 
	if [ -f /etc/php5/fpm/pool.d/www.conf ]
		then
			sed -i 's/listen = 127.0.0.1:9000/listen = \/tmp\/php.sock/'	/etc/php5/fpm/pool.d/www.conf
			sed -i 's/^pm.max_children.*/pm.max_children = 8/' /etc/php5/fpm/pool.d/www.conf
    	sed -i 's/^pm.start_servers.*/pm.start_servers = 2/' /etc/php5/fpm/pool.d/www.conf
    	sed -i 's/^pm.min_spare_servers.*/pm.min_spare_servers = 2/' /etc/php5/fpm/pool.d/www.conf
    	sed -i 's/^pm.max_spare_servers.*/pm.max_spare_servers = 4/' /etc/php5/fpm/pool.d/www.conf
    	sed -i 's/\;pm.max_requests.*/pm.max_requests = 1000/' /etc/php5/fpm/pool.d/www.conf
	fi
	if [ -f /etc/php5/fpm/php.ini ]
		then
			sed -i 's/short_open_tag = off/short_open_tag = on/'	/etc/php5/fpm/php.ini
			sed -i 's/expose_php = on/expose = off/'	/etc/php5/fpm/php.ini
			sed -i 's/max_execution_time = 30/max_execution_time = 120/'	/etc/php5/fpm/php.ini
			sed -i 's/memory_limit = 36M/memory_limit = 64M/'	/etc/php5/fpm/php.ini
	fi
	invoke-rc.d php5-fpm restart
	
}

function install_nginx {

	check_install nginx nginx

	mkdir -p /var/www
	mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
	#删除原vhost
	rm -r /etc/nginx/conf.d/*
	#复制新的配置文件
	cp -r ./nginx/* /etc/nginx/
		
    	PR=$( awk '/cpu MHz/ {cores++} END {print cores+1}' /proc/cpuinfo )
    	sed -i "s/worker_processes [0-9]*/worker_processes $PR/" /etc/nginx/nginx.conf
    	sed -i 's/worker_connections [0-9]*/worker_connections 1024/' /etc/nginx/nginx.conf
	
	#gzip on,mime.types to mime.conf,nginx.d
	mv /etc/nginx/mime.types /etc/nginx/nginx.d/mime.conf

	#cache.conf
	mkdir -p /var/lib/nginx/cache
	chown -R www-data:www-data /var/lib/nginx/cache

	#misc.conf
	#ssl.conf
	#php stream pool
	#conf.d
	# PHP-safe default vhost
	mkdir /var/www/default
	mkdir /var/www/default/public
	echo 'Hello World!' >> /var/www/default/public/index.html
	cp ./tz.php /var/www/default/public/p.php
	
	echo "探针http://ip/p.php"

	invoke-rc.d nginx restart
}

#新设站点wordpress或drupal
function install_site {

	if [ -z "$1" && -z "$2" ]
	then
		die "Usage: `basename $0` site [domain] [wordpress or drupal]"
	fi

	# Setup folder
	mkdir /var/www/$1
	mkdir /var/www/$1/public

	# Setup default index.html file
	echo "Hello World" > /var/www/$1/public/index.html

	# Setting up Nginx mapping
	cp ./site/WOD.conf /etc/nginx/host.d/$1.conf
	sed -i "s/DOMAIN/$1/" /etc/nginx/hosts.d/$1.conf
	sed -i "s/WOD/$2/" /etc/nginx/hosts.d/$1.conf


	# PHP/Nginx needs permission to access this
	chown www-data:www-data -R "/var/www/$1"

	invoke-rc.d nginx restart

	print_warn "New site successfully installed."
}

function install_mysqluser {

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` mysqluser [domain]"
	fi

	if [ ! -d "/var/www/$1/" ]
	then
		echo "no site found at /var/www/$1/"
		exit
	fi

	# Setting up the MySQL database
	dbname=`echo $1 | tr . _`
	userid=`get_domain_name $1`
	# MySQL userid cannot be more than 15 characters long
	userid="${userid:0:15}"
	passwd=`get_password "$userid@mysql"`

	cat > "/var/www/$1/mysql.conf" <<END
[mysql]
user = $userid
password = $passwd
database = $dbname
END
	chmod 600 "/var/www/$1/mysql.conf"

	mysqladmin create "$dbname"
	echo "GRANT ALL PRIVILEGES ON \`$dbname\`.* TO \`$userid\`@localhost IDENTIFIED BY '$passwd';" | \
		mysql

	# We could also add these...
	#echo "DROP USER '$userid'@'localhost';" | \ mysql
	#echo "DROP DATABASE IF EXISTS  `$dbname` ;" | \ mysql

	echo 'MySQL Username: ' $userid
	echo 'MySQL Password: ' $passwd
	echo 'MySQL Database: ' $dbname
}

#防火墙 开启ssh端口,防ssh攻击
function install_iptables {

	check_install iptables iptables

	if [ -z "$1" ]
	then
		die "Usage: `basename $0` iptables [ssh-port-#]"
	fi

	# Create startup rules
	cp ./iptables/iptables.up.rules /etc/
	sed -i "s/SSH_PORT/$1/" /etc/iptables.up.rules

	# Set these rules to load on startup
	cp ./iptables/iptables /etc/network/if-pre-up.d/

	# Make it executable
	chmod +x /etc/network/if-pre-up.d/iptables

	# Load the rules
	iptables-restore < /etc/iptables.up.rules

	# You can flush the current rules with /sbin/iptables -F
	echo 'Created /etc/iptables.up.rules and startup script /etc/network/if-pre-up.d/iptables'
	echo 'If you make changes you can restore the rules with';
	echo '/sbin/iptables -F'
	echo 'iptables-restore < /etc/iptables.up.rules'
	echo ' '
}


########################################################################
# START OF PROGRAM
########################################################################
export PATH=/bin:/usr/bin:/sbin:/usr/sbin

check_sanity
case "$1" in
mysql)
	install_mysql
	;;
exim4)
	install_exim4
	;;
nginx)
	install_nginx
	;;
php)
	install_php
	;;
apt)
	apt_dotdeb
	apt_nginx
	;;
site)
	install_site $2 $3
	;;
mysqluser)
	install_mysqluser $2
	;;
iptables)
	install_iptables $2
	;;
dropbear)
	install_dropbear $2
	;;
system)
	update_timezone
	remove_unneeded
	update_upgrade
	install_dash
	#install_vim
	install_nano
	install_htop
	install_mc
	install_iotop
	install_iftop
	install_syslogd
	;;
*)
	echo 'Usage:' `basename $0` '[option] [argument]'
	echo 'Available options (in recomended order):'
	echo '  - apt                 (install dotdeb and nginx apt source for nginx +1.0)'
	echo '  - system                 (remove unneeded, upgrade system, install software)'
	echo '  - exim4                  (install exim4 mail server)'
	echo '  - dropbear  [port]       (SSH server)'
	echo '  - iptables  [port]       (setup basic firewall with HTTP(S) open)'
	echo '  - mysql                  (install MySQL and set root password)'
	echo '  - nginx                  (install nginx and create sample PHP vhosts)'
	echo '  - php                    (install PHP5-FPM with APC, cURL, suhosin, etc...)'
	echo '  - site      [domain.tld] [wordpress/drupal]  (create nginx vhost and /var/www/$site/public)'
	echo '  - mysqluser [domain.tld]  (create matching mysql user and database)'
	echo '  '
	;;
esac



