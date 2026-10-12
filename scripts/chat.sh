#!/usr/bin/env bash
# chat.sh - Optional: chat interactively with the benchmarked model.
# Usage:  bash chat.sh [threads]     (default: physical core count)
# Exit with Ctrl+C.
set -euo pipefail

source "${WORKDIR:-$HOME/llm-bench}/env.sh"

THREADS="${1:-$(lscpu -p=Core,Socket | grep -v '^#' | sort -u | wc -l)}"
echo "Starting chat with $(basename "${MODEL_PATH}") using ${THREADS} threads..."

# Models with a chat template (like Qwen2.5-Instruct) start in conversation
# mode automatically. Generation speed is printed when you exit.
exec "${LLAMA_BIN}/llama-cli" \
  -m "${MODEL_PATH}" \
  -t "${THREADS}" \
  -c 4096