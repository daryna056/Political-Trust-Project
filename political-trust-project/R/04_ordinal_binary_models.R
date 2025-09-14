# R/04_ordinal_binary_models.R
# ----------------------------
# Ordinal logistic (grouped), Brant test, binary logistic, pseudo R^2, metrics.

library(dplyr)
library(readxl)
library(glmnet)
library(MASS)
library(car)
library(brant)
library(caret)
library(knitr)
library(here)
library(yaml)

cfg <- yaml::read_yaml(here::here("config.yml"))
set.seed(cfg$seed %||% 123)

# Use original Excel to reproduce ordinal (since some vars dropped earlier)
data_path <- here::here(cfg$data_file %||% "data/ess_political_trust.xlsx")
stopifnot(file.exists(data_path))
data_clean <- read_excel(data_path, col_names = TRUE)

# Remove common missing codes by column (based on user's second script)
missing_codes <- list(
  trstplt = c(77, 88), hinctnta = c(77, 88), stfedu = c(88), nwspol = c(7777, 8888),
  trstlgl = c(77, 88), stfdem = c(77, 88), agea = c(999), stfeco = c(77, 88),
  medcrgvc = c(77, 88), edlvdch = c(7777), ppltrst = c(88), gincdif = c(8), fairelc = c(77,88), lrscale = c(77,88)
)
for (col in names(missing_codes)) {
  if (col %in% names(data_clean)) {
    data_clean <- data_clean %>% dplyr::filter(!.data[[col]] %in% missing_codes[[col]])
  }
}

# Type conversions
data_clean <- data_clean %>%
  mutate(
    across(c("nwspol", "ppltrst", "trstlgl", "stfdem", "stfedu", "agea", "hinctnta", "stfeco", "medcrgvc"),
           ~ suppressWarnings(as.numeric(as.character(.)))),
    across(c("emplrel", "gincdif"), ~ factor(., ordered = TRUE)),
    gndr = factor(gndr),
    trstplt = factor(trstplt)
  )

# Education rearrangement (finer groups)
education_group <- NA
education_group[data_clean$edlvdch %in% c(1, 2)] <- "Primary Education"
education_group[data_clean$edlvdch %in% c(3, 4, 5)] <- "Lower Secondary"
education_group[data_clean$edlvdch %in% c(6, 7, 8, 9, 10)] <- "Upper Secondary"
education_group[data_clean$edlvdch %in% c(11, 12, 13, 14, 15, 16)] <- "Vocational Training"
education_group[data_clean$edlvdch %in% c(17, 18, 19, 20, 21, 22)] <- "Tertiary Education"
education_group[data_clean$edlvdch %in% 23] <- "Doctoral Degree"
data_clean$education_group <- as.numeric(factor(education_group,
  levels = c("Primary Education","Lower Secondary","Upper Secondary","Vocational Training","Tertiary Education","Doctoral Degree"),
  ordered = TRUE
))

# Frequency table of original trstplt
trust_distribution <- data_clean %>%
  group_by(trstplt) %>% summarise(Frequency = n()) %>%
  mutate(Percentage = (Frequency / sum(Frequency))*100, Cumulative_Percentage = cumsum(Percentage))
write.csv(trust_distribution, here::here("outputs","tables","trust_distribution_raw.csv"), row.names = FALSE)

# Model 1: ordinal logistic with raw trstplt
model1 <- polr(trstplt ~ nwspol + ppltrst + trstlgl + stfdem + stfedu + gndr + agea +
                 hinctnta + stfeco + medcrgvc + education_group + fairelc,
               data = data_clean, Hess = TRUE)
capture.output(vif(model1), file = here::here("outputs","tables","ordinal_vif_model1.txt"))
# Brant test may fail with sparse categories
capture.output(try(brant(model1), silent = TRUE), file = here::here("outputs","tables","ordinal_brant_model1.txt"))

# Re-group dependent variable and re-fit
data_clean <- data_clean %>%
  mutate(trstplt = as.numeric(as.character(trstplt)),
         trstplt_group = cut(trstplt, breaks = c(-Inf, 3, 6, Inf), labels = c("Low","Middle","High"), include.lowest = TRUE),
         trstplt_group = factor(trstplt_group, levels = c("Low","Middle","High")))

trust_table <- data_clean %>% group_by(trstplt_group) %>% summarise(Frequency = n()) %>%
  mutate(Percentage = round((Frequency/sum(Frequency))*100,1))
write.csv(trust_table, here::here("outputs","tables","trust_distribution_grouped.csv"), row.names = FALSE)

model2 <- polr(trstplt_group ~ ppltrst + trstlgl + stfdem + stfedu + gndr + agea +
                 hinctnta + stfeco + medcrgvc + education_group + fairelc,
               data = data_clean, Hess = TRUE)
capture.output(vif(model2), file = here::here("outputs","tables","ordinal_vif_model2.txt"))
capture.output(try(brant(model2), silent = TRUE), file = here::here("outputs","tables","ordinal_brant_model2.txt"))

# Confusion matrix
predicted_categories <- predict(model2, type = "class")
cm <- confusionMatrix(predicted_categories, data_clean$trstplt_group)
capture.output(cm, file = here::here("outputs","tables","ordinal_confusion_matrix.txt"))

# Pseudo R^2
ll_model <- logLik(model2); ll_null <- logLik(update(model2, . ~ 1))
mcfadden_r2 <- 1 - as.numeric(ll_model / ll_null)
cox_snell_r2 <- 1 - exp(-2 * (ll_model - ll_null) / nobs(model2))
sink(here::here("outputs","tables","ordinal_pseudo_r2.txt"))
cat("McFadden:", mcfadden_r2, "\nCox & Snell:", cox_snell_r2, "\n")
sink()

# Coefficients with p-values
coefs <- summary(model2)$coefficients
p_values <- 2 * (1 - pnorm(abs(coefs[, "t value"])))
results <- data.frame(
  Estimate = coefs[, "Value"],
  Std_Error = coefs[, "Std. Error"],
  Z_value = coefs[, "t value"],
  P_value = p_values
)
write.csv(results, here::here("outputs","tables","ordinal_coefficients.csv"), row.names = FALSE)

# Binary logistic
data_clean <- data_clean %>%
  mutate(trstplt_binary = factor(ifelse(trstplt <= 5, 0, 1), levels = c(0,1)))
binary_model <- glm(trstplt_binary ~ ppltrst + trstlgl + stfdem + stfedu + gndr + agea +
                      hinctnta + stfeco + medcrgvc + education_group + fairelc,
                    data = data_clean, family = binomial)
sum_bin <- summary(binary_model)
write.csv(cbind(Predictor = rownames(sum_bin$coefficients), as.data.frame(sum_bin$coefficients)),
          here::here("outputs","tables","binary_logit_coefficients.csv"), row.names = FALSE)

ll_binary_model <- logLik(binary_model); ll_null_binary <- logLik(update(binary_model, . ~ 1))
mcfadden_r2_binary <- 1 - as.numeric(ll_binary_model / ll_null_binary)
cox_snell_r2_binary <- 1 - exp(-2 * (ll_binary_model - ll_null_binary) / nobs(binary_model))
sink(here::here("outputs","tables","binary_pseudo_r2.txt"))
cat("McFadden:", mcfadden_r2_binary, "\nCox & Snell:", cox_snell_r2_binary, "\n")
sink()

pred_binary <- predict(binary_model, type = "response")
pred_class <- ifelse(pred_binary >= 0.5, 1, 0)
cm_bin <- confusionMatrix(factor(pred_class, levels = c(0,1)), data_clean$trstplt_binary)
capture.output(cm_bin, file = here::here("outputs","tables","binary_confusion_matrix.txt"))

message("Ordinal & binary models complete. Tables saved to outputs/.")