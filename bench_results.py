"""Download and visualize llama-bench results from a Chameleon instance.

Usage in a notebook:

    from bench_results import download_results, load_results, plot_results

    local_dir = download_results(server)          # server has .ssh_connection()
    df, meta, cpu_model = load_results(local_dir)
    plot_results(df, meta, cpu_model)
"""
import json
from pathlib import Path, PurePosixPath

import matplotlib.pyplot as plt
import pandas as pd

RESULT_FILES = ("bench.csv", "meta.json", "lscpu.txt")


def download_results(server, local_root="results", run_dir=None, **kwargs):
    """Copy one result set from the instance to local_root/<run name>/.

    By default fetches the most recent run. Pass run_dir (a remote path) to
    pick a specific one. Extra kwargs are passed to server.ssh_connection().
    """
    with server.ssh_connection(**kwargs) as conn:
        if run_dir is None:
            # Newest directory under ~/llm-bench/results (sorted by mtime).
            # Absolute path needed: fabric's get() does not expand "~".
            result = conn.run(
                'ls -1td "$HOME"/llm-bench/results/*/ 2>/dev/null | head -n 1',
                hide=True, warn=True,
            )
            run_dir = result.stdout.strip().rstrip("/")
            if not run_dir:
                raise FileNotFoundError(
                    "No results found on the instance. Did run_bench.sh finish?"
                )

        remote = PurePosixPath(run_dir)
        local = Path(local_root) / remote.name
        local.mkdir(parents=True, exist_ok=True)

        for name in RESULT_FILES:
            conn.get(str(remote / name), local=str(local / name))

    print(f"Downloaded {remote} -> {local}")
    return local


def load_results(local_dir):
    """Return (dataframe, metadata dict, CPU model string) for one run."""
    local_dir = Path(local_dir)
    df = pd.read_csv(local_dir / "bench.csv")
    meta = json.loads((local_dir / "meta.json").read_text())

    cpu_model = "unknown CPU"
    for line in (local_dir / "lscpu.txt").read_text().splitlines():
        if line.startswith("Model name:"):
            cpu_model = line.split(":", 1)[1].strip()
            break

    # Label each row as prompt processing (pp) or token generation (tg).
    df["test"] = df.apply(
        lambda r: f"pp{r.n_prompt}" if r.n_gen == 0 else f"tg{r.n_gen}", axis=1
    )
    df = df.sort_values(["test", "n_threads"]).reset_index(drop=True)

    # Speedup relative to the single-thread (or smallest) configuration.
    base = df.loc[df.groupby("test")["n_threads"].idxmin()].set_index("test")
    df["speedup"] = df["avg_ts"] / df["test"].map(base["avg_ts"])
    return df, meta, cpu_model


def plot_results(df, meta, cpu_model, save_path=None):
    """Three panels: pp throughput, tg throughput, and speedup vs. ideal."""
    tests = sorted(df["test"].unique())          # e.g. ["pp512", "tg128"]
    colors = {t: c for t, c in zip(tests, ["tab:blue", "tab:orange"])}
    labels = {
        t: ("Prompt processing" if t.startswith("pp") else "Token generation")
        + f" ({t})"
        for t in tests
    }
    phys, logical = meta["physical_cores"], meta["logical_cpus"]
    threads = sorted(df["n_threads"].unique())

    fig, axes = plt.subplots(1, 3, figsize=(16, 4.5))

    def mark_cores(ax):
        ax.axvline(phys, color="gray", ls="--", lw=1, label=f"physical cores ({phys})")
        if logical != phys:
            ax.axvline(logical, color="gray", ls=":", lw=1, label=f"logical CPUs ({logical})")

    def style_x(ax):
        ax.set_xscale("log", base=2)
        ax.set_xticks(threads)
        ax.set_xticklabels(threads)
        ax.set_xlabel("Threads")
        ax.grid(True, alpha=0.3)

    # Panels 1 and 2: absolute throughput, one test per panel (scales differ a lot).
    for ax, test in zip(axes[:2], tests):
        d = df[df["test"] == test]
        ax.errorbar(d["n_threads"], d["avg_ts"], yerr=d["stddev_ts"],
                    marker="o", capsize=3, color=colors[test])
        best = d.loc[d["avg_ts"].idxmax()]
        ax.annotate(f"peak {best.avg_ts:.0f} tok/s\n@ {best.n_threads} threads",
                    (best.n_threads, best.avg_ts), textcoords="offset points",
                    xytext=(0, -35), ha="center", fontsize=9)
        mark_cores(ax)
        style_x(ax)
        ax.set_ylabel("Tokens / second")
        ax.set_title(labels[test])
        ax.set_ylim(bottom=0)
        ax.legend(fontsize=8, loc="upper left")

    # Panel 3: scaling compared with the ideal linear speedup.
    ax = axes[2]
    for test in tests:
        d = df[df["test"] == test]
        ax.plot(d["n_threads"], d["speedup"], marker="o",
                color=colors[test], label=labels[test])
    t_min = min(threads)
    ax.plot(threads, [t / t_min for t in threads], color="black",
            ls="--", lw=1, label="ideal (linear)")
    mark_cores(ax)
    style_x(ax)
    ax.set_yscale("log", base=2)
    ax.set_ylabel(f"Speedup vs. {t_min} thread(s)")
    ax.set_title("Scaling: compute-bound vs. memory-bound")
    ax.legend(fontsize=8, loc="upper left")

    env = "bare metal" if meta.get("virtualization") in ("none", "", None) \
        else f"VM ({meta['virtualization']})"
    fig.suptitle(
        f"{meta['model']} on {meta['hostname']} | {env} | {cpu_model} | "
        f"llama.cpp {meta['llama_cpp_tag']}, {meta['reps']} reps",
        fontsize=11,
    )
    fig.tight_layout()
    if save_path:
        fig.savefig(save_path, dpi=150, bbox_inches="tight")
    plt.show()
    return fig