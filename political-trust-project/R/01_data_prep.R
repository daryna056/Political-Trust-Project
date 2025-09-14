# R/01_data_prep.R
# -----------------
# Loads, cleans, and prepares data for all downstream scripts.

library(tidyverse)
library(readxl)
library(here)
library(yaml)
library(janitor)

cfg <- yaml::read_yaml(here::here("config.yml"))
set.seed(cfg$seed %||% 123)

data_path <- here::here(cfg$data_file %||% "data/ess_political_trust.xlsx")
stopifnot(file.exists(data_path))

df <- read_excel(data_path) %>% clean_names()

# Replace coded missing values with NA (union of codes from both scripts)
fake_missing_values <- c(77, 88, 999, 7777, 8888)
df <- df %>% mutate(across(everything(), ~ ifelse(. %in% fake_missing_values, NA, .))) %>% na.omit()

# Binary target variable (trust in politicians >=7 := 1)
df <- df %>% mutate(trstplt_binary = factor(ifelse(trstplt >= 7, 1, 0), levels = c(0,1)))

# Education recode (coarser version)
df <- df %>%
  mutate(
    education_group = case_when(
      edlvdch %in% 1:5   ~ "Basic Education",
      edlvdch %in% 6:16  ~ "Secondary/Vocational",
      edlvdch %in% 17:23 ~ "Higher Education",
      TRUE ~ NA_character_
    ),
    education_group = as.numeric(factor(
      education_group,
      levels = c("Basic Education", "Secondary/Vocational", "Higher Education"),
      ordered = TRUE
    ))
  )

# Keep a safe subset, drop some unused
df <- df %>% select(-c(edlvdch, cntry))

# Save prepped data
dir.create(here::here("outputs"), showWarnings = FALSE)
saveRDS(df, here::here("outputs","prepped.rds"))
message("Saved outputs/prepped.rds (", nrow(df), " rows).")