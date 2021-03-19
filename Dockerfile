FROM pingcap/tidb-enterprise-tools AS tidb-enterprise-tools
RUN apk add binutils curl \
    && curl -sS -L http://download.pingcap.org/tidb-v3.0-linux-amd64.tar.gz | \
         tar -C / --strip-components=2 -xvzf - \
             tidb-v3.0-linux-amd64/bin/tikv-ctl \
             tidb-v3.0-linux-amd64/bin/pd-ctl \
    && curl -L -o /kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x kubectl \
    && curl -L https://download.pingcap.org/dumpling-nightly-linux-amd64.tar.gz | tar -C / -xvzf - \
    && strip importer loader mydumper syncer tikv-ctl pd-ctl sync_diff_inspector ddl_checker kubectl

FROM stedolan/jq as jq

FROM golang as usql
RUN GO111MODULE=on go get -tags 'mysql no_oracle no_impala no_spanner no_voltdb no_sqlite3 no_couchbase no_postgres no_memsql no_mssql' github.com/xo/usql

FROM ubuntu
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -yq \
    curl \
    dnsutils \
    iputils-ping \
    less \
    libreadline5 \
    vim \
    screen \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*


COPY --from=tidb-enterprise-tools /importer /loader /mydumper /syncer /tikv-ctl /pd-ctl /sync_diff_inspector /ddl_checker /kubectl /dumpling /usr/local/bin/
COPY --from=jq /usr/local/bin/jq /usr/local/bin/
COPY --from=usql /go/bin/usql /usr/local/bin/
WORKDIR /root
COPY README.container README
COPY motd.bash .motd.bash
RUN echo source .motd.bash >> .bashrc
ENTRYPOINT ["/usr/bin/env","bash"]
