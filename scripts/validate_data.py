#!/usr/bin/env python3
"""
Data Validation Script

Validates JSON/CSV data files from benchmark experiments.
Checks data format, required fields, value ranges, and statistical consistency.

Author: Benchmarks-PQC Project
Date: November 2025
"""

import json
import csv
import sys
import os
import argparse
import hashlib
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from abc import ABC, abstractmethod
from datetime import datetime


# ============================================================================
# Data Classes
# ============================================================================

@dataclass
class ValidationResult:
    """Results from validation check"""
    valid: bool
    errors: List[str]
    warnings: List[str]
    file_path: str
    checksum: Optional[str] = None


# ============================================================================
# Abstract Validator (Dependency Inversion Principle)
# ============================================================================

class DataValidator(ABC):
    """Abstract base class for data validators"""
    
    @abstractmethod
    def validate(self, file_path: str) -> ValidationResult:
        """Validate a data file"""
        pass
    
    @abstractmethod
    def get_checksum(self, file_path: str) -> str:
        """Calculate file checksum"""
        pass


# ============================================================================
# JSON Validator (Interface Segregation Principle)
# ============================================================================

class JSONValidator(DataValidator):
    """Validator for JSON benchmark data files"""
    
    def __init__(self, required_fields: Optional[List[str]] = None):
        # Accept both old format (iterations, operations) and new format (results)
        self.required_fields = required_fields or ['algorithm']
    
    def validate(self, file_path: str) -> ValidationResult:
        """Validate JSON file structure and content"""
        errors = []
        warnings = []
        
        # Check file exists
        if not Path(file_path).exists():
            errors.append(f"File not found: {file_path}")
            return ValidationResult(False, errors, warnings, file_path)
        
        # Check file is not empty
        if Path(file_path).stat().st_size == 0:
            errors.append(f"File is empty: {file_path}")
            return ValidationResult(False, errors, warnings, file_path)
        
        # Try to parse JSON
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
        except json.JSONDecodeError as e:
            errors.append(f"Invalid JSON: {e}")
            return ValidationResult(False, errors, warnings, file_path)
        
        # Validate structure
        if not isinstance(data, dict):
            errors.append("Root element must be a JSON object")
            return ValidationResult(False, errors, warnings, file_path)
        
        # Check required fields
        for field in self.required_fields:
            if field not in data:
                errors.append(f"Missing required field: {field}")
        
        # Validate new format with 'results' array
        if 'results' in data and isinstance(data['results'], list):
            for idx, result in enumerate(data['results']):
                if not isinstance(result, dict):
                    errors.append(f"Result {idx} must be an object")
                    continue
                
                # Check for operation field
                if 'operation' not in result:
                    warnings.append(f"Result {idx} missing 'operation' field")
                
                # Check for statistical fields
                stat_fields = ['mean_us', 'median_us', 'stddev_us', 'min_us', 'max_us']
                missing_stats = [f for f in stat_fields if f not in result]
                if missing_stats:
                    warnings.append(f"Result {idx} missing stats: {missing_stats}")
                
                # Validate numeric values
                for stat_field in stat_fields:
                    if stat_field in result:
                        value = result[stat_field]
                        if not isinstance(value, (int, float)) or value < 0:
                            errors.append(f"Invalid {stat_field} in result {idx}: {value}")
                
                # Check num_samples
                if 'num_samples' in result:
                    if not isinstance(result['num_samples'], int) or result['num_samples'] < 100:
                        warnings.append(f"Low sample count in result {idx}: {result.get('num_samples')}")
        
        # Validate old format with 'operations' dict (backward compatibility)
        elif 'operations' in data and isinstance(data['operations'], dict):
            for op_name, op_data in data['operations'].items():
                if not isinstance(op_data, dict):
                    errors.append(f"Operation '{op_name}' must be an object")
                    continue
                
                stat_fields = ['min', 'max', 'mean', 'median', 'stddev']
                missing_stats = [f for f in stat_fields if f not in op_data]
                if missing_stats:
                    warnings.append(f"Operation '{op_name}' missing stats: {missing_stats}")
        
        # Calculate checksum
        checksum = self.get_checksum(file_path)
        
        is_valid = len(errors) == 0
        return ValidationResult(is_valid, errors, warnings, file_path, checksum)
    
    def get_checksum(self, file_path: str) -> str:
        """Calculate SHA256 checksum of file"""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                sha256.update(chunk)
        return sha256.hexdigest()


# ============================================================================
# CSV Validator (Interface Segregation Principle)
# ============================================================================

class CSVValidator(DataValidator):
    """Validator for CSV benchmark data files"""
    
    def __init__(self, expected_columns: Optional[List[str]] = None):
        self.expected_columns = expected_columns or [
            'algorithm',
            'operation',
            'iterations',
            'mean',
            'median'
        ]
    
    def validate(self, file_path: str) -> ValidationResult:
        """Validate CSV file structure and content"""
        errors = []
        warnings = []
        
        # Check file exists
        if not Path(file_path).exists():
            errors.append(f"File not found: {file_path}")
            return ValidationResult(False, errors, warnings, file_path)
        
        # Check file is not empty
        if Path(file_path).stat().st_size == 0:
            errors.append(f"File is empty: {file_path}")
            return ValidationResult(False, errors, warnings, file_path)
        
        # Try to parse CSV
        try:
            with open(file_path, 'r') as f:
                reader = csv.DictReader(f)
                headers = reader.fieldnames
                
                if headers is None:
                    errors.append("CSV file has no headers")
                    return ValidationResult(False, errors, warnings, file_path)
                
                # Check for expected columns (partial match OK)
                missing_cols = [col for col in self.expected_columns 
                               if col not in headers]
                if missing_cols:
                    warnings.append(f"Missing expected columns: {missing_cols}")
                
                # Validate rows
                row_count = 0
                for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is 1)
                    row_count += 1
                    
                    # Check for empty values in critical columns
                    for col in ['algorithm', 'operation']:
                        if col in row and not row[col].strip():
                            errors.append(f"Row {row_num}: Empty value in column '{col}'")
                    
                    # Validate numeric columns
                    numeric_cols = ['iterations', 'mean', 'median', 'min', 'max', 'stddev']
                    for col in numeric_cols:
                        if col in row and row[col].strip():
                            try:
                                value = float(row[col])
                                if value < 0:
                                    errors.append(f"Row {row_num}: Negative value in '{col}': {value}")
                            except ValueError:
                                errors.append(f"Row {row_num}: Invalid numeric value in '{col}': {row[col]}")
                
                if row_count == 0:
                    warnings.append("CSV file has no data rows")
        
        except Exception as e:
            errors.append(f"Error parsing CSV: {e}")
            return ValidationResult(False, errors, warnings, file_path)
        
        # Calculate checksum
        checksum = self.get_checksum(file_path)
        
        is_valid = len(errors) == 0
        return ValidationResult(is_valid, errors, warnings, file_path, checksum)
    
    def get_checksum(self, file_path: str) -> str:
        """Calculate SHA256 checksum of file"""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                sha256.update(chunk)
        return sha256.hexdigest()


# ============================================================================
# Validator Factory (Open/Closed Principle)
# ============================================================================

class ValidatorFactory:
    """Factory to create appropriate validator based on file type"""
    
    @staticmethod
    def create_validator(file_path: str) -> Optional[DataValidator]:
        """Create validator based on file extension"""
        extension = Path(file_path).suffix.lower()
        
        if extension == '.json':
            return JSONValidator()
        elif extension == '.csv':
            return CSVValidator()
        else:
            return None


# ============================================================================
# Batch Validation
# ============================================================================

def validate_directory(directory: str, recursive: bool = True) -> List[ValidationResult]:
    """Validate all data files in a directory"""
    results = []
    dir_path = Path(directory)
    
    if not dir_path.exists():
        print(f"Error: Directory not found: {directory}", file=sys.stderr)
        return results
    
    # Find all JSON and CSV files
    patterns = ['*.json', '*.csv']
    files = []
    
    for pattern in patterns:
        if recursive:
            files.extend(dir_path.rglob(pattern))
        else:
            files.extend(dir_path.glob(pattern))
    
    # Validate each file
    for file_path in sorted(files):
        validator = ValidatorFactory.create_validator(str(file_path))
        if validator:
            result = validator.validate(str(file_path))
            results.append(result)
    
    return results


def print_validation_summary(results: List[ValidationResult]) -> bool:
    """Print validation summary and return overall status"""
    total = len(results)
    valid = sum(1 for r in results if r.valid)
    invalid = total - valid
    
    print(f"\n{'='*70}")
    print(f"Validation Summary")
    print(f"{'='*70}")
    print(f"Total files validated: {total}")
    print(f"Valid: {valid}")
    print(f"Invalid: {invalid}")
    print(f"{'='*70}\n")
    
    # Print details for invalid files
    if invalid > 0:
        print("Invalid Files:")
        print("-" * 70)
        for result in results:
            if not result.valid:
                print(f"\nERROR: {result.file_path}")
                for error in result.errors:
                    print(f"   ERROR: {error}")
                for warning in result.warnings:
                    print(f"   WARNING: {warning}")
        print()
    
    # Print warnings for valid files
    valid_with_warnings = [r for r in results if r.valid and r.warnings]
    if valid_with_warnings:
        print("Valid Files with Warnings:")
        print("-" * 70)
        for result in valid_with_warnings:
            print(f"\n⚠️  {result.file_path}")
            for warning in result.warnings:
                print(f"   WARNING: {warning}")
        print()
    
    # Print checksums if requested
    print("Checksums:")
    print("-" * 70)
    for result in results:
        status = "VALID" if result.valid else "INVALID"
        checksum = result.checksum or "N/A"
        print(f"{status} {Path(result.file_path).name}: {checksum[:16]}...")
    print()
    
    return invalid == 0


# ============================================================================
# Main Entry Point
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Validate benchmark data files (JSON/CSV)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s data/raw/native/mlkem/mlkem512_20251110_120000.json
  %(prog)s data/raw/native --recursive
  %(prog)s data/ -r --quiet
        """
    )
    
    parser.add_argument(
        'path',
        help='File or directory to validate'
    )
    
    parser.add_argument(
        '-r', '--recursive',
        action='store_true',
        help='Recursively validate all files in directory'
    )
    
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Only show summary, not individual file details'
    )
    
    parser.add_argument(
        '--checksums',
        action='store_true',
        help='Generate checksum file for validated data'
    )
    
    args = parser.parse_args()
    
    # Validate path
    path = Path(args.path)
    
    if path.is_file():
        # Validate single file
        validator = ValidatorFactory.create_validator(str(path))
        if validator is None:
            print(f"Error: Unsupported file type: {path.suffix}", file=sys.stderr)
            return 1
        
        result = validator.validate(str(path))
        results = [result]
    
    elif path.is_dir():
        # Validate directory
        results = validate_directory(str(path), args.recursive)
    
    else:
        print(f"Error: Path not found: {path}", file=sys.stderr)
        return 1
    
    # Print results
    if not args.quiet:
        for result in results:
            status = "VALID" if result.valid else "INVALID"
            print(f"\n{status}: {result.file_path}")
            
            if result.errors:
                print("  Errors:")
                for error in result.errors:
                    print(f"    - {error}")
            
            if result.warnings:
                print("  Warnings:")
                for warning in result.warnings:
                    print(f"    - {warning}")
    
    # Print summary
    all_valid = print_validation_summary(results)
    
    # Generate checksums file if requested
    if args.checksums and results:
        checksums_file = Path(args.path).parent / "checksums.txt"
        with open(checksums_file, 'w') as f:
            f.write(f"# Checksums generated on {datetime.now().isoformat()}\n")
            f.write(f"# Total files: {len(results)}\n\n")
            for result in results:
                if result.checksum:
                    f.write(f"{result.checksum}  {result.file_path}\n")
        print(f"Checksums written to: {checksums_file}")
    
    return 0 if all_valid else 1


if __name__ == '__main__':
    sys.exit(main())
