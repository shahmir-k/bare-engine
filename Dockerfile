# The canonical linux-aarch64 Bare engine (libbare.so), rebuilt by anyone:
#   docker build -t bare-engine .
#   docker run --rm -v "$PWD/out:/out" bare-engine
# Every tool that shapes the output bytes is pinned by hash: the base image,
# zig (its bundled LLVM is the compiler), CMake and Node (which mirrors the
# prebuilt V8). The build checks the prebuilts against their recorded hashes.
FROM debian@sha256:78d2f66e0fec9e5a39fb2c72ea5e052b548df75602b5215ed01a17171529f706

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git libatomic1 make xz-utils \
    && rm -rf /var/lib/apt/lists/*

ARG ZIG=zig-x86_64-linux-0.15.2
ARG ZIG_SHA256=02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239
ARG CMAKE=cmake-4.2.3-linux-x86_64
ARG CMAKE_SHA256=5bb505d5e0cca0480a330f7f27ccf52c2b8b5214c5bba97df08899f5ef650c23
ARG NODE=node-v24.12.0-linux-x64
ARG NODE_SHA256=bdebee276e58d0ef5448f3d5ac12c67daa963dd5e0a9bb621a53d1cefbc852fd
RUN set -eu; cd /opt; \
    curl -fsSLo z.tar.xz https://ziglang.org/download/0.15.2/$ZIG.tar.xz; \
    curl -fsSLo c.tar.gz https://github.com/Kitware/CMake/releases/download/v4.2.3/$CMAKE.tar.gz; \
    curl -fsSLo n.tar.xz https://nodejs.org/dist/v24.12.0/$NODE.tar.xz; \
    printf '%s  z.tar.xz\n%s  c.tar.gz\n%s  n.tar.xz\n' $ZIG_SHA256 $CMAKE_SHA256 $NODE_SHA256 | sha256sum -c -; \
    tar -xJf z.tar.xz && tar -xzf c.tar.gz && tar -xJf n.tar.xz && rm z.tar.xz c.tar.gz n.tar.xz; \
    ln -s /opt/$ZIG/zig /usr/local/bin/zig; \
    ln -s /opt/$CMAKE/bin/cmake /usr/local/bin/cmake; \
    ln -s /opt/$NODE/bin/node /usr/local/bin/node; ln -s /opt/$NODE/bin/npm /usr/local/bin/npm; \
    printf '#!/bin/sh\nexec zig ar "$@"\n' > /usr/local/bin/ar; \
    printf '#!/bin/sh\nexec zig ranlib "$@"\n' > /usr/local/bin/ranlib; \
    chmod +x /usr/local/bin/ar /usr/local/bin/ranlib

COPY build-engine.sh /usr/local/bin/build-engine.sh
ENTRYPOINT ["/usr/local/bin/build-engine.sh", "/out"]
