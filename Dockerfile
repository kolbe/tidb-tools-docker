FROM ubuntu:18.04 AS mysql-client
RUN sed -i 's/# \(deb-src .*\)$/\1/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
        git cmake gcc g++ gnutls-dev libncurses5-dev libcurl4-gnutls-dev libssl-dev \
    && git clone https://github.com/kolbe/mariadb-server --depth=1 -b tidb-client --single-branch /mariadb-10.4 \
    && git clone https://github.com/mysql/mysql-server --depth=1 -b 5.7 --single-branch /mysql-5.7 \
    && git clone https://github.com/mysql/mysql-server --depth=1 -b 8.0 --single-branch /mysql-8.0 \
    && mkdir -p /install \
    && cd /mariadb-10.4 \
    && cmake . -DWITHOUT_SERVER=ON -DCPACK_STRIP_FILES=ON -DMYSQL_TCP_PORT=4000 \
    && make -j preinstall \
    && mv client/mysql /install/ \
    && cd /mysql-5.7 \
    && cmake . -DWITHOUT_SERVER=ON -DCPACK_STRIP_FILES=ON -DMYSQL_TCP_PORT=4000 -DDOWNLOAD_BOOST=1 -DWITH_BOOST=/tmp \
    && make -j preinstall \
    && mv client/mysql /install/mysql_57 \
    && cd /mysql-8.0 \
    && cmake . -DWITHOUT_SERVER=ON -DCPACK_STRIP_FILES=ON -DMYSQL_TCP_PORT=4000 -DFORCE_INSOURCE_BUILD=1 -DDOWNLOAD_BOOST=1 -DWITH_BOOST=/tmp \
    && make preinstall \
    && mv runtime_output_directory/mysql /install/mysql_80 \
    && rm -rf /mariadb-* /mysql-* /var/lib/apt/lists/*


FROM pingcap/tidb-enterprise-tools AS tidb-enterprise-tools
RUN apk add binutils curl \
    && curl -sS -L http://download.pingcap.org/tidb-v3.0-linux-amd64.tar.gz | \
         tar -C / --strip-components=2 -xvzf - \
             tidb-v3.0-linux-amd64/bin/tikv-ctl \
             tidb-v3.0-linux-amd64/bin/pd-ctl \
    && curl -L -o /kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x kubectl \
    && strip importer loader mydumper syncer tikv-ctl pd-ctl sync_diff_inspector ddl_checker kubectl

FROM stedolan/jq as jq

FROM ubuntu:18.04
RUN apt-get update && apt-get install -y \
    curl \
    dnsutils \
    iputils-ping \
    less \
    libreadline5 \
    vim \
    && rm -rf /var/lib/apt/lists/*


COPY --from=mysql-client /install/* /usr/local/bin/
COPY --from=tidb-enterprise-tools /importer /loader /mydumper /syncer /tikv-ctl /pd-ctl /sync_diff_inspector /ddl_checker /kubectl /usr/local/bin/
COPY --from=jq /usr/local/bin/jq /usr/local/bin/
WORKDIR /root
COPY README.container README
COPY motd.bash .motd.bash
RUN echo source .motd.bash >> .bashrc
ENTRYPOINT ["/usr/bin/env","bash"]
