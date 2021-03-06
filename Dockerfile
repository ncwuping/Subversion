FROM centos:7

ENV HTTPD_VERSION 2.4.37
ENV IUS_REPO_URL https://dl.iuscommunity.org/pub/ius/stable/CentOS/7/x86_64/ius-release-1.0-15.ius.centos7.noarch.rpm

RUN set -xe; \
    mv /etc/localtime /etc/localtime.UTC \
 && echo 'Asia/Shanghai' > /etc/timezone \
 && ln -sf ../usr/share/zoneinfo/Asia/Shanghai /etc/localtime; \
    { \
      echo '[WandiscoSVN]'; \
      echo 'name=Wandisco SVN Repo'; \
      echo 'baseurl=http://opensource.wandisco.com/centos/7/svn-1.8/RPMS/$basearch/'; \
      echo 'enabled=1'; \
      echo 'gpgcheck=1'; \
      echo 'gpgkey=http://opensource.wandisco.com/RPM-GPG-KEY-WANdisco'; \
    } > /etc/yum.repos.d/wandisco-svn.repo \
 && yum makecache fast \
 && yum install -y \
        epel-release \
        subversion \
        ${IUS_REPO_URL} \
 && sed -e 's!^\s*#\+\s*baseurl=https:\/\/!baseurl=https:\/\/!' \
        -e 's!^\s*mirrorlist=https:\/\/!#mirrorlist=https:\/\/!' \
        -i.bak /etc/yum.repos.d/ius*.repo \
 && yum install -y \
        httpd24u-${HTTPD_VERSION} \
        httpd24u-mod_ssl-${HTTPD_VERSION}  \
        httpd24u-mod_ldap-${HTTPD_VERSION} \
        mod_dav_svn \
        mod_auth_kerb \
 && yum clean all -y \
 && rm -rf /var/cache/yum; \
    sed -E 's/^\s*(SSLProtocol\s.*)/\1 -TLSv1 -TLSv1.1/' -i /etc/httpd/conf.d/ssl.conf \
 && sed -E 's/^\s*(SSLCipherSuite HIGH:).*/\1!aNULL:!MD5:!SHA:!DHE/' -i /etc/httpd/conf.d/ssl.conf \
 && { \
      echo 'LoadModule dav_svn_module     modules/mod_dav_svn.so'; \
      echo 'LoadModule authz_svn_module   modules/mod_authz_svn.so'; \
      echo 'LoadModule dontdothat_module  modules/mod_dontdothat.so'; \
    } > /etc/httpd/conf.modules.d/10-subversion.conf \
 && chown -Rf apache.apache /var/www \
 && rm -rf /etc/httpd/conf.d/subversion.conf /var/log/httpd

COPY docker-entrypoint.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
 && mkdir -p /docker-entrypoint-initdb.d \
 && ln -s usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]
