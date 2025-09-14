# run_all.R — convenience wrapper to reproduce everything
source("install.R")                     # first time only
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/tables",  recursive = TRUE, showWarnings = FALSE)
source("R/01_data_prep.R")
source("R/02_modeling_ml.R")
source("R/03_psm_analysis.R")
source("R/04_ordinal_binary_models.R")
cat("\n✔ All steps finished. See outputs/figures and outputs/tables.\n")
