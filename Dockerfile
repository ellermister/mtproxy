FROM --platform=$TARGETPLATFORM nginx:latest AS build
# FROM nginx:latest AS build
COPY . /home/mtproxy
ENV WORKDIR=/home/mtproxy
WORKDIR /home/mtproxy 
# setup config
RUN set -ex \
    && cd $WORKDIR \
    && cp src/* /usr/share/nginx/html \
    && rm -rf .git \
    && cp mtproxy-entrypoint.sh /docker-entrypoint.d/40-mtproxy-start.sh \
    && chmod +x /docker-entrypoint.d/40-mtproxy-start.sh \
    && cp -f nginx/default.conf /etc/nginx/conf.d/default.conf \
    && cp -f nginx/ip_white.conf /etc/nginx/ip_white.conf \
    && cp -f nginx/nginx.conf /etc/nginx/nginx.conf
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends git wget curl build-essential libssl-dev zlib1g-dev iproute2 php8.2-fpm vim \
    && bash mtproxy.sh build \
    && sed -i 's/^user\s*=[^\r]\+/user = root/' /etc/php/8.2/fpm/pool.d/www.conf \
    && sed -i 's/^group\s*=[^\r]\+/group = root/' /etc/php/8.2/fpm/pool.d/www.conf \
    && rm -rf $WORKDIR/MTProxy \
    && rm -rf ~/go \
    && mkdir /run/php -p && mkdir $WORKDIR/pid \
    && apt-get purge -y git build-essential libssl-dev zlib1g-dev \
    && apt-get clean \
    && apt-get autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 80 443
