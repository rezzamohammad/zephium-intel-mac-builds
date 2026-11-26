# Zephium — Intel macOS Builds

Reproducible **Intel-only (`x86_64`) macOS builds** of [Zephium](https://zephium.app/), a native Rust browser and work environment with a Tauri + Svelte interface.

> This is an unofficial community build. It is not affiliated with or endorsed by the Zephium project. Zephium remains a separate project; see the original project and license notices before redistribution.

## Download

Open **Releases** and download the `.dmg` for your Intel Mac once a release has been published. The strict workflow produces SHA-256 checksums and a build manifest alongside its DMG artifact. This repository does not ship a prebuilt DMG until a build has passed and its output has been published.

Builds use the official [zephium-browser/Zephium](https://github.com/zephium-browser/Zephium) source project. Both workflows read `ZEPHIUM_SOURCE_REPOSITORY` and `ZEPHIUM_SOURCE_REF`, defaulting to the official repository at the immutable `v1.0.5` commit `1c4846cec9a9a0ab40ed45113d69a3f3c244d279`.

- Target: Intel `x86_64`, not universal and not Apple Silicon
- Build output: `Zephium.app`, `zephium-macos-x86_64.app.tar.gz` and `Zephium-macOS-x86_64.dmg`
- Platform requirement: upstream declares macOS 14.0 in the bundle and also checks the installed macOS/Safari/WebKit versions at startup. Those checks are retained.

## Install

1. Download the `.dmg` from Releases, or the completed workflow artifact from Actions.
2. Open it and drag `Zephium.app` to `Applications`.
3. If macOS blocks this unsigned community build, right-click the app and choose **Open** once. If necessary, remove only the quarantine attribute from the app you downloaded:

```bash
xattr -cr /Applications/Zephium.app
```

Only run that command for an artifact you trust and have verified with the published SHA-256 checksum. The app uses upstream's `app.zephium` identity and profile; back up an existing Zephium profile before replacing another installation.

## Why a custom Intel build integration is required

Zephium's `v1.0.5` release publishes macOS installers for Apple Silicon only. Its upstream macOS release workflow targets `aarch64-apple-darwin` and requires Apple Developer ID signing, notarization and the official updater signing key.

This repository builds the pinned source natively on an Intel runner for `x86_64-apple-darwin`. It uses the upstream Rust, Node and pnpm pins and frozen dependency lockfiles. The community configuration requests an ad hoc signature, retains upstream entitlements and legal resources, and disables updater artifacts. A small source change marked `INTEL-BUILD` sets the updater's `SUPPORTED` guard to `false`, so the app neither schedules nor offers updates from the official feed. The configuration also clears that feed's endpoints.

[`scripts/intel/prepare-source.py`](scripts/intel/prepare-source.py) checks SHA-256 pins for the upstream updater, Tauri configurations and notices generator before modifying anything. A changed integration file fails instead of silently applying stale logic. The resulting `community-build.patch` is included with the build output.

[`scripts/intel/make-dmg.sh`](scripts/intel/make-dmg.sh) creates a drag-to-Applications DMG with `hdiutil`; it does not sign, notarize or staple the DMG. If macOS reports `Resource busy`, creation is retried at most three times; other errors fail immediately. The signed app is archived before DMG creation and retained in failure artifacts, so a disk-image failure does not discard the compiled bundle.

See [DEPENDENCIES.md](docs/DEPENDENCIES.md) for the dependency map and source links.

## Workflows

- **Legacy/manual:** [`build-intel-legacy.yml`](.github/workflows/build-intel-legacy.yml) is the minimal build path. Run it from **Actions → Build Intel DMG (legacy)**. It checks the source integration and toolchains, builds the app, verifies its signature and main executable architecture, and uploads a short-retention DMG artifact with the source patch and community notice.
- **Strict/release:** [`build-intel-strict.yml`](.github/workflows/build-intel-strict.yml) is the recommended path. It also runs upstream engine/advisory checks and native macOS policy unit tests, scans every bundled Mach-O for Intel-only architecture, checks system-library linkage, ad hoc signing, entitlements, app version and notices, and mounts and validates the DMG. It uploads checksums, manifests and targeted logs, and can create a GitHub Release when given a tag such as `zephium-1.0.5-intel1`.

Both workflows first run a packaging regression check using a small signed Intel app with Tauri's `zephium-desktop` executable name. The check injects one `Resource busy` failure, then creates, verifies and mounts a real DMG without launching the fixture or touching a browser profile.

Both workflows are started manually; nothing runs on push or on a timer. The optional `release_tag` input adds upstream's `check-release-engine-security` gate before publication. Expired reviews or stale blocker seeds fail that gate; update and review the source integration rather than weakening the checks. An artifact-only build runs the ordinary upstream policy checks, which can emit review advisories.

The repository arrangement follows the Mixar and Herdr build repositories: maintain automation at [rezzamohammad/zephium-intel-mac-builds](https://github.com/rezzamohammad/zephium-intel-mac-builds), sync its fork at [hsnulll/zephium-intel-mac-builds](https://github.com/hsnulll/zephium-intel-mac-builds), and manually dispatch the build in that fork. Artifacts and any requested release belong to the repository where the workflow runs. Runner access and Actions billing follow GitHub's settings for that repository; this automation does not assume a subscription bypasses quota or runner availability.

## Verification

From an extracted strict workflow artifact, verify all published files before installation:

```bash
shasum -a 256 -c SHA256SUMS
hdiutil verify Zephium-macOS-x86_64.dmg
```

The strict workflow records executable architecture, native Mach-O counts, minimum macOS version (`minos`), linked libraries, signature type, upstream source commit, toolchain pins, automation commit and DMG checksum in `build-manifest.txt`.

## Limitations

- Intel macOS support is community-maintained. Successful compilation and bundle checks do not establish browser, WebKit, extension, media, credential or Work behavior on an Intel Mac.
- The app is ad hoc signed only; it is not Apple Developer ID signed or notarized by this repository.
- The app does not update itself. Install a newer DMG from Releases to update.
- Upstream's macOS/Safari/WebKit admission policy is retained; the bundle's macOS 14.0 metadata is not a claim that every Sonoma/Safari combination is accepted.
- The workflow does not launch the browser or touch an installed app or personal profile. Its native runtime coverage is limited to upstream macOS policy unit tests. A green strict workflow is not full upstream release qualification or Windows acceptance.

## License

The automation and documentation in this repository are licensed under the [Mozilla Public License 2.0](LICENSE), matching upstream Zephium. The DMG helper is adapted from the Herdr build repository and retains its [Apache License 2.0](docs/LICENSE-Apache-2.0.txt). The Zephium source and bundled dependencies retain their own licenses. The app ships upstream MPL, blocker CC-BY-SA/GPL notices, generated third-party notices and a community-build notice. The `INTEL-BUILD` modification is distributed as `community-build.patch`; its exact original source is linked in the manifest. Do not remove upstream license notices.

### Source configuration for maintainers

Both workflows default to the official `zephium-browser/Zephium` repository at the pinned `v1.0.5` commit. Set repository variables `ZEPHIUM_SOURCE_REPOSITORY` and `ZEPHIUM_SOURCE_REF` only if intentionally building an authorized fork or a different pinned checkout. The strict workflow's `upstream_ref` input overrides `ZEPHIUM_SOURCE_REF` for one run. For a private authorized checkout, add a fine-grained repository secret named `ZEPHIUM_SOURCE_TOKEN` with read-only Contents access.

When moving to a new upstream release, review changes to the updater, both Tauri configurations, legal resources and notices generator, update the SHA-256 pins in `prepare-source.py`, and update both workflow source defaults. Check toolchain requirements, frozen lockfiles and upstream release/security policy before dispatching. No Apple certificate or official updater private key is required for these community builds.
