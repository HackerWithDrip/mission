# build stage
FROM node:18-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --silent
COPY . .
RUN npm run build

# production stage
FROM nginx:1.25-alpine
WORKDIR /usr/share/nginx/html

# copy nginx configs
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# copy built React app
COPY --from=build /app/build /usr/share/nginx/html

# fix permissions for OpenShift random UID
RUN mkdir -p /var/cache/nginx /var/cache/nginx/proxy_temp /var/run /var/log/nginx /tmp \
    && chgrp -R 0 /var/cache/nginx /var/run /var/log/nginx /tmp /usr/share/nginx/html /etc/nginx/conf.d /etc/nginx \
    && chmod -R g+rwX /var/cache/nginx /var/run /var/log/nginx /tmp /usr/share/nginx/html /etc/nginx/conf.d /etc/nginx

# run as non-root (OpenShift will override with random UID anyway)
USER 1002890000

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
