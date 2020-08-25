FROM centos:7

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
 && yum clean all -y \
 && yum makecache fast \
 && yum update -y \
 && yum install -y \
        subversion \
        httpd \
        mod_dav_svn \
        mod_ssl \
        mod_auth_kerb \
        mod_ldap \
 && yum clean all -y \
 && rm -rf /var/cache/yum; \
    sed -E 's/^\s*(SSLProtocol\s.*)/\1 -TLSv1 -TLSv1.1/' -i /etc/httpd/conf.d/ssl.conf \
 && sed -E 's/^\s*(SSLCipherSuite HIGH:).*/\1!aNULL:!MD5:!SHA:+SHA256:+SHA384/' -i /etc/httpd/conf.d/ssl.conf \
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
