# Core Interfaces

This directory contains the core interface definitions for the PQC benchmark system. These interfaces are designed to be independent of any external libraries (including liboqs) and provide a clean abstraction layer.

## Files

### error_codes.h
Standard error codes used throughout the system. All functions return `int` status codes where `0` indicates success and negative values indicate errors.

**Key Features:**
- Standard error codes (invalid param, memory allocation, I/O, etc.)
- Helper functions for error string conversion
- No external dependencies

### algorithm_interface.h
Generic interface for PQC algorithms (both KEM and signature schemes).

**Key Features:**
- `PQCAlgorithm` structure with function pointers for operations
- Support for both KEM (keygen, encaps, decaps) and Signature (keygen, sign, verify)
- Algorithm metadata (sizes, type, name)
- Type-safe with enums and validation functions
- No external dependencies

### benchmark_engine.h
Generic benchmark engine that can measure any algorithm conforming to the `PQCAlgorithm` interface.

**Key Features:**
- `BenchmarkConfig` for configuring benchmark execution
- `BenchmarkResult` for storing timing samples and statistics
- Support for JSON and CSV output formats
- Integration with existing timing and statistics utilities
- No external dependencies (except standard C library)

### provider_interface.h
Provider abstraction for PQC algorithm implementations (e.g., liboqs).

**Key Features:**
- `PQCProvider` structure for algorithm providers
- Factory pattern for creating algorithm instances
- Query functions for listing and checking algorithm support
- Optional provider registry for global lookup
- No external dependencies

## Design Principles

1. **Dependency Inversion**: Core interfaces depend only on abstractions, not concrete implementations
2. **Single Responsibility**: Each interface has a clear, focused purpose
3. **Open/Closed**: Interfaces are open for extension (new algorithms, providers) but closed for modification
4. **No External Dependencies**: All headers compile with only standard C library headers
5. **Type Safety**: Use of enums, structs, and validation functions to catch errors at compile time
