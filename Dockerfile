# syntax=docker/dockerfile:1

# ─── Stage 1: Build ──────────────────────────────────────────────────────────
FROM rust:1.75-bookworm AS builder

WORKDIR /build

# --- Layer-cache optimisation: build dependencies first ----------------------
COPY Cargo.toml Cargo.lock ./

# Create dummy source files matching every [[bin]] and src/lib.rs so that
# `cargo build` resolves and compiles *only* the dependency graph.
RUN mkdir -p src/bin \
    && echo "fn main() {}" > src/main.rs \
    && echo "fn main() {}" > src/scarb_main.rs \
    && echo "fn main() {}" > src/bin/inspect_ir.rs \
    && touch src/lib.rs

RUN cargo build --release \
    --bin shdr \
    --bin shadowhare \
    --bin scarb-shdr \
    --bin scarb-shadowhare

# --- Now copy the real source and rebuild (only app code recompiles) ---------
RUN rm -rf src/
COPY src/ src/

RUN cargo build --release \
    --bin shdr \
    --bin shadowhare \
    --bin scarb-shdr \
    --bin scarb-shadowhare

# ─── Stage 2: Runtime ────────────────────────────────────────────────────────
FROM debian:bookworm-slim

# OCI image labels
LABEL org.opencontainers.image.title="shadowhare" \
      org.opencontainers.image.description="Production-grade static analyzer for Cairo/Starknet smart contracts" \
      org.opencontainers.image.version="0.1.0" \
      org.opencontainers.image.source="https://github.com/br0wnD3v/shadowhare" \
      org.opencontainers.image.licenses="MIT OR Apache-2.0"

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --system shadowhare \
    && useradd --system --gid shadowhare --create-home shadowhare

COPY --from=builder /build/target/release/shdr /usr/local/bin/shdr
COPY --from=builder /build/target/release/shadowhare /usr/local/bin/shadowhare
COPY --from=builder /build/target/release/scarb-shdr /usr/local/bin/scarb-shdr
COPY --from=builder /build/target/release/scarb-shadowhare /usr/local/bin/scarb-shadowhare

# Health check: verify the binary is functional
HEALTHCHECK --interval=60s --timeout=5s --start-period=5s --retries=3 \
    CMD ["shdr", "--help"]

USER shadowhare

ENTRYPOINT ["shdr"]
CMD ["--help"]
