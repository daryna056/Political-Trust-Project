# Political Trust Modeling & Propensity Score Matching (ESS)

_Reproducible R project to study determinants of **political trust** and the causal association between **trust in the legal system** and political trust. Includes supervised ML (logit, tree, random forest), **Propensity Score Matching (ATT)**, and **ordinal/binary regression**—with a clean repo layout, configuration, CI, and reproducibility via `renv`._

[![R](https://img.shields.io/badge/R-%3E%3D%204.2-blue)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](#license)
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-lightgrey)](#continuous-integration)

---

## Table of Contents
- [Highlights](#highlights)
- [Results Preview](#results-preview)
- [Data & Variables](#data--variables)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
  - [RStudio](#rstudio)
  - [Terminal](#terminal)
- [Configuration](#configuration)
- [Methods](#methods)
  - [Data Prep](#data-prep)
  - [Supervised ML](#supervised-ml)
  - [Propensity Score Matching (PSM)](#propensity-score-matching-psm)
  - [Ordinal & Binary Models](#ordinal--binary-models)
- [Interpreting Outputs](#interpreting-outputs)
- [Reproducibility](#reproducibility)
- [Continuous Integration](#continuous-integration)
- [Troubleshooting](#troubleshooting)
- [Roadmap / Extensions](#roadmap--extensions)
- [How to Cite](#how-to-cite)
- [License](#license)
- [Acknowledgements & Maintainer](#acknowledgements--maintainer)

---

## Highlights
- **End-to-end pipeline**: data prep → ML models → PSM → ordinal/binary models.
- **Leakage-safe ML**: after creating `trstplt_binary` from `trstplt`, the raw `trstplt` is **dropped** from predictors.
- **Config-driven**: adjust paths & parameters in `config.yml`; keep private data out of Git.
- **Reproducible**: optional `renv.lock` to freeze package versions.
- **Artifacts**: figures & tables saved to `outputs/` (ROC curves, RF importance, Love plot, ATT estimates, confusion matrices, pseudo-R²).

---

## Results Preview
> These render from the committed images.

<p align="left">
  <img src="https://raw.githubusercontent.com/daryna056/political-trust-project/main/outputs/figures/roc_all_models.png" width="400" alt="ROC: all models" />
  <img src="https://raw.githubusercontent.com/daryna056/political-trust-project/main/outputs/figures/rf_var_importance.png" width="400" alt="RF Variable Importance" />
  <img src="https://raw.githubusercontent.com/daryna056/political-trust-project/main/outputs/figures/psm_love_plot.png" width="400" alt="PSM Love Plot" />
</p>






---

## Data & Variables

**Expected columns (ESS-style):**

- **Outcome**
  - `trstplt` — trust in politicians (0–10).  
  - **Derived:** `trstplt_binary` (≥ 7 → 1; else 0) — created during prep.

- **Key covariates**  
  `agea`, `gndr`, `stfeco`, `stfedu`, `stfdem`, `ppltrst`, `hinctnta`, `lrscale`, `medcrgvc`, and `edlvdch` (recoded to ordered **`education_group`**).

- **Treatment (for PSM)**  
  `trstlgl` — trust in legal system (0–10). **Treatment = `trstlgl ≥ 8`**.

> If your education field isn’t `edlvdch`, update the mapping in `R/01_data_prep.R`.

---

## Repository Structure
```
R/
  01_data_prep.R              # read/clean/recode; build trstplt_binary; save prepped.rds
  02_modeling_ml.R            # logistic, decision tree, random forest + ROC/F1/CM; importance
  03_psm_analysis.R           # PSM (nearest/logit/caliper), balance, ATT on matched sample
  04_ordinal_binary_models.R  # ordinal logit, Brant test, binary logit, pseudo-R²
data/                         # place your Excel/CSV here (git-ignored)
outputs/
  figures/                    # plots (tracked via .gitignore exceptions)
  tables/                     # summaries/coefficients/ATT (tracked via .gitignore exceptions)
.github/workflows/
  R-CMD-check.yml             # lightweight CI to sanity-check scripts
install.R                     # install required packages
config.yml                    # central config (paths, seeds, params)
run_all.R                     # one-click pipeline runner
Makefile                      # terminal workflow: make all
LICENSE                       # MIT
README.md
```

---

## Quick Start

### RStudio
1. Open `political-trust-project.Rproj`.
2. In the Console:
   ```r
   source("install.R")   # first time only
   source("run_all.R")   # or run scripts 01 → 04 individually
   ```

### Terminal
```bash
R -q -e "source('install.R')"   # first time only
make all
```

**Outputs land in:**
- `outputs/figures/` (ROC curves, RF importance, Love plot, etc.)
- `outputs/tables/` (summaries, coefficients, pseudo-R², ATT CSVs)

---

## Configuration
All user-specific settings live in `config.yml`. Example:
```yaml
paths:
  data_file: "data/ess_ch.xlsx"     # your raw data file
  output_dir: "outputs"

seed: 1234

ml:
  test_size: 0.2
  rpart_cp: 0.01
  rf_ntree: 500

psm:
  treat_cutoff: 8           # trstlgl ≥ cutoff => treated
  method: "nearest"
  distance: "logit"
  caliper: 0.2
```
> Ensure `paths.data_file` matches your actual filename.

---

## Methods

### Data Prep
- Replace special codes `{77, 88, 999, 7777, 8888}` with `NA`; drop rows with missing essentials.
- Recode `edlvdch` → ordered `education_group` (primary → doctoral).
- Create `trstplt_binary` (≥ 7 → 1).
- **Important:** remove `trstplt` from predictors to avoid leakage.
- Drop `cntry` and raw `edlvdch` (use `education_group`).

### Supervised ML
- Split 80/20 using `caret::createDataPartition`.
- Models: logistic regression, decision tree (`rpart`, `cp` from config), random forest (`ntree` from config).
- Metrics: confusion matrix, AUC (ROC), F1, combined ROC plot.
- Saves model summaries and RF variable importance.

### Propensity Score Matching (PSM)
- Treatment: high legal trust (`trstlgl ≥ 8` by default).
- Propensity model: logistic.
- Matching: nearest neighbor; configurable `caliper`.
- Balance: Love plot + numeric balance table.
- Effect: **ATT** from a logit of `trstplt_binary ~ treatment` on the matched sample.

### Ordinal & Binary Models
- Ordinal logit on grouped `trstplt` (Low/Middle/High).
- Diagnostics: parallel-lines check (`brant`), multicollinearity (`car::vif`).
- Binary logit on `trstplt_binary` with same covariates.
- Fit: pseudo-R² (McFadden, Cox–Snell), confusion matrices, coefficient tables.

---

## Interpreting Outputs
- **ROC/AUC:** higher AUC ⇒ better discrimination on the test set.
- **RF importance:** highlights predictive features (not causal).
- **PSM balance:** small absolute standardized mean differences after matching ⇒ good balance.
- **ATT (PSM):** odds ratio > 1 ⇒ high legal trust associated with higher odds of political trust (matched sample).
- **Ordinal/Binary coefficients:** check signs, magnitudes, significance; use pseudo-R² for context.

> ⚠️ **Causality caveat:** PSM adjusts only for observed covariates. Unobserved confounding may remain. Consider sensitivity checks, alternative calipers/ratios/kernels, or doubly-robust estimators.

---

## Reproducibility
Using **renv** (recommended):
```r
install.packages("renv")
renv::init()
renv::snapshot()   # commits renv.lock with exact package versions
```
Keep `renv/library/` ignored; commit `renv.lock` for collaborators.

---

## Continuous Integration
A lightweight GitHub Actions workflow (`.github/workflows/R-CMD-check.yml`) runs a sanity check to ensure scripts execute without errors.

---

## Troubleshooting
- **File not found**: verify `config.yml: paths.data_file` exactly matches your file.
- **Perfect AUC / convergence warnings**: check for leakage (ensure `trstplt` is **not** among predictors).
- **Function masking (e.g., `select()`)**: prefer fully-qualified calls like `dplyr::select()` and `tidyselect::any_of()`.

---

## Roadmap / Extensions
- Cross-validation & threshold tuning (Youden’s J); calibration plots.
- Penalized models (`glmnet`) for separation/regularization.
- Heterogeneous treatment effects (CATE) via causal forests (`grf`).
- Multi-country analysis with fixed effects; survey weights.
- R Markdown report under `reports/` pulling artifacts from `outputs/`.

---

## How to Cite
> Author (2025). _Political Trust Modeling & Propensity Score Matching (ESS)._  
> GitHub repository: https://github.com/<your-username>/political-trust-project

(Optionally add a `CITATION.cff` to enable GitHub’s “Cite this repository” button.)

---

## License
MIT License — see [`LICENSE`](LICENSE).

---

## Acknowledgements & Maintainer
Built with: **tidyverse**, **caret**, **rpart**, **randomForest**, **pROC**, **MatchIt**, **cobalt**, **broom**, **MASS**, **car**, **brant**, **knitr**, **janitor**, **yaml**, **here**.

**Maintainer:** Daryna — Issues and pull requests welcome!
