#!/usr/bin/env python3
"""Build the HuntDog r2 macOS arm64 release from an explicit whitelist."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PACKAGE_BASENAME = "HuntDog-CyberUnion-macos-arm64"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def detect_core_version(binary: Path) -> str:
    output = subprocess.check_output([str(binary), "--version"], text=True, timeout=30).strip()
    match = re.search(r"version\s+([^\s]+)", output)
    if not match:
        raise RuntimeError(f"Cannot parse core version from: {output}")
    return match.group(1)


def copy_file(src: Path, dst: Path, executable: bool = False) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    if executable:
        dst.chmod(0o755)


def write_zip(source_dir: Path, zip_path: Path) -> None:
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(source_dir.rglob("*")):
            relative = Path(source_dir.name) / path.relative_to(source_dir)
            info = zipfile.ZipInfo.from_file(path, arcname=str(relative))
            info.create_system = 3
            mode = path.stat().st_mode
            info.external_attr = (mode & 0xFFFF) << 16
            if path.is_dir():
                info.filename = info.filename.rstrip("/") + "/"
                archive.writestr(info, b"")
            else:
                with path.open("rb") as stream:
                    archive.writestr(info, stream.read(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def build(binary: Path, skill_source: Path, output_dir: Path, package_version: str) -> tuple[Path, Path]:
    binary = binary.expanduser().resolve()
    skill_source = skill_source.expanduser().resolve()
    output_dir = output_dir.expanduser().resolve()

    if not binary.is_file():
        raise FileNotFoundError(binary)
    if not (skill_source / "SKILL.md").is_file():
        raise FileNotFoundError(skill_source / "SKILL.md")

    core_version = detect_core_version(binary)
    package_name = f"{PACKAGE_BASENAME}-{package_version}"
    package_dir = output_dir / package_name
    zip_path = output_dir / f"{package_name}.zip"

    output_dir.mkdir(parents=True, exist_ok=True)
    if package_dir.exists():
        shutil.rmtree(package_dir)
    if zip_path.exists():
        zip_path.unlink()
    package_dir.mkdir(parents=True)

    copy_file(ROOT / "templates" / "README-先看这里.md", package_dir / "README_FIRST.md")
    copy_file(ROOT / "templates" / "INSTALL_FOR_AGENT.md", package_dir / "INSTALL_FOR_AGENT.md")
    copy_file(ROOT / "templates" / "install.command", package_dir / "install.command", executable=True)
    copy_file(ROOT / "installer" / "install.sh", package_dir / "installer" / "install.sh", executable=True)
    copy_file(ROOT / "installer" / "verify.sh", package_dir / "installer" / "verify.sh", executable=True)
    copy_file(binary, package_dir / "payload" / "bin" / "huntdog", executable=True)
    shutil.copytree(skill_source, package_dir / "payload" / "codex-skill" / "wechat-huntdog")

    core_sha = sha256_file(package_dir / "payload" / "bin" / "huntdog")
    manifest = {
        "product": "CyberUnion HuntDog",
        "package_version": package_version,
        "core_version": core_version,
        "platform": "macos-arm64",
        "core_sha256": core_sha,
        "install_mode": "agent-first-with-control-click-fallback",
        "auto_init": False,
    }
    (package_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (package_dir / "manifest.env").write_text(
        "\n".join(
            [
                f"HUNTDOG_PACKAGE_VERSION='{package_version}'",
                f"HUNTDOG_CORE_VERSION='{core_version}'",
                "HUNTDOG_PLATFORM='macos-arm64'",
                f"HUNTDOG_CORE_SHA256='{core_sha}'",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    checksums = []
    for relative in (
        Path("payload/bin/huntdog"),
        Path("install.command"),
        Path("installer/install.sh"),
        Path("installer/verify.sh"),
    ):
        checksums.append(f"{sha256_file(package_dir / relative)}  {relative}")
    (package_dir / "SHA256SUMS").write_text("\n".join(checksums) + "\n", encoding="utf-8")

    for executable in (
        package_dir / "install.command",
        package_dir / "installer" / "install.sh",
        package_dir / "installer" / "verify.sh",
        package_dir / "payload" / "bin" / "huntdog",
    ):
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    write_zip(package_dir, zip_path)
    (output_dir / f"{package_name}.sha256").write_text(
        f"{sha256_file(zip_path)}  {zip_path.name}\n",
        encoding="utf-8",
    )
    return package_dir, zip_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--skill-source", required=True, type=Path)
    parser.add_argument("--output-dir", default=ROOT / "dist", type=Path)
    parser.add_argument("--package-version", default="0.4.0-r2")
    args = parser.parse_args()

    package_dir, zip_path = build(
        binary=args.binary,
        skill_source=args.skill_source,
        output_dir=args.output_dir,
        package_version=args.package_version,
    )
    print(f"PACKAGE_DIR={package_dir}")
    print(f"PACKAGE_ZIP={zip_path}")
    print(f"PACKAGE_SHA256={sha256_file(zip_path)}")


if __name__ == "__main__":
    main()
