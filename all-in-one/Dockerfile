#@NAME=all-in-one
FROM turbinelabs/envoy-simple:0.19.0

FROM turbinelabs/envtemplate:0.19.0

FROM turbinelabs/rotor:0.19.0

FROM phusion/baseimage:0.10.2

# upgrade/install deps
RUN apt-get update
RUN DEBIAN_FRONTEND="noninteractive" apt-get upgrade -y
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y git

# install node.js
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y nodejs

# install http-server
RUN npm install http-server -g

# install go
RUN curl -s -L -O https://storage.googleapis.com/golang/go1.10.3.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.10.3.linux-amd64.tar.gz
ENV GOPATH /go
ENV PATH "$PATH:/usr/local/go/bin:$GOPATH/bin"

# tbnctl
RUN go get github.com/turbinelabs/tbnctl
RUN go install github.com/turbinelabs/tbnctl
RUN mv $GOPATH/bin/tbnctl /usr/local/bin/tbnctl

# all-in-one driver
ADD driver/main/all-in-one-driver $GOPATH/src/github.com/turbinelabs/all-in-one-driver
RUN go get github.com/turbinelabs/all-in-one-driver
RUN go install github.com/turbinelabs/all-in-one-driver
RUN mv $GOPATH/bin/all-in-one-driver /usr/local/bin/all-in-one-driver
RUN mkdir -p /etc/service/driver
ADD bin/start-driver.sh /etc/service/driver/run
RUN chmod +x /etc/service/driver/run

# cleanup go
RUN rm -rf /usr/local/go
RUN rm -rf $GOPATH

# cleanup git
RUN DEBIAN_FRONTEND="noninteractive" apt-get remove -y git
RUN DEBIAN_FRONTEND="noninteractive" apt-get autoremove -y

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists* /tmp/* /var/tmp/*

# install envoy
COPY --from=0 /usr/local/bin/envoy /usr/local/bin/envoy
COPY --from=0 /usr/local/bin/start-envoy.sh /usr/local/bin/start-envoy.sh
COPY --from=0 /etc/envoy/bootstrap.conf.tmpl /etc/envoy/bootstrap.conf.tmpl
ADD bin/envoy.sh /etc/service/envoy/run
RUN chmod +x /etc/service/envoy/run
RUN mkdir -p /var/log/envoy

# install envtemplate
COPY --from=1 /usr/local/bin/envtemplate /usr/local/bin/envtemplate

# all-in-one shell utils
ADD scripts/envcheck.sh /usr/local/bin/envcheck.sh
RUN chmod +x /usr/local/bin/envcheck.sh

# rotor
ENV ROTOR_STATS_SOURCE all-in-one
COPY --from=2 /usr/local/bin/rotor* /usr/local/bin/
COPY --from=2 /usr/local/bin/rotor.sh /usr/local/bin/rotor.sh
ADD config/clusters.yml /opt/rotor/clusters.yml
ADD bin/rotor.sh /etc/service/rotor/run
RUN chmod +x /etc/service/rotor/run

# all-in-one server
ADD server/server.js /opt/all-in-one/server/server.js
ADD server/main.js /opt/all-in-one/server/main.js

RUN mkdir -p /etc/service/blue
ADD bin/start-blue.sh /etc/service/blue/run
RUN chmod +x /etc/service/blue/run
RUN mkdir -p /etc/service/green
ADD bin/start-green.sh /etc/service/green/run
RUN chmod +x /etc/service/green/run
RUN mkdir -p /etc/service/yellow
ADD bin/start-yellow.sh /etc/service/yellow/run
RUN chmod +x /etc/service/yellow/run

# all-in-one client
ENV ALL_IN_ONE_CLIENT_DIR /opt/all-in-one/client
ENV ALL_IN_ONE_CLIENT_PORT 8083
ADD client/create-workers.js /opt/all-in-one/client/create-workers.js
ADD client/index.html /opt/all-in-one/client/index.html
ADD client/start.sh /etc/service/client/run
RUN chmod +x /etc/service/client/run

# check time
ADD bin/check-time.sh /etc/my_init.d/01_check-time.sh
RUN chmod +x /etc/my_init.d/01_check-time.sh

# init
ADD bin/init.sh /etc/my_init.d/02_init.sh
RUN chmod +x /etc/my_init.d/02_init.sh

# Document that the service listens on port 80 and the admin port
EXPOSE 80 9999

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
