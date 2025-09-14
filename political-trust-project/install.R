# Install project packages
pkgs <- c(
  "tidyverse","caret","rpart","rpart.plot","randomForest","pROC",
  "readxl","MatchIt","cobalt","broom","here","yaml","janitor",
  "glmnet","MASS","car","brant","knitr"
)
new <- pkgs[!(pkgs %in% installed.packages()[,"Package"])]
if (length(new)) install.packages(new, repos = "https://cloud.r-project.org")