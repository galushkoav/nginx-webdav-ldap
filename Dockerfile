FROM alpine:3.7
LABEL maintainer "a.v.galushko86@gmail.com"

ENV COMPILE_DIR /build
ENV LIBRESSL_DIR /libressl
ENV NB_PROC 8
ENV NGINX_VERSION 1.15.0
ENV VERSION_PCRE pcre-8.42
ENV VERSION_LIBRESSL libressl-2.7.3
ENV VERSION_NGINX nginx-$NGINX_VERSION
ENV SOURCE_LIBRESSL http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/
ENV SOURCE_PCRE https://ftp.pcre.org/pub/pcre/
ENV SOURCE_NGINX http://nginx.org/download/
ENV STATICLIBSSL $LIBRESSL_DIR/$VERSION_LIBRESSL

RUN addgroup -g 82 -S www-data \
    && adduser -u 82 -D -S -G www-data www-data \
    && apk add --no-cache \
     ca-certificates \
     openldap-dev \
     pcre \
     zlib \
     libgcc \
     tzdata \
   && apk add --no-cache --virtual .build-deps \
     build-base \
     autoconf \
     automake \
     bind-tools \
     binutils \
     build-base \
     ca-certificates \
     cmake \
     curl \
     file \
     gcc \
     gd-dev \
     geoip-dev \
     git \
     gnupg \
     gnupg \
     go \
     libc-dev \
     libstdc++ \
     readline \
     libtool \
     libxslt-dev \
     linux-headers \
     make \
     patch \
     pcre \
     pcre-dev \
     perl-dev \
     su-exec \
     tar \
     tzdata \
     zlib \
     zlib-dev \
 &&  mkdir -p ${COMPILE_DIR} && mkdir -p ${LIBRESSL_DIR} \
 &&  wget -P $LIBRESSL_DIR http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/$VERSION_LIBRESSL.tar.gz \
 && wget -P $COMPILE_DIR https://ftp.pcre.org/pub/pcre/${VERSION_PCRE}.tar.gz \
 && wget -P $COMPILE_DIR http://nginx.org/download/${VERSION_NGINX}.tar.gz \
 && wget -P $COMPILE_DIR https://github.com/3078825/nginx-image/archive/master.zip \
 && wget -P $COMPILE_DIR http://luajit.org/download/LuaJIT-2.0.5.tar.gz \
 && git clone git://github.com/vozlt/nginx-module-vts.git $COMPILE_DIR/nginx-module-vts \
 && git clone https://github.com/openresty/lua-nginx-module.git $COMPILE_DIR/lua-nginx-module \
 && git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git $COMPILE_DIR/ngx_http_substitutions_filter_module \
 && git clone https://github.com/kvspb/nginx-auth-ldap.git $COMPILE_DIR/nginx-auth-ldap \
 && cd $LIBRESSL_DIR && tar xzf $VERSION_LIBRESSL.tar.gz \
 && cd $COMPILE_DIR && tar xzf $VERSION_NGINX.tar.gz \
 && cd $COMPILE_DIR && tar xzf $VERSION_PCRE.tar.gz \
 && cd $COMPILE_DIR && unzip master.zip  \
 && cd $COMPILE_DIR && tar xzf LuaJIT-2.0.5.tar.gz \
 && cd $STATICLIBSSL && ./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-strip -j $NB_PROC \
 && cd $COMPILE_DIR/LuaJIT-2.0.5 && make  && make install \
&& cd $COMPILE_DIR/$VERSION_NGINX && ./configure \
--with-openssl=$STATICLIBSSL \
--with-ld-opt="-lrt"  \
--with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2' \
--with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,--as-needed' \
--sbin-path=/usr/sbin/nginx \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--lock-path=/var/lock/nginx.lock \
--pid-path=/run/nginx.pid \
--with-pcre=$COMPILE_DIR/$VERSION_PCRE \
--with-http_ssl_module \
--with-http_v2_module \
--with-file-aio \
--with-http_sub_module \
--with-http_gzip_static_module \
--with-http_stub_status_module \
--with-http_image_filter_module \
--with-threads \
--with-mail \
--with-http_dav_module \
--with-mail_ssl_module \
--with-stream \
--with-stream_realip_module \
--with-stream_ssl_module \
--with-stream_ssl_preread_module \
--http-client-body-temp-path=/var/lib/nginx/body \
--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
--http-proxy-temp-path=/var/lib/nginx/proxy \
--http-scgi-temp-path=/var/lib/nginx/scgi \
--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
--with-debug \
--with-pcre-jit \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_gunzip_module \
--with-http_auth_request_module \
--with-http_addition_module \
--with-http_gzip_static_module \
--add-module=$COMPILE_DIR/ngx_http_substitutions_filter_module \
--add-module=$COMPILE_DIR/lua-nginx-module \
--add-module=$COMPILE_DIR/nginx-auth-ldap \
--add-module=$COMPILE_DIR/nginx-module-vts \
&& cd $COMPILE_DIR/$VERSION_NGINX \
&& make  -j 4 \
&& make install && rm -rf $COMPILE_DIR/*\
&&  apk add --no-cache --virtual .gettext gettext \
  && mv /usr/bin/envsubst /tmp/ \
  && runDeps="$( \
    scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u \
  ) sed tzdata ca-certificates tini shadow" \
  && apk add --no-cache --virtual .nginx-rundeps $runDeps \
  && apk del .build-deps \
  && apk del .gettext \
  && mv /tmp/envsubst /usr/local/bin/ \
  # forward request and error logs to docker log collector
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && mkdir -p /var/www \
  && rm -rf /tmp/* /usr/src/* /var/cache/apk/* /root/.gnupg /libressl* /nginx* || true
RUN mkdir -p /var/lib/nginx/body
  EXPOSE 80 443
  CMD ["nginx", "-g", "daemon off;"]