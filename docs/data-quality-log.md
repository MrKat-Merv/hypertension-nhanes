# Data Quality Log

**Project:** Identifying Everyday Risk Factors for Hypertension
**Data:** CDC NHANES 2017–2018 (tables `DEMO_J`, `BPX_J`, `BMX_J`, `SMQ_J`, `PAQ_J`)
**Scripts covered:** `R/01-download.R`, `R/02-merge-clean.R`
**Date of checks:** 2026-10-31

This log records what is true about the data *before* any analysis. It
documents what we found, not how we interpreted it. Methodological
choices are in `docs/decisions.md`. The CDC's own definition of every
variable is in `docs/codebook/`.

---

## 1. Data acquisition

All five tables were downloaded directly from the CDC
(`wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/`) by
`R/01-download.R`. The matching CDC documentation page for each table was
saved to `docs/codebook/` (48–163 KB each, all real documentation pages,
not error pages). The download date is recorded in `data/raw/SOURCE.txt`.

| Table | Content | Rows | Columns |
|---|---|---:|---:|
| `DEMO_J` | Demographics (all ages) | 9,254 | 46 |
| `BPX_J` | Blood pressure exam | 8,704 | 21 |
| `BMX_J` | Body measures (incl. BMI) | 8,704 | 21 |
| `SMQ_J` | Smoking questionnaire | 6,724 | 37 |
| `PAQ_J` | Physical activity questionnaire | 5,856 | 17 |

The row counts differ because each component has its own eligibility
rules. `DEMO_J` covers everyone interviewed, including children. The exam
tables cover people who completed the examination. The two questionnaires
cover only the age groups they were asked of.

## 2. Merging

The five tables were joined on `SEQN` (the unique respondent ID) with
`inner_join()`, so a person is kept only if they appear in **all five**
tables.

- Starting point (`DEMO_J`): **9,254** people
- After all four joins: **5,533** people, **138** columns
- People lost to the merge: **3,721 of 9,254 (40.2%)**

`PAQ_J` (5,856 rows) and `SMQ_J` (6,724 rows) are the smallest tables, so
they set the ceiling on how many people can survive the merge. This is the
expected cost of `inner_join()`: everyone who remains has a record in
every table, but the sample is smaller than the original survey.

|step       |    n|
|:----------|----:|
|demo alone | 9254|
|+bpx       | 8704|
|+bmx       | 8704|
|+smq       | 6401|
|+paq       | 5533|

## 3. Restriction to adults

The analysis is restricted to respondents aged 18 and over (`RIDAGEYR >= 18`).
dim(nhanes_adults) = 5,533. 
Note: the five-table merge already
gives 5,533 rows, so the adult filter may remove few or no further people
(the smoking and activity questionnaires are only asked of adults). This is due
the fact that we used inner_join() so it filter even before we did.

## 4. Missing values

Counts of missing values (`NA`) in the variables the analysis depends on.
Percentages assume the 5,533 people above; adjust if `dim(nhanes_adults)`
differs.

| Variable | Meaning | Missing | % of people | Verdict |
|---|---|---:|---:|---|
| `BPXSY4` | 4th systolic BP reading | 5,079 | 91.8% | **Expected** |
| `SMD030` | Age started smoking regularly | 3,301 | 59.7% | **Expected** |
| `SMQ040` | Currently smokes? | 3,301 | 59.7% | **Expected** |
| `INDFMPIR` | Income-to-poverty ratio | 734 | 13.3% | **Needs a decision** |
| `BPXSY3` | 3rd systolic BP reading | 414 | 7.5% | Minor |
| `BPXSY2` | 2nd systolic BP reading | 405 | 7.3% | Minor |
| `BMXBMI` | Body mass index | 99 | 1.8% | Minor |
| `RIDAGEYR` | Age in years | 0 | 0% | Complete |
| `RIAGENDR` | Sex | 0 | 0% | Complete |
| `SMQ020` | Smoked 100+ cigarettes in life? | 0 | 0% | Complete |
| `PAQ650` | Vigorous recreational activity? | 0 | 0% | Complete |
| `PAQ665` | Moderate recreational activity? | 0 | 0% | Complete |
| `RIDRETH3` | Race/ethnicity | 0 | 0% | Complete |

**Expected missingness (explained by how the survey works):**
- `BPXSY4`: a fourth reading is only taken when earlier readings were
  incomplete, so most people have none. This is not a data problem.
- `SMQ040` and `SMD030`: both are skipped for people who answered "No" to
  `SMQ020` (never smoked 100+ cigarettes). They have identical counts
  (3,301), which is consistent with both following the same skip rule.
  See the skip patterns on the `SMQ_J` codebook page.

**Missingness that needs a decision:**
- `INDFMPIR` (13.3% missing) is the largest gap in a variable we need.
  These are people whose household income was not reported (refused,
  don't know, or not collected). We build `income_group` from this
  variable, so these people will have no income group. They cannot be
  used in the model unless we impute or drop them. See `docs/decisions.md`.

**Minor missingness:** `BPXSY2` and `BPXSY3` are each missing for about 7%
of people, and `BMXBMI` for under 2%. Most people missing one BP reading
still have others, and people with no usable reading at all are handled
when the hypertension outcome is built (Task 3).

**Complete variables:** age, sex, race/ethnicity, and the smoking and
activity screening questions have no missing values, so the merge did not
break any core field.

## 5. Duplicates

`sum(duplicated(nhanes_adults$SEQN))` returned **0**. Every respondent
appears exactly once, so the joins did not create repeated rows.

## 6. Plausibility checks

| Check | Rule | Rows failing |
|---|---|---:|
| Blood pressure | Diastolic ≥ systolic (2nd reading) | 0 |
| Age | Under 18 or over 110 | 0 |
| BMI | Under 10 or over 80 | **2** |

Blood pressure and age passed with zero violations. **Two people have a
BMI outside 10–80.**

I have inspected the two people failing the check of bmi using these commands
`bmi_outside_10_80 <- nhanes_adults %>% filter(BMXBMI < 10 | BMXBMI > 80) %>% select(SEQN, RIDAGEYR, BMXBMI)`
`knitr::kable(bmi_outside_10_80, format = "markdown")`
Anyway 2 out of 5,533 is negligible therefore can be left.

|   SEQN| RIDAGEYR| BMXBMI|
|------:|--------:|------:|
|  97938|       35|   86.2|
| 102778|       67|   84.4|

## 7. Summary

- Five tables acquired with their CDC documentation; 9,254 → 5,533
  respondents after merging (40.2% lost, all through the requirement to
  appear in every table).
- No duplicate respondents.
- Blood pressure and age values are plausible; two BMI values are outside
  the plausible range and are noted above.
- Most missingness is explained by survey design (4th BP reading,
  smoking skip pattern). The one gap that affects the analysis is income
  (`INDFMPIR`, 13.3% missing).
