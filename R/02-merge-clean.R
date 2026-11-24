# 1. Join the tables
# What SEQN is?: NHANES's respondent sequence number
# a unique ID present in every table, letting us 
# link "this person's blood pressure" 
# to "this same person's smoking history" even though
# they live in separate files.
# Why inner_join()?: it keeps a row only if that SEQN
# exists in both tables being joined.
# used 4 times to keep only people who completed all 5 components.

# NOTES: We deliberately decide to lose people who skipped
# even one questionnaire.
# To consider and keep everyone from the first table and fill NA
# for everyone missing from a later one, left_join() should be used.
# We considered this to be messier missingness to handle later.
# Expected output: since demo X bpx alone already dropped from 9,254 to 8,704 rows.
# We should expect nhanes_merged row count to land somewhere in the 5,500 - 8,500 range.
library(ggplot2)

nhanes_merged <- demo %>%
  inner_join(bpx, by = "SEQN") %>%
  inner_join(bmx, by = "SEQN") %>%
  inner_join(smq, by = "SEQN") %>%
  inner_join(paq, by = "SEQN")

dim(nhanes_merged)


# 2. Measure exactly how much each join step costs us
# What this table means?: each row shows how many people survive to that point.
# The drop between consecutive rows tells us which single
# questionnaire cost us the most people. View table screenshot in docs/data-quality-log.md
# The goal is to be able to make this statement:
# "The biggest lost happened at the X questionnaire"
# in our case:
# "The biggest lost happened at the smp(smoking) questionnaire"
# This could definitely help determine that there is a co-relation with how 
# society definitely look into smoking today, compare to the 80's and 90's.

n0 <- nrow(demo)
n1 <- nrow(demo %>% inner_join(bpx, by = "SEQN"))
n2 <- nrow(demo %>% inner_join(bpx, by = "SEQN") %>% inner_join(bmx, by = "SEQN"))
n3 <- nrow(demo %>% inner_join(bpx, by = "SEQN") %>% inner_join(bmx, by = "SEQN") %>% inner_join(smq, by = "SEQN"))
n4 <- nrow(nhanes_merged)

join_loss <- data.frame(step = c("demo alone", "+bpx", "+bmx", "+smq", "+paq"), n = c(n0,n1,n2,n3,n4))
join_loss

# 3. Restrict to adults
# What RIDAGEYR is?: age in years at screening.
# Why restrict here, right after merging?: NHANES surveys children too,
# and several later variables.
# Example: the way physical activity is asked for children or smoking or not asked at all.
# Filtering now means every downstream script only ever see adults.
# What to expect?: a considerate drop, and in our case: inner_join() filtered already the age 
# even though that was not our intention.
# during the inner_join() process, many children were dropped because they did not either take the 
# smoking questionnaire or the physical activity questionnaire.

nhanes_adults <- nhanes_merged %>% filter(RIDAGEYR >= 18)
dim(nhanes_adults)

# 4. Missing data, by column 
# What this does?: For each listed column, counts how many rows are NA.
# pivot_longer() reshapes the one-row-per-column summary into a tidy two-column table,
# much easier to read and sort than a wide row of numbers.
# What the numbers mean?: refer to BPX_J.htm for definitions of terms
# But we expect a likely high missingness of BPXSY4, likely zero or near-zero
# missingness for RIDAGEYR. a non-zero for RIDAGEYR will be a reason to check
# the merge again.
# The key distinction: missigness that makes logical sense versus
# missingness that's unexplained. 

key_cols <- c("RIDAGEYR", "RIAGENDR", "BMXBMI", "SMQ020", "SMD030", "SMQ040", "PAQ650", "PAQ665", "RIDRETH3", "INDFMPIR", "BPXSY2", "BPXSY3", "BPXSY4")

missingness <- nhanes_adults %>%
  select(all_of(key_cols)) %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  tidyr::pivot_longer(everything(), names_to = "variable", values_to = "n_missing") %>%
  dplyr::arrange(desc(n_missing))

missingness

# 5. Duplicate check
# What this means?: SEQN is defined as a unique ID
# If this returns anything above 0, the join logic has a bug
# (most likely a table with multiple rows per person)
# Should be fixed before any progress.

duplicate_count <- sum(duplicated(nhanes_adults$SEQN))
duplicate_count

# 6. Plausible checks
# What each check means?: These are not statistical tests
# They are common-sense rules a real value can't violate
# (diastolic should never be >= systolic in the same reading)
# (age and BMI should fall in the physically real ranges)
# Expected result for all three should be 0 or very close to it.
# A nonzero count is worth  inspecting individually before deciding whether
# to exclude those rows. It does not mean automatically the dataset is broken.

implausible_bp <- nhanes_adults %>% filter(BPXDI2 >= BPXSY2) %>% nrow()
implausible_age <- nhanes_adults %>% filter(RIDAGEYR < 18 | RIDAGEYR > 110) %>% nrow()
implausible_bmi <- nhanes_adults %>% filter(BMXBMI < 10 | BMXBMI > 80) %>% nrow()

c(implausible_bp = implausible_bp, implausible_age = implausible_age, implausible_bmi = implausible_bmi)

# create the folder.
# recursive = TRUE creates output/ too if it doesn't exist yet.

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

# Turn "step" into an ordered factor so the bars keep merge order
# (otherwise R sorts them alphabetically)
join_loss$step <- factor(join_loss$step, levels = join_loss$step)

p_join <- ggplot(join_loss, aes(x = step, y = n)) +
  geom_col(fill = "#2F8F7F") +
  geom_text(aes(label = n), vjust = -0.4) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(title = "People remaining after each merge step",
       x = NULL, y = "Number of people") +
  theme_minimal()

ggsave("output/figures/02-join-loss.png", p_join, width = 7, height = 4.5, dpi = 150)
p_join


missingness$pct <- missingness$n_missing / nrow(nhanes_adults) * 100

p_miss <- ggplot(missingness, aes(x = reorder(variable, pct), y = pct)) +
  geom_col(fill = "#E1A657") +
  coord_flip() +
  geom_text(aes(label = paste0(round(pct, 1), "%")), hjust = -0.1) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Missing values by variable",
       x = NULL, y = "Percent of people missing") +
  theme_minimal()

ggsave("output/figures/02-missingness.png", p_miss, width = 7, height = 5, dpi = 150)
p_miss


save_hist <- function(data, column, title, xlab, file, bins = 30) {
  p <- ggplot(data, aes(x = .data[[column]])) +
    geom_histogram(bins = bins, fill = "#13233A", colour = "white") +
    labs(title = title, x = xlab, y = "Number of people") +
    theme_minimal()
  ggsave(file.path("output", "figures", file), p, width = 7, height = 4.5, dpi = 150)
  p
}

save_hist(nhanes_adults, "RIDAGEYR", "Age of adults in the sample",
          "Age (years)", "02-hist-age.png")
save_hist(nhanes_adults, "BMXBMI", "Body mass index (BMI)",
          "BMI", "02-hist-bmi.png", bins = 40)
save_hist(nhanes_adults, "BPXSY2", "Systolic blood pressure, reading 2",
          "Systolic pressure (mmHg)", "02-hist-systolic.png")
save_hist(nhanes_adults, "BPXDI2", "Diastolic blood pressure, reading 2",
          "Diastolic pressure (mmHg)", "02-hist-diastolic.png")
save_hist(nhanes_adults, "INDFMPIR", "Income-to-poverty ratio",
          "Household income / poverty line", "02-hist-income.png")


p_bp <- ggplot(nhanes_adults, aes(x = BPXSY2, y = BPXDI2)) +
  geom_point(alpha = 0.25, colour = "#13233A") +
  geom_abline(slope = 1, intercept = 0, colour = "red", linetype = "dashed") +
  labs(title = "Diastolic vs systolic pressure (reading 2)",
       subtitle = "Every point should lie below the red line",
       x = "Systolic (mmHg)", y = "Diastolic (mmHg)") +
  theme_minimal()

ggsave("output/figures/02-scatter-bp.png", p_bp, width = 7, height = 5, dpi = 150)
p_bp

# Save the merged, adult-restricted dataset
# Why save here, before variable construction(Task3)?: This is a natural checkpoint
# merging and quality-checking is genuinely finished work, separate from the next
# decision(how to derive hypertension status, smoking categories etc,)
# Task 3 will start from this exact point.

saveRDS(nhanes_adults, "data/clean/nhanes_adults_merged.rds")

