#!/bin/bash
case "$1" in
base)
	bash ./setup.sh apt
	bash ./setup.sh system
	bash ./setup.sh exim4
	bash ./setup.sh nginx
	bash ./setup.sh mysql
	bash ./setup.sh php
	;;
site)
	bash ./setup.sh site $2 $3
	bash ./setup.sh mysqluser $2
	;;
harden)
	bash ./setup.sh dropbear $2
	bash ./setup.sh iptables $2
	;;
*)
	echo 'Usage:' `basename $0` '[option] [argument]'
	echo 'Available options (in recomended order):'
	echo '  - base                 			(install base emp system,nginx+mysql+php+exim4)'
	echo '  - site [domain.tld] [wordpress/drupal]   (set new website,virtual host,width your domain and project)'
	echo '  - harden [ssh-port]          (install dropbear and iptables with your port)'
	;;
esac	