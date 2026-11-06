FROM node:22-alpine AS frontend-builder

WORKDIR /app/admin-ui
COPY admin-ui/package.json admin-ui/pnpm-lock.yaml admin-ui/.npmrc admin-ui/pnpm-workspace.yaml ./
RUN npm install -g pnpm
RUN pnpm install --frozen-lockfile
COPY admin-ui ./
RUN pnpm build

FROM rust:1.92-alpine AS builder

RUN apk add --no-cache musl-dev perl make

WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
COPY src ./src
COPY --from=frontend-builder /app/admin-ui/dist /app/admin-ui/dist

RUN cargo build --release --no-default-features

FROM alpine:3.21

LABEL org.opencontainers.image.title="kiro.rs_railway" \
      org.opencontainers.image.description="Anthropic <-> Kiro API proxy, Railway 部署分支"

RUN apk add --no-cache ca-certificates

WORKDIR /app
COPY --from=builder /app/target/release/kiro-rs /app/kiro-rs

# 容器内必须监听所有网卡；PORT 由 Railway 等平台注入，不在此写死
ENV HOST=0.0.0.0 \
    RUST_LOG=info

# 不声明 VOLUME：Railway 构建器直接拒绝 Dockerfile 里的 VOLUME 指令
# （docker VOLUME at Line 35 is not supported, use Railway Volumes）
# 需要持久化 token 时，在平台侧挂 Volume 到 /app/config
EXPOSE 8080

CMD ["./kiro-rs", "-c", "/app/config/config.json", "--credentials", "/app/config/credentials.json"]
