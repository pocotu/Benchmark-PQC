#!/usr/bin/env python3
"""
Generate SHA-256 checksums for all data files.

Creates a manifest file with checksums for verification.
"""

import hashlib
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List


def calculate_sha256(file_path: Path) -> str:
    """Calculate SHA-256 checksum of a file."""
    sha256_hash = hashlib.sha256()
    
    with open(file_path, "rb") as f:
        # Read in 64kb chunks
        for byte_block in iter(lambda: f.read(65536), b""):
            sha256_hash.update(byte_block)
    
    return sha256_hash.hexdigest()


def generate_checksums(data_dir: Path) -> Dict:
    """Generate checksums for all data files."""
    checksums = {}
    file_count = 0
    
    # Patterns to include
    patterns = ["*.json", "*.csv", "*.png", "*.svg"]
    
    # Directories to exclude (temporary/cache files)
    exclude_dirs = {"htmlcov", "quality", "__pycache__", ".pytest_cache"}
    
    for pattern in patterns:
        for file_path in data_dir.rglob(pattern):
            # Skip if in excluded directory
            if any(excluded in file_path.parts for excluded in exclude_dirs):
                continue
                
            if file_path.is_file():
                relative_path = file_path.relative_to(data_dir)
                checksum = calculate_sha256(file_path)
                
                checksums[str(relative_path)] = {
                    "sha256": checksum,
                    "size": file_path.stat().st_size,
                    "modified": datetime.fromtimestamp(
                        file_path.stat().st_mtime
                    ).isoformat()
                }
                
                file_count += 1
                print(f"✓ {relative_path}: {checksum[:16]}...")
    
    return {
        "generated": datetime.now().isoformat(),
        "total_files": file_count,
        "checksums": checksums
    }


def save_manifest(manifest: Dict, output_file: Path):
    """Save checksum manifest to file."""
    with open(output_file, 'w') as f:
        json.dump(manifest, f, indent=2)
    
    print(f"\n✓ Manifest saved to: {output_file}")


def generate_verification_script(manifest_file: Path):
    """Generate verification script."""
    script_content = """#!/usr/bin/env python3
\"\"\"Verify data integrity using checksums.\"\"\"

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
    
    checksums = manifest["checksums"]
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
        expected_checksum = info["sha256"]
        
        if actual_checksum == expected_checksum:
            verified += 1
            print(f"✓ {rel_path}")
        else:
            print(f"✗ Checksum mismatch: {rel_path}")
            failed.append((rel_path, "mismatch"))
    
    print(f"\\nResults: {verified}/{total} verified")
    
    if failed:
        print(f"\\nFailed files ({len(failed)}):")
        for path, reason in failed:
            print(f"  - {path}: {reason}")
        sys.exit(1)
    else:
        print("\\n✓ All files verified successfully!")
        sys.exit(0)


if __name__ == "__main__":
    manifest_file = Path("CHECKSUMS.json")
    data_dir = Path("results")
    
    if not manifest_file.exists():
        print(f"Error: {manifest_file} not found")
        sys.exit(1)
    
    verify_checksums(manifest_file, data_dir)
"""
    
    script_file = manifest_file.parent / "verify_checksums.py"
    with open(script_file, 'w') as f:
        f.write(script_content)
    
    script_file.chmod(0o755)
    print(f"✓ Verification script saved to: {script_file}")


def main():
    """Main entry point."""
    import sys
    
    data_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("results")
    
    if not data_dir.exists():
        print(f"Error: {data_dir} does not exist")
        sys.exit(1)
    
    print("=" * 60)
    print("CHECKSUM GENERATOR")
    print("=" * 60)
    print(f"\nScanning: {data_dir}")
    print()
    
    # Generate checksums
    manifest = generate_checksums(data_dir)
    
    # Save manifest
    manifest_file = Path("CHECKSUMS.json")
    save_manifest(manifest, manifest_file)
    
    # Generate verification script
    generate_verification_script(manifest_file)
    
    print("\n" + "=" * 60)
    print("✓ CHECKSUM GENERATION COMPLETE")
    print("=" * 60)
    print(f"\nGenerated checksums for {manifest['total_files']} files")
    print(f"Manifest: {manifest_file}")
    print(f"Verify with: python3 verify_checksums.py")


if __name__ == "__main__":
    main()
