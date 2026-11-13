# bare-engine

A reproducible build of [Bare](https://github.com/holepunchto/bare)'s shared library,
`libbare.so`, for **linux-aarch64**: the Pear/Bare engine that apps on Linux handhelds share
through [pear-runtime-store](#related). Anyone can rebuild it and check the hash instead of
trusting a binary.

## Expected result

| | |
|---|---|
| File | `libbare.so` (SONAME `libbare.so`, needs glibc ≥ 2.29) |
| SHA-256 | `52dd593a08581d5b4d3175541eedac5143ffe81c047b8c51bd59e493a811259e` |
| Size | 63,707,248 bytes |
| Bare | 1.32.0, commit `1330332d7f60185b5e0e38e5779cebbecc3c11d7` |

## Rebuild it

```sh
docker build -t bare-engine .
docker run --rm -v "$PWD/out:/out" bare-engine
sha256sum out/libbare.so    # 52dd593a…259e
```

About 1.3 GB of tools are downloaded into the image; the build needs network access
(GitHub, npm, and Bare's prebuilt V8 drive).

## What is pinned

- **Base image**: Debian bookworm, by digest.
- **zig 0.15.2** from ziglang.org, by SHA-256. zig is the compiler (`zig cc` / `zig c++`
  targeting `aarch64-linux-gnu`), and its bundled LLVM (20.1.2) decides the machine code.
  A zig built against another LLVM (Homebrew's, for example) gives a different file.
- **CMake 4.2.3** and **Node 24.12.0** from their official releases, by SHA-256. Node only
  runs Bare's build helpers. The same hash has been produced with CMake 4.4.3 and Node 26.7.0.
- **Bare's source** at the commit above. Its dependencies are pinned by Bare itself
  (`package-lock.json`, and commits in its CMake files).
- **The prebuilt V8, libc++ and libjs** that Bare mirrors (drive
  `krmguqnh75rud4iieqgmzyqoza415cbu68payoww65ii9fzt5n4o`, checkout 159). The build stops if
  they don't match:

  | File | SHA-256 |
  |---|---|
  | `libv8.a` | `37bcaa64518f1026f019e1bf66fa435e20186f0522bf6b74ed37c6b1f49cff57` |
  | `libc++.a` | `04e382ff34d1e37c5bdc19b2c4a11edbc6c56911c12b9e7ff0d4dcd9708dfedd` |
  | `libjs.a` | `6905d6abdfbfaa6f06552c658d6adf81874ea1281c6b1cd4e801ee1db377e991` |

## One patch: the JS bundle's order

Bare embeds its own JavaScript as a bundle made by `bare-pack`. bare-pack 2.2.2 writes the
modules in the order its concurrent file reads finish, so two builds of the same source
differ. `build-engine.sh` sorts them by URL before they are written. Modules are looked up by
URL, so nothing changes when the engine runs. The patch is applied only to the exact
`bare-pack/index.js` it was written for (checked by SHA-256); any other version stops the
build.

## Verified

On 2026-11-13 the same `52dd593a…` came from two runs of this image and from a plain Linux
host with different tool versions and paths. The build also refuses an output that contains
a build path.

## Related

- [Bare](https://github.com/holepunchto/bare): the runtime.
- pear-runtime-store: the library that keeps one verified copy of this engine per device.
  Apps check the engine against the hash above before loading it.

## License

The files in this repository are under the Apache License 2.0 (`LICENSE`), like Bare.
