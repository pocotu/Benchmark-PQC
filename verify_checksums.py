#!/usr/bin/env python3
"""Verify data integrity using checksums."""

import hashlib
import json
import sys
from pathlib import Path


def calculate_sha256(file_path):
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(65536), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def verify_checksums(manifest_file, data_dir):
    with open(manifest_file) as f:
        manifest = json.load(f)
    
    # Support both formats: {"checksums": {...}} and {"files": {...}}
    if "checksums" in manifest:
        checksums = manifest["checksums"]
    elif "files" in manifest:
        # Convert simple format to expected format
        checksums = {path: {"sha256": checksum} for path, checksum in manifest["files"].items()}
    else:
        print("Error: Invalid manifest format")
        sys.exit(1)
    
    total = len(checksums)
    verified = 0
    failed = []
    
    print(f"Verifying {total} files...")
    
    for rel_path, info in checksums.items():
        file_path = data_dir / rel_path
        
        if not file_path.exists():
            print(f"✗ Missing: {rel_path}")
            failed.append((rel_path, "missing"))
            continue
        
        actual_checksum = calculate_sha256(file_path)
        # Handle both dict and string formats
        expected_checksum = info["sha256"] if isinstance(info, dict) else info
        
        if actual_checksum == expected_checksum:
            verified += 1
            print(f"✓ {rel_path}")
        else:
            print(f"✗ Checksum mismatch: {rel_path}")
            failed.append((rel_path, "mismatch"))
    
    print(f"\nResults: {verified}/{total} verified")
    
    if failed:
        print(f"\nFailed files ({len(failed)}):")
        for path, reason in failed:
            print(f"  - {path}: {reason}")
        sys.exit(1)
    else:
        print("\n✓ All files verified successfully!")
        sys.exit(0)


if __name__ == "__main__":
    manifest_file = Path("CHECKSUMS.json")
    data_dir = Path("results")
    
    if not manifest_file.exists():
        print(f"Error: {manifest_file} not found")
        sys.exit(1)
    
    verify_checksums(manifest_file, data_dir)
