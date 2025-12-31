#!/bin/bash
# ML-DSA Benchmark with Summary Output

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PROJECT_ROOT/build/bin"
RESULTS_DIR="$PROJECT_ROOT/results"
LIBOQS_DIR="$PROJECT_ROOT/build/liboqs/build-native"

mkdir -p "$RESULTS_DIR"
export LD_LIBRARY_PATH="$LIBOQS_DIR/lib:$LD_LIBRARY_PATH"

# Clean previous temporary files
rm -f /tmp/mldsa_output.txt

echo ""
echo "======================================================================"
echo "Running ML-DSA Benchmark"
echo "======================================================================"
echo ""

"$BIN_DIR/benchmark_mldsa" -i 1000 -w 100 -r \
    -j "$RESULTS_DIR/mldsa_results.json" \
    -c "$RESULTS_DIR/mldsa_results.csv" > /tmp/mldsa_output.txt 2>&1

# Verify that benchmark executed correctly
if [ $? -ne 0 ]; then
    echo "ERROR: Benchmark execution failed. See details:"
    cat /tmp/mldsa_output.txt
    rm -f /tmp/mldsa_output.txt
    exit 1
fi

echo "ML-DSA Results:"
echo "+------------+--------------+--------------+--------------+"
echo "| Algorithm  | KeyGen (µs)  | Sign (µs)    | Verify (µs)  |"
echo "+------------+--------------+--------------+--------------+"
awk '
/Starting benchmark: mldsa44/ { alg="ML-DSA-44 "; kg=""; sign=""; ver="" }
/Starting benchmark: mldsa65/ { alg="ML-DSA-65 "; kg=""; sign=""; ver="" }
/Starting benchmark: mldsa87/ { alg="ML-DSA-87 "; kg=""; sign=""; ver="" }
/Operation: keygen/ { in_keygen=1; in_sign=0; in_verify=0; next }
/Operation: sign/ { in_keygen=0; in_sign=1; in_verify=0; next }
/Operation: verify/ { in_keygen=0; in_sign=0; in_verify=1; next }
/^  Mean:/ && /µs/ {
    gsub(/^  Mean:[ \t]+/, "")
    gsub(/ µs.*/, "")
    if (in_keygen) kg=$0
    else if (in_sign) sign=$0
    else if (in_verify) {
        ver=$0
        printf "| %-10s | %12s | %12s | %12s |\n", alg, kg, sign, ver
    }
}
' /tmp/mldsa_output.txt
echo "+------------+--------------+--------------+--------------+"
echo ""
echo "Detailed results saved to:"
echo "  $RESULTS_DIR/mldsa_results.json"
echo "  $RESULTS_DIR/mldsa_results.csv"
echo ""

rm -f /tmp/mldsa_output.txt
