# Decisions Log

**Project:** Identifying Everyday Risk Factors for Hypertension
**Data:** CDC NHANES 2017–2018
**Script covered:** `R/03-variables.R`
**Date:** 2026-11-04

This log records the choices made when turning the raw survey responses
into analysis variables, and why. `docs/data-quality-log.md` describes
what is true about the data; this file describes what we decided to do
with it. The CDC's definition of every variable is in `docs/codebook/`.

The sample at the start of this script is the 5,533 adults left after the
merge (see the data quality log). The final analysis sample is **5,218**.

---

## 1. Outcome: how "hypertension" is defined

**Decision:** a person is labelled **High** if their average systolic
blood pressure is 130 mmHg or higher, **or** their average diastolic
pressure is 80 mmHg or higher. Otherwise they are labelled **Low**.

**Why 130/80:** this is the threshold from the 2017 American College of
Cardiology / American Heart Association (ACC/AHA) guideline, the current
clinical standard. The older JNC7 guideline used 140/90. That is a real,
also defensible alternative, and using it would label fewer people High.
We did not use it.

**Why "or":** high blood pressure is diagnosed if either number is
elevated, so either one is enough.

**Averaging the readings:** each person has up to four readings of each
number. We average readings **2, 3 and 4** (`BPXSY2–4`, `BPXDI2–4`) and
skip reading 1. The first reading tends to run high because of a brief
nervous response to the procedure, and blood pressure research commonly
uses the later, calmer readings. Missing readings are ignored in the
average (`na.rm = TRUE`), so someone with only two readings is averaged
over those two.

**People with no usable reading:** 315 people had no valid reading at all
(5.7% of 5,533). R returns `NaN`, not `NA`, when it averages nothing, and
these people cannot be labelled, so they were removed. This leaves
**5,218** people, the final analysis sample.

**Result:**

| Label | People | Share |
|---|---:|---:|
| High | 2,328 | 44.6% |
| Low | 2,890 | 55.4% |

This is in line with the roughly 45% prevalence the CDC reports for U.S.
adults under the same definition, which is a useful check that the
pipeline is working.

**Limit of this definition:** it uses measured blood pressure only. It
does not take into account whether someone is on blood pressure
medication. A person whose pressure is controlled by medication is
labelled Low. Our outcome is therefore "elevated blood pressure at the
time of the exam," not "has a diagnosis of hypertension."

---

## 2. Smoking status

**Decision:** combine two questions into three groups.

| Group | Rule |
|---|---|
| Never | `SMQ020 == 2` (has not smoked 100 or more cigarettes in life) |
| Current | `SMQ020 == 1` and `SMQ040` is 1 or 2 (smokes every day or some days) |
| Former | `SMQ020 == 1` and `SMQ040 == 3` (smoked 100 or more, does not smoke now) |

**Why two questions:** neither question alone identifies a former smoker.
`SMQ040` is only asked of people who answered Yes to `SMQ020`, which is
why it is blank for never-smokers (see the data quality log).

**Result:**

| Group | People | Share |
|---|---:|---:|
| Never | 3,089 | 59.2% |
| Former | 1,208 | 23.2% |
| Current | 921 | 17.7% |
| Missing | 0 | 0% |

Every person fits one of the three groups.

---

## 3. Physical activity level

**Decision:** combine two yes/no questions about recreational activity
into three groups.

| Group | Rule |
|---|---|
| High | `PAQ650 == 1` (does vigorous recreational activity) |
| Moderate | `PAQ650 == 2` and `PAQ665 == 1` (no vigorous, but moderate) |
| Low | `PAQ650 == 2` and `PAQ665 == 2` (neither) |

**Trade-off:** NHANES has a much fuller activity questionnaire, including
work-related activity and minutes per week. We use only these two
recreational questions to get a simple three-level variable. Someone with
a physically demanding job but no recreational exercise is classified
Low. This is a deliberate simplification.

**Result:**

| Group | People | Share |
|---|---:|---:|
| Low | 2,738 | 52.5% |
| High | 1,296 | 24.8% |
| Moderate | 1,184 | 22.7% |
| Missing | 0 | 0% |

---

## 4. Race / ethnicity

**Decision:** use the CDC variable `RIDRETH3` ("Race/Hispanic origin w/
NH Asian"), and convert its codes into labels.

**Codebook check:** before writing the labels we looked the codes up with
`nhanesCodebook("DEMO_J", "RIDRETH3")` and in
`docs/codebook/DEMO_J.htm`. The CDC describes the variable as a "recode
of reported race and Hispanic origin information, with Non-Hispanic Asian
Category."

| Code | CDC description | Label used |
|---:|---|---|
| 1 | Mexican American | Mexican American |
| 2 | Other Hispanic | Other Hispanic |
| 3 | Non-Hispanic White | Non-Hispanic White |
| 4 | Non-Hispanic Black | Non-Hispanic Black |
| 6 | Non-Hispanic Asian | Non-Hispanic Asian |
| 7 | Other Race, including Multi-Racial | Other/Multi-Racial |

There is **no code 5** in this variable. The numbering skips from 4 to 6,
so the code values must be copied from the codebook, not guessed.

**Why `RIDRETH3` and not `RIDRETH1`:** `RIDRETH3` reports Non-Hispanic
Asian as its own group. The older variable folds it into "Other."

**Result:**

| Group | People | Share |
|---|---:|---:|
| Non-Hispanic White | 1,811 | 34.7% |
| Non-Hispanic Black | 1,214 | 23.3% |
| Non-Hispanic Asian | 740 | 14.2% |
| Mexican American | 700 | 13.4% |
| Other Hispanic | 477 | 9.1% |
| Other/Multi-Racial | 276 | 5.3% |
| Missing | 0 | 0% |

**Note:** these group sizes reflect how NHANES samples people, not the
U.S. population. NHANES deliberately oversamples some groups, and this
analysis is unweighted.

---

## 5. Income group

**Decision:** use the income-to-poverty ratio `INDFMPIR` (household
income divided by the official poverty line for that household size) and
cut it into four groups.

| Group | Rule |
|---|---|
| Below poverty line | `INDFMPIR < 1` |
| 1-2x poverty line | `1 ≤ INDFMPIR < 2` |
| 2-4x poverty line | `2 ≤ INDFMPIR < 4` |
| 4x+ poverty line | `INDFMPIR ≥ 4` |

A value of 1.0 means income exactly at the poverty line. NHANES caps the
variable at 5.0.

**Why this variable:** it measures economic position at the household
level, which is more meaningful than a country-level proxy.

**Result:**

| Group | People | Share |
|---|---:|---:|
| 1-2x poverty line | 1,274 | 24.4% |
| 2-4x poverty line | 1,238 | 23.7% |
| 4x+ poverty line | 1,165 | 22.3% |
| Below poverty line | 872 | 16.7% |
| **Missing** | **669** | **12.8%** |

**Missing income:** 669 people have no income-to-poverty ratio (they did
not report household income). They are kept in the dataset with a missing
income group. They will be left out of the predictive model, which needs
all of its variables, but they remain in analyses that do not use income.
Missing income is likely not random (people may decline to report income
for reasons related to their circumstances), so results by income group
describe only the people who reported income.

---

## 6. Age groups

**Decision:** cut age in years (`RIDAGEYR`) into five groups.

| Group | Ages |
|---|---|
| 18-29 | 18 up to but not including 30 |
| 30-44 | 30 up to but not including 45 |
| 45-59 | 45 up to but not including 60 |
| 60-74 | 60 up to but not including 75 |
| 75+ | 75 and older |

**Edge convention:** `cut(..., right = FALSE)` makes each group include
its lower edge and exclude its upper edge, so a 30-year-old is in "30-44",
not "18-29". A different convention would quietly move people between
groups, so it is written down here.

**Result:**

| Group | People | Share |
|---|---:|---:|
| 18-29 | 975 | 18.7% |
| 30-44 | 1,131 | 21.7% |
| 45-59 | 1,201 | 23.0% |
| 60-74 | 1,344 | 25.8% |
| 75+ | 567 | 10.9% |
| Missing | 0 | 0% |

---

## Summary of the final dataset

- **5,218 adults** with a usable blood pressure (from 5,533 after the
  merge; 315 removed for having no valid reading).
- **Outcome:** 44.6% High, 55.4% Low.
- **Complete variables:** smoking status, activity level, race/ethnicity
  and age group have no missing values.
- **Incomplete variable:** income group is missing for 669 people (12.8%).