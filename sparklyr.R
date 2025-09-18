## Spark Connection Test
## Lewis Quayle, Ph.D. (drlquayle@gmail.com)
## 2025-09-18


# setup -------------------------------------------------------------------

# load dependencies
# install.packages("sparklyr")
# install.packages("pysparklyr")
# pysparklyr::install_pyspark(version = "3.4.4")

library(dplyr)
library(sparklyr)


# configuration -----------------------------------------------------------

# base config (override here as needed)
config <- spark_config()
# config$spark.executor.memory <- "4G"
# config$spark.driver.memory <- "4G"
# config$spark.executor.cores <- 1


# connection --------------------------------------------------------------

# connect to spark using sparklyr
sc <-
  spark_connect(
    master  = "sc://localhost:15002",
    method  = "spark_connect",
    version = "3.4.4",
    config  = config
  )


# minimal test ------------------------------------------------------------

# quick sanity check: enumerate available tables
DBI::dbListTables(sc)

# upload the built-in iris dataset and compute a trivial aggregation
df <- copy_to(sc, iris, overwrite = TRUE)

df %>%
  group_by(Species) %>%
  summarise(
    mean_sepal_length = mean(Sepal_Length, na.rm = TRUE)
  )

# confirm table presence after write
DBI::dbListTables(sc)


# disconnect --------------------------------------------------------------

spark_disconnect(sc)
