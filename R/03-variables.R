# Task 3 -- `R/03-variables.R`: Variable Construction
# Goal: We want to turn the NHANES's coded survey responses into the analysis-ready
# variables the project needs: the hypertension outcome, smoking status, activity level
# race/ethnicity, income group and age group.


# We are loading the checkpoint from Task 2
# We are re-loading from disk to make each script independent
# and re-runnable on its own.
# To make (source("R/03-variables.R) Able to work on a fresh R session as long as 
# data/clean/nhanes_adults_merged.rds already exists)
# We have considered for average the readings 2-4, skipping reading 1
# This is a real clinical convention, first reading tend to run slightly high.
# We have chosen 130/80 since that is the 2017 ACC/AHA guideline.
# Output meaning: anyone with zero valid readings gets NaN from the `mean(...,na.rm=TRUE)`
# not NA. 
# Reminder in R: NA has a different meaning, it is not "missing"
library(dplyr)
nhanes_adults <- readRDS("data/clean/nhanes_adults_merged.rds")

# 1. Average blood pressure and the hypertension label

nhanes_adults <- nhanes_adults %>%
  rowwise() %>%
  mutate(
    avg_systolic = mean(c(BPXSY2, BPXSY3, BPXSY4), na.rm = TRUE),
    avg_diastolic = mean(c(BPXDI2, BPXDI3, BPXDI4), na.rm = TRUE)
  ) %>%
  ungroup() %>%
  mutate(hypertension = if_else(avg_systolic >= 130 | avg_diastolic >= 80, "High", "Low"))

# Let us print but we will comment the next printing lines
# Because not useful or necessary. Just a temporary reading.

nan_count <- sum(is.nan(nhanes_adults$avg_systolic))
nan_count   # 315 people have no valid reading at all.
# and get dropped, leaving 5,218 adults with usable blood pressure value.
# 5,218 is our final analytic sample.
nhanes_adults <- nhanes_adults %>% filter(!is.nan(avg_systolic))

# We are expecting 2,328 High / 2,890 Low
# roughly a 44-45% High split, consistent with published CDC figures for 
# this exact survey cycle (about 45%).
table(nhanes_adults$hypertension)

# 2. Smoking status
# Why this specific logic:`SMQ020` asks "have you smoked 100+
# cigarettes in your life" (1=Yes, 2=No). `SMQ040` (only asked if
# `SMQ020==1`) asks "do you smoke now" (1=Every day, 2=Some days, 3=Not at
# all). Combining them is necessary because neither question alone captures
# "Former" smoker.

nhanes_adults <- nhanes_adults %>%
  mutate(smoking_status = case_when(
    SMQ020 == 2 ~ "Never",
    SMQ020 == 1 & SMQ040 %in% c(1, 2) ~ "Current",
    SMQ020 == 1 & SMQ040 == 3 ~ "Former",
    TRUE ~ NA_character_
  ))

table(nhanes_adults$smoking_status, useNA = "always")


# 3. Physical activity level
# PAQ650` asks about *vigorous* recreational activity
# (Yes/No), `PAQ665` about *moderate* activity (Yes/No) — collapsed into one
# 3-level category. This is a simplification of NHANES's fuller activity
# questionnaire

nhanes_adults <- nhanes_adults %>%
  mutate(activity_level = case_when(
    PAQ650 == 1 ~ "High",
    PAQ650 == 2 & PAQ665 == 1 ~ "Moderate",
    PAQ650 == 2 & PAQ665 == 2 ~ "Low",
    TRUE ~ NA_character_
  ))

table(nhanes_adults$activity_level, useNA = "always")

# 4. Race/ethnicity - with the codebook checked first
# if you get `fatal error: curl/curl.h: No such file or directory`
# Or similar depending on your OS.
# That is not an R mistake or problem.
# My solution is for Ubuntu:
# `sudo apt update
# `sudo apt install libcurl4-openssl-dev libssl-dev libxml2-dev`
# Then
# install.packages("nhanesA")

library(nhanesA)
nhanesCodebook("DEMO_J", "RIDRETH3")

nhanes_adults <- nhanes_adults %>%
  mutate(race_ethnicity = case_when(
    RIDRETH3 == 1 ~ "Mexican American",
    RIDRETH3 == 2 ~ "Other Hispanic",
    RIDRETH3 == 3 ~ "Non-Hispanic White",
    RIDRETH3 == 4 ~ "Non-Hispanic Black",
    RIDRETH3 == 6 ~ "Non-Hispanic Asian",
    RIDRETH3 == 7 ~ "Other/Multi-Racial",
    TRUE ~ NA_character_
  ))

table(nhanes_adults$race_ethnicity, useNA = "always")

# 5. Income group and age groups
# What INDFMPIR is?: a household's income divided by the official
# poverty line for its size and year.
# 1.0 means exactly at the poverty line, values capped at 5.0.
# A genuinely individual/ household-level economic measure.

nhanes_adults <- nhanes_adults %>%
  mutate(income_group = case_when(
    INDFMPIR < 1 ~ "Below poverty line",
    INDFMPIR < 2 ~ "1-2x poverty line",
    INDFMPIR < 4 ~ "2-4x poverty line",
    INDFMPIR >= 4 ~ "4x+ poverty line",
    TRUE ~ NA_character_
  ))

table(nhanes_adults$income_group, useNA = "always")

nhanes_adults <- nhanes_adults %>%
  mutate(age_group = cut(RIDAGEYR,
    breaks = c(18, 30, 45, 60, 75, Inf),
    labels = c("18-29", "30-44", "45-59", "60-74", "75+"),
    right = FALSE))

table(nhanes_adults$age_group, useNA = "always")
