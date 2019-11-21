FROM ubuntu:18.04 AS mysql-client
RUN sed -i 's/# \(deb-src .*\)$/\1/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get build-dep -y mariadb-client && \
    apt-get install -y \
        git \
        gnutls-dev \
        vim.tiny
RUN    git clone https://github.com/kolbe/mariadb-server --depth=1 --branch=tidb-client /client
WORKDIR /client
RUN    cmake . -DWITHOUT_SERVER=ON -DCPACK_STRIP_FILES=ON
RUN    make -j install


FROM pingcap/tidb-enterprise-tools AS tidb-enterprise-tools
RUN apk add binutils curl \
    && curl -sS -L http://download.pingcap.org/tidb-v3.0-linux-amd64.tar.gz | \
         tar -C / --strip-components=2 -xvzf - \
             tidb-v3.0-linux-amd64/bin/tikv-ctl \
             tidb-v3.0-linux-amd64/bin/pd-ctl \
    && strip importer loader mydumper syncer tikv-ctl pd-ctl


FROM ubuntu:18.04
RUN apt-get update && apt-get install -y \
    curl \
    less \
    libreadline5 \
    vim \
    && rm -rf /var/lib/apt/lists/*

COPY --from=mysql-client /usr/local/mysql/bin/mysql /usr/local/bin/
COPY --from=tidb-enterprise-tools /importer /loader /mydumper /syncer /tikv-ctl /pd-ctl /usr/local/bin/
WORKDIR /root
COPY README.container README
COPY motd.bash .motd.bash
RUN echo source .motd.bash >> .bashrc
ENTRYPOINT ["/usr/bin/env","bash"]
