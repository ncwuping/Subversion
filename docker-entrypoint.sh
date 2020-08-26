#!/usr/bin/env bash

set -e

{
  echo "ServerTokens Prod"
} > /etc/httpd/conf.d/httpd-default.conf

if [ ! -d /etc/httpd/ssl ]
then
  mkdir -p /etc/httpd/ssl
fi

openssl dhparam -out /etc/httpd/ssl/dhparams.pem 2048
{
  echo ''
  echo 'SSLOpenSSLConfCmd DHParameters "/etc/httpd/ssl/dhparams.pem"'
} >> /etc/httpd/conf.d/ssl.conf

if [ ! -f /etc/httpd/ssl/server.key -o ! -f /etc/httpd/ssl/server.crt ]
then
  #rm -rf /etc/httpd/ssl/*
  /usr/bin/openssl req -x509 -nodes -days 730 -subj "/C=CN/ST=Jiangsu/L=Suchow/CN=`tail -1 /etc/hosts | awk '{ print $1 }'`" -newkey rsa:4096 -keyout /etc/httpd/ssl/server.key -out /etc/httpd/ssl/server.crt
  chmod 600 /etc/httpd/ssl/server.key
fi
sed -e 's!^SSLCertificateFile .*!SSLCertificateFile /etc/httpd/ssl/server.crt!' \
    -e 's!^SSLCertificateKeyFile .*!SSLCertificateKeyFile /etc/httpd/ssl/server.key!' \
    -i /etc/httpd/conf.d/ssl.conf

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

if [ ! -f /etc/httpd/conf.d/subversion.conf ]
then
  { \
    echo "<Location /svn/>"
    echo "    DAV svn"
    echo "    SVNParentPath /var/lib/subversion/repos/"
    echo "    SVNListParentPath on"
    echo "    AuthName \"Subversion Repository\""
    echo "    AuthzSVNAccessFile /var/lib/subversion/etc/dav_svn.authz"
    echo ""
  } > /etc/httpd/conf.d/subversion.conf

  case "${AUTH_TYPE}" in
  "ldap")
    {
      echo "<IfModule mod_authnz_ldap.c>"
      echo "    # Distinguished Name (DN) of the user that mod_authz_ldap should"
      echo "    # bind to the LDAP server as when searching for the domain user"
      echo "    # provided by the web client (Active Directory does not allow"
      echo "    # anonymous binds).  Note, the cn attribute corresponds to the"
      echo "    # \"Display Name\" field of a user's account in the Active Directory"
      echo "    # Users and Computers tool, not their login username:"
      echo "    AuthLDAPBindDN \"${AUTH_LDAP_BIND_DN}\""
      echo ""
      echo "    # the BindDN user's password:"
      echo "    AuthLDAPBindPassword \"${AUTH_LDAP_BIND_PASSWORD}\""
      echo ""
      echo "    AuthLDAPURL \"${AUTH_LDAP_URL}\" NONE"
      echo "</IfModule>"
      echo ""
      echo "    AuthType Basic"
      echo "    AuthBasicProvider file ldap"
      echo "    AuthBasicAuthoritative off"
      echo "    AuthUserFile /var/lib/subversion/etc/dav_svn.passwd"
      echo ""
    } >> /etc/httpd/conf.d/subversion.conf
    ;;
  "kerberos")
    AUTH_KERB_REALM_L=$( echo ${AUTH_KERB_REALM} | tr '[A-Z]' '[a-z]' )
    AUTH_KERB_REALM_U=$( echo ${AUTH_KERB_REALM} | tr '[a-z]' '[A-Z]' )
    {
      echo "<IfModule mod_auth_kerb.c>"
      echo "    AuthType Kerberos"
#      echo "    AuthType Basic"
      echo "    KrbMethodNegotiate off"
      echo "    #KrbMethodK5Passwd off"
      echo "    KrbAuthoritative off"
      echo "    #KrbAuthRealms ${AUTH_KERB_REALM_U}"
      echo "    KrbVerifyKDC off"
      echo "    #KrbServiceName HTTP/${HOSTNAME}@${AUTH_KERB_REALM_U}"
      echo "    #Krb5Keytab auth_kerb.keytab ;in the same format of KrbServiceName"
      echo "    #KrbSaveCredentials on"
      echo "    KrbLocalUserMapping on"
      echo "    KrbDelegateBasic on"
      echo "    AuthUserFile /var/lib/subversion/etc/dav_svn.passwd"
      echo "</IfModule>"
      echo ""
#      echo "    AuthType Basic"
#      echo "    AuthBasicProvider file"
#      echo "    AuthBasicAuthoritative off"
#      echo "    AuthUserFile /var/lib/subversion/etc/dav_svn.passwd"
      echo ""
    } >> /etc/httpd/conf.d/subversion.conf

    {
      echo "# Configuration snippets may be placed in this directory as well"
      echo "includedir /etc/krb5.conf.d/"
      echo "[libdefaults]"
      echo " dns_lookup_realm = false"
      echo "# ticket_lifetime = 24h"
      echo "# renew_lifetime = 7d"
      echo "# forwardable = true"
      echo "# rdns = false"
      echo "# pkinit_anchors = /etc/pki/tls/certs/ca-bundle.crt"
      echo "# default_realm = EXAMPLE.COM"
      echo "# default_ccache_name = KEYRING:persistent:%{uid}"
      echo " default_realm = ${AUTH_KERB_REALM_U}"
#      echo " default_keytab_name = /etc/krb5.keytab"
      echo " default_tgs_enctypes = rc4-hmac"
      echo " default_tkt_enctypes = rc4-hmac"
      echo ""
      echo "[realms]"
      echo "# EXAMPLE.COM = {"
      echo "#  kdc = kerberos.example.com"
      echo "#  admin_server = kerberos.example.com"
      echo "# }"
      echo ""
      echo "[domain_realm]"
      echo "# .example.com = EXAMPLE.COM"
      echo "# example.com = EXAMPLE.COM"
    } > /etc/krb5.conf

    {
      echo "[realms]"
      echo " ${AUTH_KERB_REALM_U} = {"
      echo "  kdc = ${AUTH_KERB_KDC}"
      echo "  default_domain = ${AUTH_KERB_REALM_U}"
      echo " }"
      echo ""
      echo "[domain_realm]"
      echo " .${AUTH_KERB_REALM_L} = ${AUTH_KERB_REALM_U}"
      echo " ${AUTH_KERB_REALM_L} = ${AUTH_KERB_REALM_U}"
    } > /etc/krb5.conf.d/realm

#    {
#      echo "HTTP/${HOSTNAME}.${AUTH_KERB_REALM_L}@${AUTH_KERB_REALM_U}"
#    } > /etc/krb5.keytab
    ;;
  *)
    {
      echo "    AuthType Basic"
      echo "    AuthBasicProvider file"
      echo "    AuthUserFile /var/lib/subversion/etc/dav_svn.passwd"
      echo ""
    } >> /etc/httpd/conf.d/subversion.conf
    ;;
  esac

  {
    echo "    RequestHeader set REMOTE_USER %{REMOTE_USER}s"
    echo "    Require valid-user"
    echo "    SSLRequireSSL"
    echo "</Location>"
    echo ""
    echo "RedirectMatch ^(/svn)\$ \$1/"
  } >> /etc/httpd/conf.d/subversion.conf
fi

#sed -e 's!^#ServerName .*!ServerName '`tail -1 /etc/hosts | awk '{ print $1 }'`':80!' -i /etc/httpd/conf/httpd.conf
sed -e 's!^\s*Listen\s80!#Listen 80!' \
    -i /etc/httpd/conf/httpd.conf

exec /usr/sbin/httpd -DFOREGROUND
