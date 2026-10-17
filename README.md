# Identifying Everyday Risk Factors for Hypertension

A team data science project (Data Science Micro-Credential, University at Buffalo), in R.
Using CDC NHANES 2017–2018 survey data, we measure how hypertension risk differs by income, race/ethnicity,
age and lifestyle, with a scripted, replicable pipeline and a documented data-quality log.

## Why NHANES

We first evaluated a popular Kaggle hypertension dataset and found strong evidence it was synthetic:
the same ~72% hypertension rate in every country, age and income group, and no feature related to the outcome.
NHANES is real, documented survey data with an official codebook.

## Pipeline

| Step | Script | Does |
|---|---|---|
| 1 | `R/01-download.R` | Downloads the NHANES 2017–2018 tables (DEMO, BPX, BMX, SMQ, PAQ) into `data/raw/` |
| 2 | `R/02-merge-clean.R` | Merges on `SEQN`, keeps adults, audits missing values, duplicates, implausible readings and records lost at each merge |
| 3 | `R/03-variables.R` | Average BP (readings 2–4), hypertension outcome (ACC/AHA 2017, 130/80 mmHg), income-to-poverty, race/ethnicity, age, smoking, activity groups |
| 4 | `R/04-analysis.R` | Hypertension rates by group, correlation, logistic regression against the no-information baseline |
| 5 | `reports/report.Rmd` | Final report: leading risk factors and the data's limitations |

Run everything from the project root:

```r
source("R/01-download.R")
source("R/02-merge-clean.R")
source("R/03-variables.R")
source("R/04-analysis.R")
rmarkdown::render("reports/report.Rmd")
```

## Layout

```
R/            pipeline scripts, numbered in run order
reports/      R Markdown report
docs/         data-quality-log.md, codebook notes, decisions
data/raw/     downloaded by script, not committed
data/clean/   produced by script, not committed
output/       figures and tables
```

## Data

NHANES is public: [CDC NHANES 2017–2018](https://wwwn.cdc.gov/nchs/nhanes/continuousnhanes/default.aspx?BeginYear=2017).
Data files are not committed; `R/01-download.R` fetches them.

## Team

| Member | Role |
|---|---|
| Merveilles | |
| | |
