#!/usr/bin/env bash
# setup.sh - Install dependencies, clone and build the experiment code, and
# download its model.
set -euo pipefail

REPO_URL=https://github.com/ggml-org/llama.cpp.git
REPO_REF=v0.6.0
WORKDIR=$HOME/llm-bench

# System packages
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential cmake git curl libcurl4-openssl-dev libssl-dev

# Clone
mkdir -p "$WORKDIR"
cd "$WORKDIR"
[[ -d src ]] || git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" src

# Build
cmake -S src -B src/build -DCMAKE_BUILD_TYPE=Release
cmake --build src/build -j"$(nproc)" --target llama-bench llama-cli

# Model
MODEL_PATH=$WORKDIR/qwen2.5-0.5b-instruct-q4_k_m.gguf
[[ -s $MODEL_PATH ]] || curl -L --fail -o "$MODEL_PATH" \
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf

cat > env.sh << ENV
export WORKDIR="$WORKDIR"
export REPO_REF="$REPO_REF"
export LLAMA_BIN="$WORKDIR/src/build/bin"
export MODEL_PATH="$MODEL_PATH"
ENV
