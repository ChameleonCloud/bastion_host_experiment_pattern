# Single Node Experiment: CPU LLM Inference Scaling with llama.cpp

This artifact benchmarks CPU-only large language model inference on a single Chameleon instance. It runs unchanged on a bare metal node or a virtual machine.

NOTE: The experiment here is just for demonstration purposes only.

It uses llama.cpp's `llama-bench` to measure tokens per second for a small quantized model (Qwen2.5-0.5B-Instruct) across a range of thread counts. Prompt processing is compute-bound and keeps scaling as cores are added. Token generation is limited by memory bandwidth and levels off early, which shows why more cores do not always mean faster inference.

The steps of the artifact are:
1. Reserve an instance
2. Launch an Ubuntu 24.04 instance with the reservation
3. Configure networking and security groups for SSH access
4. Install dependencies, build llama.cpp, and download the model (`setup.sh`)
5. Run the thread-count sweep (`run_bench.sh`)
6. Download the results and plot them in the notebook (`bench_results.py`)

The benchmark takes a few minutes on bare metal. Small VMs take longer, mainly for the llama.cpp build. Each run saves its results with hardware metadata (CPU model, core counts, virtualization type, software versions) so result sets can be interpreted later.
