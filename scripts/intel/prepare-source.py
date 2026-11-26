#!/usr/bin/env python3
"""Validate the upstream contract, then disable official self-updates."""
import hashlib
import json
from pathlib import Path
import re
import sys
import tomllib

PINS = {
    "desktop/src/updates.rs": "4a4a3cc13fde32c0551346d107ea2f6d14e8fcf35d4229f311addb30c13cc074",
    "desktop/tauri.conf.json": "c8e52e3b84ebe63fa2b60d0c590d1ec564742eedd6b3d88a0f0bcccd203f4d06",
    "desktop/tauri.macos.conf.json": "b2b9cf8d6c713274211b5ff9ef2f5afc69b131add1e4a976fe07eaa6a3a63a1c",
    "scripts/release/third_party_notices.py": "20556b045e9cc49a080f9908829ae3419942eb778f77377eec61351148556b05",
}


def prepare(root):
    for name, expected in PINS.items():
        actual = hashlib.sha256((root / name).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"upstream {name} changed (sha256 {actual}); review the Intel integration before building")
    for name in ("Cargo.lock", "pnpm-lock.yaml", "LICENSE", "desktop/Entitlements.plist",
                 "assets/blocker-seed/v1/NOTICE", "vendor/tauri/Cargo.toml"):
        if not (root / name).is_file():
            raise ValueError(f"required source file missing: {name}")
    rust = tomllib.loads((root / "rust-toolchain.toml").read_text())["toolchain"]["channel"]
    node = (root / ".node-version").read_text().strip()
    pnpm = json.loads((root / "package.json").read_text())["packageManager"]
    version = tomllib.loads((root / "desktop/Cargo.toml").read_text())["package"]["version"]
    for name, value, pattern in (("rust", rust, r"\d+\.\d+\.\d+"),
                                 ("node", node, r"\d+\.\d+\.\d+"),
                                 ("pnpm", pnpm, r"pnpm@\d+\.\d+\.\d+"),
                                 ("version", version, r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?")):
        if not re.fullmatch(pattern, value):
            raise ValueError(f"invalid upstream {name} pin: {value!r}")
    updates = root / "desktop/src/updates.rs"
    old = 'const SUPPORTED: bool = !cfg!(debug_assertions) && cfg!(any(target_os = "macos", windows));'
    new = '// INTEL-BUILD: community builds update manually; never use the official feed.\nconst SUPPORTED: bool = false;'
    text = updates.read_text()
    if text.count(old) != 1:
        raise ValueError("updater guard no longer matches the reviewed integration")
    updates.write_text(text.replace(old, new))
    return {"rust": rust, "node": node, "pnpm": pnpm, "version": version}


if __name__ == "__main__":
    try:
        for key, value in prepare(Path(sys.argv[1] if len(sys.argv) > 1 else ".")).items():
            print(f"{key}={value}")
    except (OSError, ValueError, KeyError) as error:
        sys.exit(f"error: {error}")
