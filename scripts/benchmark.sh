#!/usr/bin/env bash
# run_bench.sh - Sweep thread counts with llama-bench and save results.
# Works unchanged on bare metal or VMs: the thread list is derived from the
# instance's own core count.
#
# Usage:  bash run_bench.sh
# Tunables (env vars):
#   REPS=3           repetitions per configuration
#   N_PROMPT=512     prompt-processing tokens (compute-bound phase)
#   N_GEN=128        generated tokens (memory-bandwidth-bound phase)
#   THREADS="1,2,4"  override the automatic thread list
set -euo pipefail

source "${WORKDIR:-$HOME/llm-bench}/env.sh"

REPS="${REPS:-3}"
N_PROMPT="${N_PROMPT:-512}"
N_GEN="${N_GEN:-128}"

LOGICAL=$(nproc)
PHYSICAL=$(lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l)

# Default sweep: powers of two up to the logical CPU count, plus the
# physical-core count and the logical count (shows the effect of SMT).
if [[ -z "${THREADS:-}" ]]; then
  list=()
  t=1
  while (( t < LOGICAL )); do list+=("$t"); t=$(( t * 2 )); done
  list+=("$PHYSICAL" "$LOGICAL")
  THREADS=$(printf '%s\n' "${list[@]}" | sort -n -u | paste -sd, -)
fi

STAMP=$(date -u +%Y%m%dT%H%M%SZ)
OUT="${WORKDIR}/results/$(hostname -s)-${STAMP}"
mkdir -p "${OUT}"

# --- Metadata: lets the analysis notebook interpret each result set --------
VIRT=$(systemd-detect-virt 2>/dev/null || true)   # "none" on bare metal, e.g. "kvm" in a VM
lscpu > "${OUT}/lscpu.txt"
cat > "${OUT}/meta.json" << META
{
  "hostname": "$(hostname -s)",
  "timestamp_utc": "${STAMP}",
  "virtualization": "${VIRT:-none}",
  "logical_cpus": ${LOGICAL},
  "physical_cores": ${PHYSICAL},
  "mem_total_kb": $(awk '/MemTotal/ {print $2}' /proc/meminfo),
  "kernel": "$(uname -r)",
  "llama_cpp_tag": "${REPO_REF}",
  "model": "$(basename "${MODEL_PATH}")",
  "threads": "${THREADS}",
  "n_prompt": ${N_PROMPT},
  "n_gen": ${N_GEN},
  "reps": ${REPS}
}
META

echo "Environment : ${VIRT:-none} | ${LOGICAL} logical CPUs, ${PHYSICAL} physical cores"
echo "Thread sweep: ${THREADS}"
echo "Output      : ${OUT}"
echo

# --- Run --------------------------------------------------------------------
"${LLAMA_BIN}/llama-bench" \
  -m "${MODEL_PATH}" \
  -t "${THREADS}" \
  -p "${N_PROMPT}" \
  -n "${N_GEN}" \
  -r "${REPS}" \
  -o csv > "${OUT}/bench.csv"

# --- Quick summary ------------------------------------------------------------
python3 - "${OUT}/bench.csv" << 'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1])))
print(f"{'threads':>8} {'test':>8} {'tokens/s':>10} {'stddev':>8}")
for r in rows:
    test = f"pp{r['n_prompt']}" if int(r["n_gen"]) == 0 else f"tg{r['n_gen']}"
    print(f"{r['n_threads']:>8} {test:>8} {float(r['avg_ts']):>10.1f} {float(r['stddev_ts']):>8.1f}")
PY

echo
echo "Saved: ${OUT}/bench.csv, meta.json, lscpu.txt"