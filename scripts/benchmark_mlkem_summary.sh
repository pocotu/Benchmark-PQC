#!/bin/bash
# ML-KEM Benchmark with Summary Output

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PROJECT_ROOT/build/bin"
RESULTS_DIR="$PROJECT_ROOT/results"
LIBOQS_DIR="$PROJECT_ROOT/build/liboqs/build-native"

mkdir -p "$RESULTS_DIR"
export LD_LIBRARY_PATH="$LIBOQS_DIR/lib:$LD_LIBRARY_PATH"

# Clean previous temporary files
rm -f /tmp/mlkem_output.txt

echo ""
echo "======================================================================"
echo "Running ML-KEM Benchmark"
echo "======================================================================"
echo ""

"$BIN_DIR/benchmark_mlkem" -i 1000 -w 100 -r \
    -j "$RESULTS_DIR/mlkem_results.json" \
    -c "$RESULTS_DIR/mlkem_results.csv" > /tmp/mlkem_output.txt 2>&1

# Verify that benchmark executed correctly
if [ $? -ne 0 ]; then
    echo "ERROR: Benchmark execution failed. See details:"
    cat /tmp/mlkem_output.txt
    rm -f /tmp/mlkem_output.txt
    exit 1
fi

echo "ML-KEM Results:"
echo "+-------------+--------------+--------------+--------------+"
echo "| Algorithm   | KeyGen (µs)  | Encaps (µs)  | Decaps (µs)  |"
echo "+-------------+--------------+--------------+--------------+"
awk '
/Starting benchmark: mlkem512/ { alg="ML-KEM-512 "; kg=""; enc=""; dec="" }
/Starting benchmark: mlkem768/ { alg="ML-KEM-768 "; kg=""; enc=""; dec="" }
/Starting benchmark: mlkem1024/ { alg="ML-KEM-1024"; kg=""; enc=""; dec="" }
/Operation: keygen/ { in_keygen=1; in_encaps=0; in_decaps=0; next }
/Operation: encaps/ { in_keygen=0; in_encaps=1; in_decaps=0; next }
/Operation: decaps/ { in_keygen=0; in_encaps=0; in_decaps=1; next }
/^  Mean:/ && /µs/ {
    gsub(/^  Mean:[ \t]+/, "")
    gsub(/ µs.*/, "")
    if (in_keygen) kg=$0
    else if (in_encaps) enc=$0
    else if (in_decaps) {
        dec=$0
        printf "| %-11s | %12s | %12s | %12s |\n", alg, kg, enc, dec
    }
}
' /tmp/mlkem_output.txt
echo "+-------------+--------------+--------------+--------------+"
echo ""
echo "Detailed results saved to:"
echo "  $RESULTS_DIR/mlkem_results.json"
echo "  $RESULTS_DIR/mlkem_results.csv"
echo ""

rm -f /tmp/mlkem_output.txt
