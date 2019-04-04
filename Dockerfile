FROM centos:latest

RUN { \
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
 && yum clean all -y \
 && rm -rf /var/cache/yum; \
    { \
      echo 'LoadModule dav_svn_module     modules/mod_dav_svn.so'; \
      echo 'LoadModule authz_svn_module   modules/mod_authz_svn.so'; \
      echo 'LoadModule dontdothat_module  modules/mod_dontdothat.so'; \
    } > /etc/httpd/conf.modules.d/10-subversion.conf \
 && chown -Rf apache.apache /var/www \
 && rm -rf /etc/httpd/conf.d/subversion.conf /var/log/httpd

COPY docker-entrypoint.sh /usr/local/bin/

RUN mkdir -p /docker-entrypoint-initdb.d \
 && ln -s usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]
