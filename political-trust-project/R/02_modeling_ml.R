# R/02_modeling_ml.R
# ------------------
# Logistic regression, decision tree, and random forest with ROC + metrics.

library(tidyverse)
library(caret)
library(rpart)
library(rpart.plot)
library(randomForest)
library(pROC)
library(here)
library(yaml)

dir.create(here::here("outputs","figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(here::here("outputs","tables"),  recursive = TRUE, showWarnings = FALSE)

cfg <- yaml::read_yaml(here::here("config.yml"))
set.seed(cfg$seed %||% 123)

df <- readRDS(here::here("outputs","prepped.rds"))

# Train-Test Split
split <- createDataPartition(df$trstplt_binary, p = 0.8, list = FALSE)
train <- df[split, ]
test  <- df[-split, ]
test  <- test[, names(train)]

# Evaluation helper
evaluate_model <- function(model_name, probs, preds, true_labels, save_prefix) {
  cm <- confusionMatrix(as.factor(preds), true_labels, positive = "1")
  roc_obj <- roc(as.numeric(true_labels), as.numeric(probs))
  auc_val <- auc(roc_obj)
  precision <- cm$byClass["Precision"]
  recall <- cm$byClass["Sensitivity"]
  f1 <- 2 * ((precision * recall) / (precision + recall))
  cat("\n---", model_name, "---\n")
  print(cm)
  cat("AUC:", round(auc_val, 3), "\n")
  cat("F1 Score:", round(f1, 3), "\n")
  png(here::here("outputs","figures", paste0(save_prefix, "_roc.png")), width=900, height=700, res=120)
  plot(roc_obj, main = paste("ROC Curve -", model_name))
  dev.off()
  list(roc = roc_obj, auc = auc_val, cm = cm, f1 = f1)
}

threshold <- cfg$models$threshold %||% 0.5

# Logistic Regression
logit_model <- glm(trstplt_binary ~ ., data = train, family = "binomial")
logit_probs <- predict(logit_model, test, type = "response")
logit_preds <- ifelse(logit_probs > threshold, 1, 0)
res_logit <- evaluate_model("Logistic Regression", logit_probs, logit_preds, test$trstplt_binary, "logit")

# Decision Tree
tree_model <- rpart(trstplt_binary ~ ., data = train, method = "class", cp = cfg$models$tree_cp %||% 0.015)
tryCatch({
  png(here::here("outputs","figures","decision_tree.png"), width=1000, height=800, res=130)
  rpart.plot(tree_model, main = "Decision Tree")
  dev.off()
}, error = function(e) {
  message("Decision tree plot failed: ", e$message)
  try(dev.off(), silent = TRUE)
})
tree_probs <- predict(tree_model, test)[,2]
tree_preds <- ifelse(tree_probs > threshold, 1, 0)
res_tree <- evaluate_model("Decision Tree", tree_probs, tree_preds, test$trstplt_binary, "tree")

# Random Forest
rf_model <- randomForest(trstplt_binary ~ ., data = train, ntree = cfg$models$rf_ntree %||% 500, importance = TRUE)
rf_probs <- predict(rf_model, test, type = "prob")[,2]
rf_preds <- ifelse(rf_probs > threshold, 1, 0)
res_rf <- evaluate_model("Random Forest", rf_probs, rf_preds, test$trstplt_binary, "rf")

# Combined ROC
roc_logit <- res_logit$roc
roc_tree  <- res_tree$roc
roc_rf    <- res_rf$roc

png(here::here("outputs","figures","roc_all_models.png"), width=1000, height=800, res=130)
plot(roc_logit, col = "blue", lwd = 2, main = "ROC Curves for All Models")
lines(roc_tree, col = "darkgreen", lwd = 2)
lines(roc_rf, col = "red", lwd = 2)
abline(a = 0, b = 1, lty = 2, col = "gray")
legend("bottomright",
       legend = c(paste0("Logistic (AUC = ", round(auc(roc_logit), 3), ")"),
                  paste0("Decision Tree (AUC = ", round(auc(roc_tree), 3), ")"),
                  paste0("Random Forest (AUC = ", round(auc(roc_rf), 3), ")")),
       col = c("blue", "darkgreen", "red"), lwd = 2)
dev.off()

# Save model summaries
sink(here::here("outputs","tables","ml_summaries.txt"))
cat("=== Logistic Regression Summary ===\n")
print(summary(logit_model))
cat("\n=== Decision Tree CP Table ===\n")
printprint <- function(x) {print(x)}; printprintcp <- try(printcp(tree_model), silent=TRUE)
cat("\n=== Random Forest Importance ===\n")
print(importance(rf_model))
sink()

# Save var importance plot
tryCatch({
  png(here::here("outputs","figures","rf_var_importance.png"), width=1000, height=800, res=130)
  varImpPlot(rf_model, main = "Random Forest - Variable Importance")
  dev.off()
}, error = function(e) {
  message("Variable importance plot failed: ", e$message)
  try(dev.off(), silent = TRUE)
})

message("ML analysis complete. Figures and summaries saved to outputs/.")
