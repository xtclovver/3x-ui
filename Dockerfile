# ========================================================
# Stage: Builder
# ========================================================
FROM golang:1.24-alpine AS builder
WORKDIR /app
ARG TARGETARCH

RUN apk --no-cache --update add \
  build-base \
  gcc \
  wget \
  unzip

COPY . .

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
RUN go build -ldflags "-w -s" -o build/x-ui main.go
RUN sed -i 's/\r$//' ./DockerInit.sh && chmod +x ./DockerInit.sh
RUN ./DockerInit.sh "$TARGETARCH"

# ========================================================
# Stage: Final Image of 3x-ui
# ========================================================
FROM alpine
ENV TZ=Asia/Tehran
WORKDIR /app

RUN apk add --no-cache --update \
  ca-certificates \
  tzdata \
  fail2ban \
  bash \
  supervisor \
  nginx

COPY --from=builder /app/build/ /app/
COPY --from=builder /app/DockerEntrypoint.sh /app/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui
COPY configs/nginx.conf /etc/nginx/http.d/default.conf
COPY configs/supervisord.conf /etc/supervisord.conf

# Configure fail2ban
RUN rm -f /etc/fail2ban/jail.d/alpine-ssh.conf \
  && cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
  && sed -i "s/^\[ssh\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
  && sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf

  RUN sed -i 's/\r$//' /app/DockerEntrypoint.sh && \
    sed -i 's/\r$//' /usr/bin/x-ui && \
    chmod +x \
    /app/DockerEntrypoint.sh \
    /app/x-ui \
    /usr/bin/x-ui

ENV XUI_ENABLE_FAIL2BAN="true"
VOLUME [ "/etc/x-ui" ]
EXPOSE 2053
CMD [ "./x-ui" ]
ENTRYPOINT [ "/app/DockerEntrypoint.sh" ]
