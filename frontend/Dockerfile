FROM node:22-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci --NODE_ENV=production

COPY . .

RUN npm run build

FROM nginxinc/nginx-unprivileged:alpine

COPY --from=builder /usr/src/app/dist /usr/share/nginx/html
COPY default.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
CMD wget -q --spider http://127.0.0.1:8080 || exit 1

USER 101

CMD ["nginx", "-g", "daemon off;"]