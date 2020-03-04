FROM ubuntu:18.04 AS mysql-client
RUN sed -i 's/# \(deb-src .*\)$/\1/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
        git cmake gcc g++ gnutls-dev libncurses5-dev libcurl4-gnutls-dev \
    && git clone https://github.com/kolbe/mariadb-server --depth=1 --branch=tidb-client /client \
    && cd /client \
    && cmake . -DWITHOUT_SERVER=ON -DCPACK_STRIP_FILES=ON -DMYSQL_TCP_PORT=4000 \
    && make -j install \
    && rm -rf /client /var/lib/apt/lists/*


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
    less \
    libreadline5 \
    vim \
    && rm -rf /var/lib/apt/lists/*


COPY --from=mysql-client /usr/local/mysql/bin/mysql /usr/local/bin/
COPY --from=tidb-enterprise-tools /importer /loader /mydumper /syncer /tikv-ctl /pd-ctl /sync_diff_inspector /ddl_checker /kubectl /usr/local/bin/
COPY --from=jq /usr/local/bin/jq /usr/local/bin/
WORKDIR /root
COPY README.container README
COPY motd.bash .motd.bash
RUN echo source .motd.bash >> .bashrc
ENTRYPOINT ["/usr/bin/env","bash"]
