FROM cgr.dev/chainguard/node:latest-dev AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src

FROM cgr.dev/chainguard/node:latest
WORKDIR /app
COPY --from=builder /app /app
EXPOSE 3000
CMD ["src/index.js"]
