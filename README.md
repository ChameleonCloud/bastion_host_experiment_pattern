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

## Local development

The notebook targets Chameleon JupyterHub, which sets up authentication and SSH keys for you. You can also run it from your own machine, in VS Code or a local Jupyter. There it checks whether it's on JupyterHub and handles authentication and SSH keys differently, as described below.

### Install dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Adapting to a different experiment

The lease, server, and networking cells in the notebook don't depend on the experiment. Three files do:

| File | Role |
| --- | --- |
| `scripts/setup.sh` | Prepares the instance: installs packages, then clones and builds the experiment code |
| `scripts/benchmark.sh` | Runs the experiment on the instance |
| `bench_results.py` | Brings the results back to the notebook and analyzes them |

To run a different experiment, such as one hosted on GitHub:

1. **Setup.** In `scripts/setup.sh`, set `REPO_URL` to the experiment's repository and `REPO_REF` to a tag, so every run gets the same code, or upload your files without git.
Replace the build step with the project's own install or compile command, and list its system packages in the `apt-get install` line.

2. **Run.** Replace `scripts/benchmark.sh` with whatever runs your experiment on the instance.

3. **Results.** Replace `bench_results.py` with code that copies your output back and analyzes it. It may be useful to resuse patterns in bench_results.py, such as the `get_results()` function that copies files from the instance to the notebook.

4. **Notebook.** Choose the node type or flavor, the image, and the lease duration your experiment needs. Update the `upload` and `execute` cells to run your scripts.

5. **Descriptions.** Update this README and `trovi.json`.

## Contributing to an existing experiment

If you improve an experiment you found on Trovi, for example by fixing a bug, supporting other hardware, or extending the analysis, consider sending the change back to its authors rather than only keeping your own copy.

- **Contact the authors.** The authors are listed on the artifact's Trovi page and in its `trovi.json`, often with an email address. You can also leave a comment at the bottom of the artifact's page. Trovi doesn't send email notifications for comments yet, so email the authors directly about anything that needs an answer.
- **Fork it on GitHub.** If the experiment's code is on GitHub, fork the repository, make your change on a branch, and open a pull request against the original. Describe what you changed and which site and node type or flavor you tested it on. Once the authors merge it, they can publish it as a new version of the artifact.
- **Publish your own variant.** If your version goes in a different direction, share it as a new artifact. Credit the original in its description, and add the original under "Linked Artifacts" so readers can find both.

