# Political Trust Modeling & Propensity Score Matching (ESS)

End-to-end, reproducible R project investigating determinants of political trust
and the effect of legal trust using:
- Supervised ML (logit, decision tree, random forest)
- Ordinal & binary logistic regression
- Propensity Score Matching (ATT)
- Clean repo layout, config-driven, and CI-ready

## Quickstart

```bash
# 1) Put your Excel file in data/ and update config.yml if needed
# 2) Install deps
R -q -e "source('install.R')"

# 3) (Optional) Initialize renv for a locked environment
R -q -e "renv::init(); renv::snapshot()"

# 4) Run everything
make all
```

Outputs will land in `outputs/figures` and `outputs/tables`.

## Repo Structure

```
R/                      # Analysis scripts
data/                   # (git-ignored) place input data here
outputs/                # Figures & tables
reports/                # R Markdown reports (optional)
config.yml              # Central configuration (paths, seeds, params)
install.R               # Install required packages
Makefile                # One-command pipelines
.github/workflows/      # CI workflow
```

## Scripts

- **R/01_data_prep.R**: Loads Excel, cleans codes → NA, recodes education, creates `trstplt_binary`, saves an RDS.
- **R/02_modeling_ml.R**: Train/test split, logit, decision tree, random forest, ROC & metrics, variable importance.
- **R/03_psm_analysis.R**: PSM on legal trust (`trstlgl ≥ 8`), covariate balance, ATT estimation.
- **R/04_ordinal_binary_models.R**: Ordinal logit (with grouping), Brant test, binary logit, pseudo R², metrics.

## Data

This project expects an ESS-like dataset with columns used in the scripts (e.g., `trstplt`, `trstlgl`, `edlvdch`, etc.).
Place the file into `data/` and set `config.yml:data_file` accordingly.

## License

MIT — see `LICENSE`.