FROM cgr.dev/chainguard/node@sha256:8b10fa8fe4886720a1081826dfacddbae3348ee70e007758eee13b26abaf8d99 AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src

FROM cgr.dev/chainguard/node@sha256:f2a8ed64ec02cef2e53c76d1255d0917e749570af251e32e99f54cda1076cc8d
WORKDIR /app
COPY --from=builder /app /app
EXPOSE 3000
CMD ["src/index.js"]
