FROM alpine:3.20

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    bind-tools

COPY update-dns.sh /update-dns.sh

entrypoint ["/update-dns.sh"]
