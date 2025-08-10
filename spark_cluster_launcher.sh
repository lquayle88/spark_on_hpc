#!/bin/bash

# SLURM scheduler flags
#SBATCH --job-name=spark-cluster
#SBATCH --nodes=3               # node count
#SBATCH --ntasks-per-node=1     # keep as 1
#SBATCH --cpus-per-task=3       # change as needed
#SBATCH --mem=8G                # memory per node
#SBATCH --time=24:00:00

# load spark module
module purge
module load apps/spark/3.4.4

# start the Spark standalone cluster
spark-start

# source environment set up by spark-start
source "${HOME}/.spark-local/${SLURM_JOB_ID}/spark/conf/spark-env.sh"

# confirm the claster start-up
echo "***** Spark cluster is running *****"

echo "SPARK_MASTER_URL: ${SPARK_MASTER_URL}"
echo "SPARK_MASTER_WEBUI: ${SPARK_MASTER_WEBUI}"
echo "SPARK_CONNECT_HOST: ${SPARK_CONNECT_HOST:-$(hostname -f)}"
echo "SPARK_CONNECT_PORT: ${SPARK_CONNECT_PORT:-15002}"

# set up SSH tunnel instructions dynamically
node=$(hostname -s)
user=$(whoami)
cluster=$(hostname -f | awk -F"." '{print $3}')
domain=".shu.ac.uk"

# extract web port from SPARK_MASTER_WEBUI
web_port=$(echo "${SPARK_MASTER_WEBUI}" | awk -F ":" '{print $3}')

# print SSH tunnel instructions
cat <<EOM

To access the Spark Master Web UI (optional, for debugging):

MacOS or Linux:
ssh -N -L ${web_port}:${node}:${web_port} ${user}@${cluster}${domain}

Then open: http://localhost:${web_port}

To connect from your laptop via Spark Connect (this is what sparklyr will use):

MacOS or Linux:
ssh -N -f -L 15002:localhost:15002 ${user}@${cluster}${domain}

Then in R (on your laptop):

library(sparklyr)

sc <- spark_connect(
  master  = "sc://localhost:15002",
  method  = "spark_connect",
  version = "3.4.4"
)

EOM

# stop the connect server and the standalone daemons when the job ends
cleanup() {
  echo "Stopping Spark Connect server and standalone daemons..."
  "${SPARK_HOME}/sbin/stop-connect-server.sh" || true
  "${SPARK_HOME}/sbin/stop-master.sh" || true
  # Workers are started under srun; the pkill below is your existing catch-all
  pkill -u "$USER" -f 'org.apache.spark.deploy.worker.Worker' || true
  rm -rf "$HOME/.spark-local/$SLURM_JOB_ID"
}
trap cleanup SIGTERM SIGINT EXIT

# keep job alive for interactive session
sleep infinity
