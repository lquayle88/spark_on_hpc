# Spark on HPC

**Run Apache Spark in standalone mode on SLURM-managed HPC clusters with Spark Connect for R via [`sparklyr`](https://spark.posit.co/).**

This repository contains scripts and documentation for deploying a multi-node Spark cluster on an HPC system and connecting to it from your local R environment:

* **`spark_cluster_launcher.sh`**: A SLURM batch script to allocate HPC resources, launch the cluster, and print SSH port forwarding instructions for Spark Connect and the Spark Web UI.
* **`spark-start`**: A helper script to configure Spark, start the Master and workers across allocated nodes, and run a Spark Connect server.

## Features

* Standalone Spark cluster across multiple HPC nodes
* Automatic driver/worker resource allocation
* Per-job configuration and scratch directories
* Spark Connect server listening on a fixed port (`15002` by default)
* Ready-to-use `sparklyr` connection from your laptop via SSH tunnel
* Optional port forwarding to the Spark Master and Application Web UIs for monitoring

## Requirements

* SLURM-managed HPC cluster
* SSH access to the HPC system
* Spark 3.4+ installed and available as a module (tested with 3.4.4)
* `sparklyr` (≥ 1.8.4) and `pysparklyr` (≥ 0.1.3) installed locally in R

## Installation

1. Clone this repository to your HPC home directory:

```bash
git clone https://github.com/yourusername/spark_on_hpc.git
cd spark_on_hpc
```

2. Make `spark-start` executable and move it into your `~/bin` directory (so it’s in your `PATH`):

```bash
chmod +x spark-start
mkdir -p ~/bin
mv spark-start ~/bin/
```

3. Verify it’s available:

```bash
which spark-start
```

You should see something like:

```
/${HOME}/${USER}/bin/spark-start
```

## Usage

1. **Submit the SLURM batch job**:

```bash
sbatch spark_cluster_launcher.sh
```

2. **Check job output** to find:

   * Spark Master URL
   * Spark Connect host and port
   * SSH tunnel commands for Web UI and Spark Connect

3. **Forward the Spark Connect port from your laptop**:

```bash
ssh -N \
  -L 15002:<spark_master_hostname>:15002 \
  -L 8080:<spark_master_hostname>:8080 \
  -L 4040:<spark_master_hostname>:4040 \
  username@cluster.domain
```

*(Note: Ensure `spark_master_hostname`, `username` `cluster` and `domain` are replaced with your HPC credentials)*

Then open:

* Master UI (cluster overview): http://localhost:8080
* Application UI (multi-tab): http://localhost:4040

4. **Connect from R using `sparklyr`**:

```r
library(sparklyr)

sc <- spark_connect(
  master  = "sc://localhost:15002",
  method  = "spark_connect",
  version = "3.4.4"
)
```

5. **When done**:

Disconnect from Spark in R:

```r
spark_disconnect(sc)
```

Cancel the SLURM job:

```bash
scancel <jobid>
```

## File Overview

### `spark_cluster_launcher.sh`

* SLURM resource requests (`--nodes`, `--cpus-per-task`, `--mem`, `--time`)
* Calls `spark-start` to configure and launch the cluster
* Sources per-job Spark environment
* Prints connection details and SSH tunnelling instructions
* Cleans up Spark services on job termination

### `spark-start`

* Loads the Spark module
* Validates SLURM environment variables
* Creates job-specific Spark configuration and scratch directories
* Starts Spark Master, captures URLs, and distributes worker start scripts
* Reserves CPU/memory for the driver on its node
* Launches Spark Connect server on `0.0.0.0:15002`
* Makes connection details available via `spark-env.sh`

## Notes

* The scripts assume Spark is installed as a module (`module load apps/spark/3.4.4`); adjust for your HPC environment.
* Port `15002` is fixed for Spark Connect — change in both scripts if needed.
* Web UI is accessible via SSH tunnel to the Application and/or Master node’s web port.
* For best performance, request all CPU cores and memory per node in SLURM before moving to reqeust resources from subsequent nodes.

## License

MIT License - please see [LICENSE](LICENSE) for details.
