#!/usr/bin/env bash
<<<<<<< HEAD

echo "Setting up experimental environment"

set -x

sudo apt-get update -yqq
sudo apt-get install -qq -y stress-ng python3-swiftclient "linux-tools-$(uname -r)"
sudo modprobe intel_rapl_msr


=======
# setup.sh - Prepare a fresh Ubuntu 24.04 instance (bare metal or VM) for the
# CPU LLM inference experiment. Builds llama.cpp from source and downloads a
# small quantized model. Safe to re-run; finished steps are skipped.
#
# Usage:  bash setup.sh
# Override any setting via environment variables, e.g.:
#   MODEL_FILE=qwen2.5-1.5b-instruct-q4_k_m.gguf \
#   MODEL_REPO=Qwen/Qwen2.5-1.5B-Instruct-GGUF bash setup.sh
set -euo pipefail

LLAMA_CPP_TAG="${LLAMA_CPP_TAG:-v0.6.0}"
WORKDIR="${WORKDIR:-$HOME/llm-bench}"
MODEL_REPO="${MODEL_REPO:-Qwen/Qwen2.5-0.5B-Instruct-GGUF}"
MODEL_FILE="${MODEL_FILE:-qwen2.5-0.5b-instruct-q4_k_m.gguf}"

log() { echo -e "\n==> $*"; }

# --- 1. OS check -----------------------------------------------------------
. /etc/os-release
if [[ "${ID}" != "ubuntu" || "${VERSION_ID}" != "24.04" ]]; then
  echo "WARNING: tested on Ubuntu 24.04; detected ${PRETTY_NAME}. Continuing anyway."
fi

# --- 2. System packages ----------------------------------------------------
log "Installing build dependencies"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential cmake git curl ca-certificates python3 \
  libcurl4-openssl-dev libssl-dev

mkdir -p "${WORKDIR}/models"
cd "${WORKDIR}"

# --- 3. Build llama.cpp (pinned version) -----------------------------------
if [[ ! -d llama.cpp ]]; then
  log "Cloning llama.cpp ${LLAMA_CPP_TAG}"
  git clone --depth 1 --branch "${LLAMA_CPP_TAG}" \
    https://github.com/ggml-org/llama.cpp.git
fi

if [[ ! -x llama.cpp/build/bin/llama-bench || ! -x llama.cpp/build/bin/llama-cli ]]; then
  log "Building llama.cpp with $(nproc) parallel jobs"
  # GGML_NATIVE optimizes for this machine's CPU (AVX2/AVX-512 etc.).
  # Fine here because we build and run on the same instance.
  cmake -S llama.cpp -B llama.cpp/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_NATIVE=ON \
    -DLLAMA_BUILD_TESTS=OFF
  cmake --build llama.cpp/build --config Release -j"$(nproc)" \
    --target llama-bench llama-cli
fi

# --- 4. Download model -----------------------------------------------------
MODEL_PATH="${WORKDIR}/models/${MODEL_FILE}"
if [[ ! -s "${MODEL_PATH}" ]]; then
  log "Downloading ${MODEL_REPO}/${MODEL_FILE}"
  curl -L --fail --retry 3 -C - -o "${MODEL_PATH}.part" \
    "https://huggingface.co/${MODEL_REPO}/resolve/main/${MODEL_FILE}"
  mv "${MODEL_PATH}.part" "${MODEL_PATH}"
fi

# --- 5. Record config for the other scripts --------------------------------
cat > "${WORKDIR}/env.sh" << ENV
export WORKDIR="${WORKDIR}"
export LLAMA_BIN="${WORKDIR}/llama.cpp/build/bin"
export LLAMA_CPP_TAG="${LLAMA_CPP_TAG}"
export MODEL_PATH="${MODEL_PATH}"
ENV

log "Setup complete"
echo "  llama.cpp: ${LLAMA_CPP_TAG}"
echo "  model:     ${MODEL_PATH} ($(du -h "${MODEL_PATH}" | cut -f1))"
echo "  next:      bash run_bench.sh"
>>>>>>> 29d3336 (Add single_instance notebook)
