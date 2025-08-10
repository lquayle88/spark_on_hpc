#!/bin/bash

#SBATCH --job-name=spark-cluster
#SBATCH --nodes=3               # node count
#SBATCH --ntasks-per-node=1     # keep as 1
#SBATCH --cpus-per-task=3       # change as needed
#SBATCH --mem=8G                # memory per node
#SBATCH --time=24:00:00         # wall-clock time

# start the Spark standalone cluster
spark-start

# source environment set up by spark-start
source "${HOME}/.spark-local/${SLURM_JOB_ID}/spark/conf/spark-env.sh"

# confirm the cluster start-up
echo
echo "***** Spark cluster is running *****"
echo
echo "SPARK_MASTER_URL: ${SPARK_MASTER_URL}"
echo "SPARK_MASTER_WEBUI: ${SPARK_MASTER_WEBUI}"
echo "SPARK_CONNECT_HOST: ${SPARK_CONNECT_HOST:-$(hostname -f)}"
echo "SPARK_CONNECT_PORT: ${SPARK_CONNECT_PORT:-15002}"

# set up SSH tunnel instructions dynamically
user=$(whoami)
host=$(hostname -f)
cluster=$(hostname -f | awk -F"." '{print $3}')
domain=".shu.ac.uk"

# extract ports from SPARK_MASTER_WEBUI
connect_port="${SPARK_CONNECT_PORT:-15002}"
web_port=$(echo "${SPARK_MASTER_WEBUI}" | awk -F ":" '{print $3}')
app_ui_port="$(awk '/Successfully started service.*SparkUI.*port/ {print $NF}' "${SPARK_LOG_DIR}"/spark-*-SparkConnectServer-*.out 2>/dev/null | tail -n1)"
: "${app_ui_port:=4040}"

# print SSH tunnel instructions
cat <<EOM

SSH tunnel (Spark Connect + Master UI + Application UI):

ssh -N \\
  -L ${connect_port}:${host}:${connect_port} \\
  -L ${web_port}:${host}:${web_port} \\
  -L ${app_ui_port}:${host}:${app_ui_port} \\
  ${user}@${cluster}${domain}

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

  # stop workers launched via srun (best effort)
  pkill -u "$USER" -f 'org.apache.spark.deploy.worker.Worker' || true

  # belt-and-braces: kill any leftover Spark JVMs for this user
  pkill -u "$USER" -f 'org.apache.spark.sql.connect.service.SparkConnectServer|org.apache.spark.deploy.master.Master|org.apache.spark.deploy.worker.Worker' || true

  # wait for ports to be freed (Master UI, App UI, Connect)
  for p in "${SPARK_CONNECT_PORT:-15002}" "${web_port:-8080}" "${app_ui_port:-4040}"; do
    for i in $(seq 1 10); do
      ss -lntp 2>/dev/null | grep -q ":${p} " || break
      sleep 1
    done
  done

  rm -rf "$HOME/.spark-local/$SLURM_JOB_ID" || true
}
trap cleanup SIGTERM SIGINT EXIT

# keep job alive for interactive session
sleep infinity
