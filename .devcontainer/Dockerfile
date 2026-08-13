FROM archlinux:base-devel

RUN pacman -Syu --noconfirm --needed \
    git curl wget tar xz unzip openbsd-netcat \
    && pacman -Scc --noconfirm

ARG ZIG_VERSION=0.16.0
ARG TARGETARCH

# Install Zig
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64) ZIG_ARCH="x86_64" ;; \
        aarch64) ZIG_ARCH="aarch64" ;; \
        *) echo "Unsupported arch: $(uname -m)" && exit 1 ;; \
    esac; \
    curl -fLO "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz"; \
    tar -xf "zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz"; \
    mv "zig-${ZIG_ARCH}-linux-${ZIG_VERSION}" /usr/local/zig; \
    rm "zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz"; \
    ln -s /usr/local/zig/zig /usr/local/bin/zig

ENV PATH="/usr/local/zig:${PATH}"

# Install ZLS from source, pinned to matching Zig version
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64) ZLS_ARCH="x86_64" ;; \
        aarch64) ZLS_ARCH="aarch64" ;; \
        *) echo "Unsupported arch: $(uname -m)" && exit 1 ;; \
    esac; \
    curl -fLO "https://github.com/zigtools/zls/releases/download/0.16.0/zls-${ZLS_ARCH}-linux.tar.xz"; \
    tar -xf "zls-${ZLS_ARCH}-linux.tar.xz" -C /usr/local/bin zls; \
    rm "zls-${ZLS_ARCH}-linux.tar.xz"; \
    chmod +x /usr/local/bin/zls

RUN useradd -m -s /bin/bash usr

USER usr

WORKDIR /workspaces
