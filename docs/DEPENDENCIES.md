# Intel macOS dependency map

## Missing upstream Intel build

Zephium `v1.0.5` publishes an Apple Silicon macOS DMG and a Windows x64 installer. Its macOS release job targets `aarch64-apple-darwin`; this repository adds an Intel build path using the same source and dependency pins. It does not downgrade the system engine or bypass upstream runtime admission.

## Sources used

- Zephium source: https://github.com/zephium-browser/Zephium
- Default release: https://github.com/zephium-browser/Zephium/releases/tag/v1.0.5
- Exact source: https://github.com/zephium-browser/Zephium/tree/1c4846cec9a9a0ab40ed45113d69a3f3c244d279
- Upstream release workflow: https://github.com/zephium-browser/Zephium/blob/v1.0.5/.github/workflows/release.yml
- Upstream contribution guide: https://github.com/zephium-browser/Zephium/blob/v1.0.5/CONTRIBUTING.md
- macOS admission policy: https://github.com/zephium-browser/Zephium/blob/v1.0.5/crates/zephium-core/src/macos.rs
- Tauri configuration and CLI: https://v2.tauri.app/reference/config/ and https://v2.tauri.app/reference/cli/
- Scaffold references: https://github.com/rezzamohammad/herdr-app-intel-mac-builds and https://github.com/rezzamohammad/mixar-ai-feat-blender-5x-intel-mac-builds

## Build contract

1. Check out the pinned upstream source and this repository separately as `build-automation/`.
2. Validate the upstream integration hashes in `scripts/intel/prepare-source.py` before writing the `INTEL-BUILD` updater change.
3. Read Rust from `rust-toolchain.toml`, Node from `.node-version`, pnpm from `package.json`, and app version from `desktop/Cargo.toml`.
4. Require a native `x86_64` macOS host, `x86_64-apple-darwin` rustc, and matching Node/pnpm pins.
5. Install JavaScript dependencies with `pnpm install --frozen-lockfile`; generate upstream third-party notices with its own script and locked Cargo metadata.
6. Build with upstream's Tauri CLI, default features and frontend build hook, targeting `x86_64-apple-darwin` with Cargo `--locked`. Merge only the community bundle settings; retain production CSP, entitlements, legal-resource mappings and macOS/WebKit admission.
7. Validate and archive the signed app before packing it with `hdiutil`. Retry only `Resource busy`, with a maximum of three attempts; preserve the app archive if DMG creation still fails. The strict path also verifies every Mach-O is Intel-only, licenses, version, system linkage, entitlements, mounted app and Applications link.

Default pins at `v1.0.5`: Rust `1.95.0`, Node `24.18.0`, pnpm `11.17.0`, Tauri CLI `2.12.4`. These are read from source, not separate workflow copies.

Reviewed SHA-256 integration hashes:

```text
4a4a3cc13fde32c0551346d107ea2f6d14e8fcf35d4229f311addb30c13cc074  desktop/src/updates.rs
c8e52e3b84ebe63fa2b60d0c590d1ec564742eedd6b3d88a0f0bcccd203f4d06  desktop/tauri.conf.json
b2b9cf8d6c713274211b5ff9ef2f5afc69b131add1e4a976fe07eaa6a3a63a1c  desktop/tauri.macos.conf.json
20556b045e9cc49a080f9908829ae3419942eb778f77377eec61351148556b05  scripts/release/third_party_notices.py
```

## Rust, frontend and native dependencies

Rust crates come from upstream `Cargo.lock`, including its reviewed vendored forks. Frontend packages come from `pnpm-lock.yaml`. No third-party Intel dependency archive is substituted. macOS supplies WebKit; Xcode supplies the SDK and native compiler. System engine version checks remain owned by upstream source.

Upstream's notices generator inventories its configured target dependency graphs and frontend production dependencies. The build retains its generated notice file and blocker license resources. Do not trim its license inventory merely because this repository builds one architecture.

## Community build and release policy

The single updater source edit sets `SUPPORTED` to `false`; it uses the existing upstream unavailable state and prevents automatic checks. The merged Tauri configuration also clears endpoints and disables updater artifacts. There is no new update service or signing key. Ad hoc signing uses `signingIdentity: "-"`; the app retains upstream entitlements. The DMG is unsigned and not notarized.

Strict artifact builds run ordinary engine/advisory checks and upstream macOS policy unit tests. Publication additionally requires `cargo xtask check-release-engine-security`. This may fail when pinned upstream review deadlines or blocker data expire. Native policy tests run with Cargo's runner set to `env`, avoiding the upstream development signing helper and any keychain prompt. The workflow never launches the browser against a user profile.

## Maintenance arrangement

`rezzamohammad/zephium-intel-mac-builds` owns the automation; `hsnulll/zephium-intel-mac-builds` is its build fork. Sync the fork before dispatching. Neither workflow runs on push, pull requests or a schedule. Both use `macos-15-intel`, with a bounded 180-minute timeout and seven-day legacy or thirty-day strict artifact retention.
