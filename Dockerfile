FROM nginx

COPY . /home/mtproxy

ENV WORKDIR=/home/mtproxy

WORKDIR /home/mtproxy 

# setup config
RUN set -ex \
	&& cd $WORKDIR \
	&& cp src/* /usr/share/nginx/html \
    && cp mtp_config mtp_config.bak \
	&& rm -rf .git \
	&& cp mtproxy-entrypoint.sh /docker-entrypoint.d/40-mtproxy-start.sh \
	&& chmod +x /docker-entrypoint.d/40-mtproxy-start.sh \
	&& /bin/cp -f nginx/default.conf /etc/nginx/conf.d/default.conf \
	&& /bin/cp -f nginx/ip_white.conf /etc/nginx/ip_white.conf \
	&& /bin/cp -f nginx/nginx.conf /etc/nginx/nginx.conf
	
# build mtproxy and install php
RUN set -ex \
	&& apt-get update \
    && apt-get install -y --no-install-recommends git curl build-essential libssl-dev zlib1g-dev iproute2 php7.4-fpm vim-common \
	&& git clone https://github.com/TelegramMessenger/MTProxy \
	&& cd MTProxy \
    && sed -i 's/CFLAGS\s*=[^\r]\+/& -fcommon\r/' Makefile \
	&& sed -i 's/^user\s*=[^\r]\+/user = root/' /etc/php/7.4/fpm/pool.d/www.conf \
	&& sed -i 's/^group\s*=[^\r]\+/group = root/' /etc/php/7.4/fpm/pool.d/www.conf \
	&& make && cd objs/bin && cp -f mtproto-proxy $WORKDIR \
    && rm -rf $WORKDIR/MTProxy \
	&& mkdir /run/php -p && mkdir $WORKDIR/pid \
	&& apt-get purge -y git build-essential libssl-dev zlib1g-dev \
    && apt-get clean \
	&& apt-get autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/*
