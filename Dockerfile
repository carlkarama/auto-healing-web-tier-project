FROM nginx:1.30.4-alpine@sha256:dc5069ad14f19660b141b21236140b91656bf89bbc3e2417c70ae650cd66104c

LABEL org.opencontainers.image.source="https://github.com/carlkarama/auto-healing-web-tier-project" \
      org.opencontainers.image.description="NGINX welcome page for the auto-healing web tier"

ENV WEB_INSTANCE_ID=local \
    NGINX_ENVSUBST_FILTER="^WEB_INSTANCE_ID$"

COPY container/default.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:80/ || exit 1
