FROM node:26-alpine AS build
WORKDIR /app
COPY package.json package-lock.json build.mjs ./
RUN npm ci
COPY src ./src
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/frontend/browser /usr/share/nginx/html
EXPOSE 8080
