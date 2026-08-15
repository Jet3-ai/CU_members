# HuntDog macOS arm64 installer r2

This folder builds the second-generation HuntDog installer for Apple Silicon Macs.

The previous encrypted installer could decrypt and copy its payload, but the bundled PyInstaller executable failed immediately because the `zstandard` runtime dependency was missing. The r2 installer treats the executable self-test as an installation gate and separates two outcomes:

- `INSTALL_OK`: the executable and Agent adapter are installed and runnable.
- `DATA_STATE`: WeChat database discovery, keys, decryption, query, and coverage readiness.

The installer never runs `huntdog init` automatically. Initialization can scan WeChat process memory and, when macOS blocks access, the current HuntDog implementation may re-sign WeChat. That action requires the user's explicit approval.

## Build

```bash
python3 build_release.py \
  --binary /path/to/huntdog \
  --skill-source /path/to/wechat-huntdog \
  --output-dir dist
```

The builder creates both an extracted release folder and a ZIP with Unix executable permissions preserved.

## Validation

```bash
bash tests/smoke_test.sh dist/HuntDog-CyberUnion-macos-arm64-0.4.0-r2
```

The smoke test uses a temporary home directory and skips live WeChat access. A release still needs a separate real-machine readiness check with an authorized, logged-in WeChat account.
