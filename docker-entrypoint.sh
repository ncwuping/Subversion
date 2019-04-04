#!/usr/bin/env bash

if [ ! -d /var/lib/subversion/repos ]
then
  mkdir -p /var/lib/subversion/repos /var/lib/subversion/etc
  /usr/bin/htpasswd -bcm /var/lib/subversion/etc/dav_svn.passwd guest 123456
  chmod 600 /var/lib/subversion/etc/dav_svn.passwd
  chown -Rf apache.apache /var/lib/subversion /var/log/httpd
fi

if [ ! -d /var/lib/subversion/repos/demo ]
then
  /usr/bin/svnadmin create /var/lib/subversion/repos/demo
  mkdir -p /tmp/demo/{trunk,branches,tags}
  /usr/bin/svn import /tmp/demo file:///var/lib/subversion/repos/demo -m "Initial import"
  rm -rf /tmp/demo
  chown -Rf apache.apache /var/lib/subversion/repos/demo
  if [ ! -d /var/lib/subversion/etc/dav_svn.authz ]
  then
    cp -a /var/lib/subversion/repos/demo/conf/authz /var/lib/subversion/etc/dav_svn.authz
    { \
      echo ""
      echo "[/]"
      echo "guest = r"
      echo "* ="
      echo ""
      echo "[demo:/]"
      echo "guest = r"
      echo "* ="
    } >> /var/lib/subversion/etc/dav_svn.authz
  fi
fi

[ ! -d /etc/httpd/ssl ] && mkdir -p /etc/httpd/ssl
rm -rf /etc/httpd/ssl/*
/usr/bin/openssl req -x509 -nodes -days 730 -subj "/C=CN/ST=Jiangsu/L=Suchow/CN=`tail -1 /etc/hosts | awk '{ print $1 }'`" -newkey rsa:4096 -keyout /etc/httpd/ssl/server.key -out /etc/httpd/ssl/server.crt
chmod 600 /etc/httpd/ssl/server.key
sed -e 's!^SSLCertificateFile .*!SSLCertificateFile /etc/httpd/ssl/server.crt!' -e 's!^SSLCertificateKeyFile .*!SSLCertificateKeyFile /etc/httpd/ssl/server.key!' -i /etc/httpd/conf.d/ssl.conf

if [ ! -f /etc/httpd/conf.d/subversion.conf ]
then
  { \
    echo "<Location /svn/>"
    echo "    DAV svn"
    echo "    SVNParentPath /var/lib/subversion/repos/"
    echo "    SVNListParentPath on"
    echo "    AuthType Basic"
    echo "    AuthName \"Subversion Repository\""
    echo "    AuthUserFile /var/lib/subversion/etc/dav_svn.passwd"
    echo "    Require valid-user"
    echo "    AuthzSVNAccessFile /var/lib/subversion/etc/dav_svn.authz"
    echo "    SSLRequireSSL"
    echo "</Location>"
    echo ""
    echo "RedirectMatch ^(/svn)\$ \$1/"
  } > /etc/httpd/conf.d/subversion.conf
fi

sed -e 's!^#ServerName .*!ServerName '`tail -1 /etc/hosts | awk '{ print $1 }'`':80!' -i /etc/httpd/conf/httpd.conf

exec /usr/sbin/httpd -DFOREGROUND
