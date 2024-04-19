# There's an issue with node:20-alpine.
# Docker deployment is canceled after 25< minutes.

FROM golang:1.22-alpine AS build_go

ENV RELEASE_TAG=v0.0.1
ENV CGO_ENABLED=0
RUN apk add curl tar make git
RUN git clone https://github.com/0xlek/portfwd.git /goapp
WORKDIR /goapp
RUN ls .

RUN go mod download
RUN make

FROM docker.io/library/node:18-alpine AS build_node_modules

# Copy Web UI
COPY src/ /app/
WORKDIR /app
RUN npm ci --omit=dev &&\
    mv node_modules /node_modules

# Copy build result to a new image.
# This saves a lot of disk space.
FROM docker.io/library/node:18-alpine
COPY --from=build_node_modules /app /app

# Move node_modules one directory up, so during development
# we don't have to mount it in a volume.
# This results in much faster reloading!
#
# Also, some node_modules might be native, and
# the architecture & OS of your development machine might differ
# than what runs inside of docker.
COPY --from=build_node_modules /node_modules /node_modules
COPY --from=build_go /goapp/portfwd /usr/bin/portfwd

RUN \
    # Enable this to run `npm run serve`
    npm i -g nodemon &&\
    # Workaround CVE-2023-42282
    npm uninstall -g ip &&\
    # Delete unnecessary files
    npm cache clean --force && rm -rf ~/.npm

# Install Linux packages
RUN apk add --no-cache \
    dpkg \
    dumb-init \
    iptables \
    iptables-legacy \
    wireguard-tools \
    curl

# Use iptables-legacy
RUN update-alternatives --install /sbin/iptables iptables /sbin/iptables-legacy 10 --slave /sbin/iptables-restore iptables-restore /sbin/iptables-legacy-restore --slave /sbin/iptables-save iptables-save /sbin/iptables-legacy-save

WORKDIR /app
COPY ./portfwd-config.yml ./config.yaml
ENV PORTFWD_CONFIG_FILE_PATH=/app/config.yaml
COPY ./run.sh ./run.sh
RUN chmod +x run.sh

# Expose Ports
EXPOSE 51820/udp
EXPOSE 51821/tcp

# Set Environment
ENV DEBUG=Server,WireGuard

# Run Web UI
#CMD ["tail", "-f", "/dev/null"]
CMD ["./run.sh"]
#CMD ["/usr/bin/dumb-init", "node", "server.js"]
