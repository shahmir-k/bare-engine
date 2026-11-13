#!/usr/bin/env bash
# Builds libbare.so for linux-aarch64 from Bare's pinned source into OUT.
# Runs in the Dockerfile's image (the reproducible way) or on a host with the
# same zig, CMake and Node. The source and build live at fixed paths under
# WORK, so no host path can reach the output.
set -euo pipefail

out=${1:?usage: build-engine.sh OUT}
work=${WORK:-/work}
bare_rev=1330332d7f60185b5e0e38e5779cebbecc3c11d7
# The prebuilt V8, libc++ and libjs that Bare mirrors (drive checkout 159);
# a different download is a different engine.
prebuilts="37bcaa64518f1026f019e1bf66fa435e20186f0522bf6b74ed37c6b1f49cff57  libv8.a
04e382ff34d1e37c5bdc19b2c4a11edbc6c56911c12b9e7ff0d4dcd9708dfedd  libc++.a
6905d6abdfbfaa6f06552c658d6adf81874ea1281c6b1cd4e801ee1db377e991  libjs.a"

zig version
cmake --version | head -1
node --version
rm -rf "$work/bare" "$work/build"
mkdir -p "$work" "$out"
git clone -q https://github.com/holepunchto/bare.git "$work/bare"
git -C "$work/bare" checkout -q --detach "$bare_rev"
export SOURCE_DATE_EPOCH=$(git -C "$work/bare" log -1 --format=%ct)
npm ci --ignore-scripts --no-audit --no-fund --prefix "$work/bare"

# bare-pack 2.2.2 writes the modules of Bare's embedded JS bundle in the order
# its concurrent reads finish, so two builds of the same source differ. Sort
# them by URL (the bundle is looked up by URL; the order changes nothing at
# run time). Only the exact file this patch was written for is patched.
pack="$work/bare/node_modules/bare-pack/index.js"
echo "4f8bbe04c07e49581451a805666b1462f61e48c6acb9055a6696d4c16445d97e  $pack" | sha256sum -c -
sed -i 's|^  for (const { url, source, imports } of dependencies) {$|  dependencies.sort((a, b) => (a.url.href < b.url.href ? -1 : a.url.href > b.url.href ? 1 : 0))\n\n&|' "$pack"
grep -q '^  dependencies.sort(' "$pack"

cmake -S "$work/bare" -B "$work/build" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER=zig -DCMAKE_C_COMPILER_ARG1=cc -DCMAKE_CXX_COMPILER=zig -DCMAKE_CXX_COMPILER_ARG1=c++ \
  -DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu -DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-gnu \
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DBARE_PREBUILDS=ON \
  -DCMAKE_C_LINK_LIBRARY_USING_WHOLE_ARCHIVE:STRING='-Wl,--whole-archive <LINK_ITEM> -Wl,--no-whole-archive' \
  -DCMAKE_C_LINK_LIBRARY_USING_WHOLE_ARCHIVE_SUPPORTED:BOOL=TRUE \
  -DCMAKE_SHARED_LINKER_FLAGS:STRING='-lunwind -Wl,-s'
(cd "$work/build/linux-arm64" && printf '%s\n' "$prebuilts" | sha256sum -c -)
# Generated only by a native configure; the cross build needs them empty.
mkdir -p "$work/build/_deps/github+holepunchto+libnormalize-build/include/normalize" \
  "$work/build/_deps/github+holepunchto+libnormalize-build/normalize" \
  "$work/build/_deps/github+holepunchto+libidna-build/include/idna" \
  "$work/build/_deps/github+holepunchto+libidna-build/idna"
cmake --build "$work/build" --target bare_shared --parallel "$(nproc)"

cp "$work/build/libbare.so" "$out/libbare.so"
if grep -aqE "$work|/home/|/Users/" "$out/libbare.so"; then echo "a build path reached libbare.so" >&2; exit 1; fi
(cd "$out" && sha256sum libbare.so | tee libbare.so.sha256 && wc -c < libbare.so)
