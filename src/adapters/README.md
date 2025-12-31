# PQC Adapters

This directory contains adapter implementations that connect the core PQC interfaces to external libraries.

## liboqs Adapter

The liboqs adapter (`liboqs_adapter.c` and `liboqs_adapter.h`) provides a concrete implementation of the `PQCProvider` interface using the Open Quantum Safe (liboqs) library.

### Features

- **Provider Interface Implementation**: Implements all required `PQCProvider` interface methods
- **Algorithm Support**: Supports all ML-KEM and ML-DSA variants:
  - ML-KEM: 512, 768, 1024
  - ML-DSA: 44, 65, 87
- **Complete Abstraction**: No direct liboqs calls in benchmark engine
- **Error Handling**: Comprehensive error handling with logging
- **Memory Management**: Proper allocation and cleanup of resources

### Usage

```c
#include "adapters/liboqs_adapter.h"

// Create provider
PQCProvider *provider = create_liboqs_provider();

// Initialize provider
void *context = NULL;
pqc_provider_initialize(provider, &context);

// Create algorithm
PQCAlgorithm *alg = NULL;
pqc_provider_get_algorithm(provider, context, "mlkem768", &alg);

// Use algorithm with benchmark engine
BenchmarkConfig config;
pqc_benchmark_config_init(&config);
BenchmarkResultSet *results = NULL;
pqc_benchmark_algorithm(alg, &config, &results);

// Cleanup
pqc_provider_release_algorithm(provider, context, alg);
pqc_provider_finalize(provider, context);
```

### Architecture

The adapter follows a layered architecture:

1. **Provider Layer**: Implements `PQCProvider` interface
2. **Algorithm Factory**: Creates `PQCAlgorithm` instances
3. **Operation Wrappers**: Wraps liboqs-specific calls
4. **Context Management**: Manages liboqs state

### Testing

The adapter is thoroughly tested with:

- **Unit Tests** (`test_liboqs_adapter.c`): 21 tests covering:
  - Provider creation and lifecycle
  - Algorithm creation for all variants
  - Error handling for unsupported algorithms
  - Algorithm validation
  - Support checking and listing

- **Property Tests** (`test_provider_abstraction_property.c`): 14 property tests verifying:
  - Provider abstraction completeness
  - All operations accessible through provider
  - Benchmark engine provider agnosticism
  - No direct liboqs dependencies

All tests pass successfully, confirming the adapter meets requirements 2.1, 2.2, 2.3, and 3.4.

### Implementation Details

#### Algorithm Name Mapping

The adapter maps user-friendly names to liboqs names:
- `mlkem512` → `ML-KEM-512`
- `mlkem768` → `ML-KEM-768`
- `mlkem1024` → `ML-KEM-1024`
- `mldsa44` → `ML-DSA-44`
- `mldsa65` → `ML-DSA-65`
- `mldsa87` → `ML-DSA-87`

#### Context Structure

Each algorithm instance maintains a context containing:
- `OQS_KEM*` for KEM algorithms
- `OQS_SIG*` for signature algorithms

This context is opaque to the benchmark engine, ensuring proper abstraction.

#### Error Handling

All operations return standard PQC error codes:
- `PQC_SUCCESS`: Operation succeeded
- `PQC_ERROR_NULL_POINTER`: NULL parameter
- `PQC_ERROR_INVALID_PARAM`: Invalid parameter
- `PQC_ERROR_ALGORITHM_NOT_FOUND`: Algorithm not supported
- `PQC_ERROR_OPERATION_FAILED`: Cryptographic operation failed

### Future Extensions

The adapter architecture allows for easy addition of:
- New PQC algorithms as they become available in liboqs
- Alternative PQC libraries (e.g., PQClean, Botan)
- Mock providers for testing
- Performance monitoring and statistics

### Requirements Validation

This implementation satisfies:

- **Requirement 2.1**: Provider interface defined with function pointers ✓
- **Requirement 2.2**: liboqs adapter created with `create_liboqs_provider()` ✓
- **Requirement 2.3**: Benchmark engine uses provider interface, not direct liboqs calls ✓
- **Requirement 3.4**: Adapter implementations placed in `src/adapters/` ✓

### Property Verification

**Property 2: Provider abstraction completeness** ✓

*For any* PQC algorithm operation in the benchmark engine, the operation is accessible through the PQCProvider interface without direct liboqs calls.

This property has been verified through comprehensive property-based testing with 14 test cases covering all supported algorithms and operations.
