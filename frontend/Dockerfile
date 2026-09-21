FROM node:24-alpine AS build
WORKDIR /workspace
COPY package*.json ./
RUN npm ci --ignore-scripts
COPY . .
RUN npm run build
FROM nginxinc/nginx-unprivileged:1.28-alpine
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/dist/frontend/browser/ /usr/share/nginx/html/
