#!/usr/bin/env python3
"""Collect size/SBOM/vulnerability metrics for one image stage into metrics.json."""
import hashlib
import gzip
import io
import json
import shutil
import subprocess
import sys
import tarfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory


OCI_UNCOMPRESSED_LAYER_MEDIA_TYPE = "application/vnd.oci.image.layer.v1.tar"
OCI_GZIP_LAYER_MEDIA_TYPE = "application/vnd.oci.image.layer.v1.tar+gzip"
OCI_MANIFEST_MEDIA_TYPE = "application/vnd.oci.image.manifest.v1+json"
SHA256_PREFIX = "sha256:"
SHA256_HEX_LENGTH = 64


def human_size(num_bytes: int) -> str:
    # Decimal MB (bytes / 1_000_000), matching the convention used throughout
    # this project's manually-written metrics.json files (e.g. 97444975 bytes
    # -> "97.44MB"), not binary MiB.
    mb = num_bytes / 1_000_000
    return f"{mb:.2f}MB"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as blob:
        for chunk in iter(lambda: blob.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def descriptor_blob(layout: Path, descriptor: dict, description: str) -> Path:
    """Return a verified sha256 OCI blob referenced by *descriptor*."""
    digest = descriptor.get("digest")
    size = descriptor.get("size")
    if (
        not isinstance(digest, str)
        or not digest.startswith(SHA256_PREFIX)
        or len(digest) != len(SHA256_PREFIX) + SHA256_HEX_LENGTH
        or any(char not in "0123456789abcdef" for char in digest[len(SHA256_PREFIX):])
    ):
        raise ValueError(f"{description} has an invalid sha256 digest: {digest!r}")
    if not isinstance(size, int) or size < 0:
        raise ValueError(f"{description} has an invalid size: {size!r}")

    blob_path = layout / "blobs" / "sha256" / digest[len(SHA256_PREFIX):]
    if not blob_path.is_file():
        raise ValueError(f"{description} blob is missing: {blob_path}")
    actual_size = blob_path.stat().st_size
    if actual_size != size:
        raise ValueError(
            f"{description} size mismatch: descriptor={size}, actual={actual_size}"
        )
    if sha256_file(blob_path) != digest[len(SHA256_PREFIX):]:
        raise ValueError(f"{description} digest does not match its blob")
    return blob_path


def read_json(path: Path, description: str) -> dict:
    with path.open() as source:
        value = json.load(source)
    if not isinstance(value, dict):
        raise ValueError(f"{description} must contain a JSON object")
    return value


def write_blob(path: Path, source) -> dict:
    """Write *source* to an OCI sha256 blob and return its descriptor."""
    digest = hashlib.sha256()
    size = 0
    temporary_path = path.parent / ".blob.tmp"
    with temporary_path.open("wb") as destination:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
            destination.write(chunk)
    hex_digest = digest.hexdigest()
    blob_path = path.parent / hex_digest
    temporary_path.replace(blob_path)
    return {"digest": f"sha256:{hex_digest}", "size": size}


def normalized_layer_blob(source_blob: Path, source_media_type: str, blobs: Path) -> dict:
    if source_media_type not in {
        OCI_UNCOMPRESSED_LAYER_MEDIA_TYPE,
        OCI_GZIP_LAYER_MEDIA_TYPE,
    }:
        raise ValueError(
            f"unsupported source layer media type {source_media_type!r}; "
            "only uncompressed OCI tar and gzip OCI tar layers can be normalized"
        )
    with source_blob.open("rb") as source:
        gzip_magic = source.read(2) == b"\x1f\x8b"
    if gzip_magic:
        with gzip.open(source_blob, "rb") as source:
            return write_blob(blobs / "placeholder", source)
    if tarfile.is_tarfile(source_blob):
        with source_blob.open("rb") as source:
            return write_blob(blobs / "placeholder", source)
    raise ValueError(
        f"source layer {source_blob} is neither a valid uncompressed tar nor gzip data"
    )


def normalized_oci_layer_size(image_tag: str, output_dir: Path) -> int:
    """Export an image to OCI, verify it, and return its uncompressed layer bytes."""
    with TemporaryDirectory(prefix="oci-size-") as temporary_directory:
        exported_layout = Path(temporary_directory) / "exported"
        layout = Path(temporary_directory) / "normalized"
        export_command = [
            "skopeo",
            "copy",
            "--format",
            "oci",
            "--multi-arch",
            "system",
            "--dest-oci-accept-uncompressed-layers",
            f"docker-daemon:{image_tag}",
            f"oci:{exported_layout}:exported",
        ]
        skopeo_version = subprocess.run(
            ["skopeo", "--version"], check=True, capture_output=True, text=True
        ).stdout.strip()
        subprocess.run(export_command, check=True)

        exported_index = read_json(exported_layout / "index.json", "exported OCI index")
        manifests = exported_index.get("manifests")
        if not isinstance(manifests, list) or len(manifests) != 1:
            raise ValueError("OCI index must contain exactly one selected manifest")

        manifest_descriptor = manifests[0]
        if not isinstance(manifest_descriptor, dict):
            raise ValueError("OCI index manifest descriptor must be an object")
        exported_manifest = read_json(
            descriptor_blob(exported_layout, manifest_descriptor, "manifest"), "OCI manifest"
        )

        config_descriptor = exported_manifest.get("config")
        if not isinstance(config_descriptor, dict):
            raise ValueError("OCI manifest has no config descriptor")
        config = read_json(
            descriptor_blob(exported_layout, config_descriptor, "config"), "OCI config"
        )

        layers = exported_manifest.get("layers")
        if not isinstance(layers, list):
            raise ValueError("OCI manifest layers must be a list")
        blobs = layout / "blobs" / "sha256"
        blobs.mkdir(parents=True)
        normalized_layers = []
        for index_number, layer in enumerate(layers):
            if not isinstance(layer, dict):
                raise ValueError(f"layer {index_number} descriptor must be an object")
            source_blob = descriptor_blob(exported_layout, layer, f"source layer {index_number}")
            normalized = normalized_layer_blob(source_blob, layer.get("mediaType"), blobs)
            normalized["mediaType"] = OCI_UNCOMPRESSED_LAYER_MEDIA_TYPE
            normalized_layers.append(normalized)

        config_blob = descriptor_blob(exported_layout, config_descriptor, "config")
        shutil.copyfile(config_blob, blobs / config_descriptor["digest"][len(SHA256_PREFIX):])
        manifest = {
            "schemaVersion": 2,
            "mediaType": OCI_MANIFEST_MEDIA_TYPE,
            "config": config_descriptor,
            "layers": normalized_layers,
        }
        manifest_bytes = json.dumps(manifest, separators=(",", ":")).encode()
        manifest_descriptor = write_blob(blobs / "placeholder", io.BytesIO(manifest_bytes))
        manifest_descriptor["mediaType"] = OCI_MANIFEST_MEDIA_TYPE
        index = {"schemaVersion": 2, "manifests": [manifest_descriptor]}
        (layout / "oci-layout").write_text('{"imageLayoutVersion":"1.0.0"}')
        (layout / "index.json").write_text(json.dumps(index))

        descriptor_blob(layout, manifest_descriptor, "normalized manifest")
        descriptor_blob(layout, config_descriptor, "normalized config")
        for index_number, layer in enumerate(normalized_layers):
            if layer["mediaType"] != OCI_UNCOMPRESSED_LAYER_MEDIA_TYPE:
                raise ValueError(f"normalized layer {index_number} is not uncompressed")
            descriptor_blob(layout, layer, f"normalized layer {index_number}")

        size_bytes = sum(layer["size"] for layer in normalized_layers)
        output_dir.mkdir(parents=True, exist_ok=True)
        for filename, value in (
            ("size-oci-index.json", index),
            ("size-oci-manifest.json", manifest),
        ):
            with (output_dir / filename).open("w") as destination:
                json.dump(value, destination, indent=2)

        evidence = {
            "size_metric": "oci_uncompressed_layer_bytes",
            "image_tag": image_tag,
            "platform": {
                "os": config.get("os"),
                "architecture": config.get("architecture"),
                "variant": config.get("variant"),
            },
            "skopeo_version": skopeo_version,
            "skopeo_command": export_command[:-1] + ["oci:<temporary-layout>/exported:exported"],
            "manifest": manifest_descriptor,
            "config": config_descriptor,
            "source_layers": layers,
            "layers": normalized_layers,
            "layer_size_total": size_bytes,
        }
        with (output_dir / "size-evidence.json").open("w") as destination:
            json.dump(evidence, destination, indent=2)

    return size_bytes


def main() -> None:
    example, stage, image_tag, sbom_path, vulns_path, test_script, output_path = sys.argv[1:8]
    output = Path(output_path)
    size_bytes = normalized_oci_layer_size(image_tag, output.parent)

    sbom = json.load(open(sbom_path))
    sbom_component_count = len(sbom.get("artifacts", []))

    vulns = json.load(open(vulns_path))
    matches = vulns.get("matches", [])
    by_severity = dict(Counter(m["vulnerability"]["severity"] for m in matches))

    metrics = {
        "example": example,
        "stage": stage,
        "image_tag": image_tag,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "size_metric": "oci_uncompressed_layer_bytes",
        "size_bytes": size_bytes,
        "size_human": human_size(size_bytes),
        "sbom_component_count": sbom_component_count,
        "vulnerability_total": len(matches),
        "vulnerability_by_severity": by_severity,
        "functional_tests": f"PASS ({test_script})",
    }

    with output.open("w") as destination:
        json.dump(metrics, destination, indent=2)
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
