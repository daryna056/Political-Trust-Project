# R/03_psm_analysis.R
# -------------------
# Propensity Score Matching: effect of high legal trust on political trust.

library(tidyverse)
library(MatchIt)
library(cobalt)
library(broom)
library(here)
library(yaml)

cfg <- yaml::read_yaml(here::here("config.yml"))
set.seed(cfg$seed %||% 123)

df <- readRDS(here::here("outputs","prepped.rds"))

# Treatment: high legal trust (trstlgl >= 8)
df_psm <- df %>%
  mutate(treatment_legaltrust = ifelse(trstlgl >= 8, 1, 0)) %>%
  select(trstplt_binary, treatment_legaltrust, agea, gndr, education_group,
         stfeco, ppltrst, hinctnta, lrscale, stfdem) %>%
  na.omit()

m <- matchit(
  treatment_legaltrust ~ agea + gndr + education_group + stfeco + ppltrst + hinctnta + lrscale + stfdem,
  data = df_psm,
  method = cfg$psm$method %||% "nearest",
  distance = cfg$psm$distance %||% "logit",
  caliper = cfg$psm$caliper %||% 0.1
)

# Balance summary -> save
s <- summary(m)
sink(here::here("outputs","tables","psm_balance_summary.txt")); print(s); sink()

# Love plot
png(here::here("outputs","figures","psm_love_plot.png"), width=1000, height=800, res=130)
love.plot(m, binary = "std", abs = TRUE, var.order = "unadjusted")
dev.off()

# ATT estimation on matched data
matched <- match.data(m)
att_model <- glm(trstplt_binary ~ treatment_legaltrust, data = matched, family = "binomial")
att_tidy <- broom::tidy(att_model, exponentiate = TRUE, conf.int = TRUE)
write.csv(att_tidy, here::here("outputs","tables","psm_att_logit.csv"), row.names = FALSE)

message("PSM analysis complete. Balance, plots, and ATT saved to outputs/.")