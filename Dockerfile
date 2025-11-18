# ============================================================
# Stage 1: Builder
# ============================================================
FROM debian:bookworm-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    ca-certificates \
    libssl-dev \
    make \
    && rm -rf /var/lib/apt/lists/*


# Install Zig
ARG ZIG_VERSION=0.15.1
RUN curl -L "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" | tar -xJ -C /usr/local && \
    ln -s "/usr/local/zig-x86_64-linux-${ZIG_VERSION}/zig" /usr/local/bin/zig

# Set working directory
WORKDIR /app

# Copy dependency files first (for better caching)
COPY build.zig build.zig.zon ./

# Copy source code
COPY src ./src

# Copy the built binary from builder stage
CMD ["zig", "build", "test"]

