# Goal: find out which factors carry a real, learnable relationship
# with hypertension, then test whether they translate into a working
# prediction that beats a no-information baseline.

library(ggplot2)
library(dplyr)
nhanes_adults <- readRDS("data/clean/nhanes_adults_clean.rds")        # Start by loading Task 3's checkpoint

# A reusable rate-by-group function
# What this does?: for a given column name (as text), groups the data by
# that column and computes, per group, the count and the percent labeled
# "High". Writing this once as a function. instead of retyping the same 
# group_by / summarise five times. means a fix or tweak only has to happen in one place.

# Why mean(hypertension == "High") computes a percentage:
# hypertension == "High" produces TRUE / FALSE. R treats TRUE as 1 and FALSE as 0 in arithmetic,
# so the mean of that column is exactly the proportion of TRUE's. multiplying by 100 turns it into a percentage.

rate_by <- function(data, group_col) {
  data %>%
    filter(!is.na(.data[[group_col]])) %>%
    group_by(across(all_of(group_col))) %>%
    summarise(n = n(), high_risk_pct = mean(hypertension == "High") * 100, .groups = "drop") %>%
    arrange(desc(high_risk_pct))
}

# Run it across every grouping.
# What the output means: Each table has one row per category, with n and high_risk_pct.
# The dataset's overall rate is ~44.6%, which is our reference point, also called Null Hypothesis.
# A category's rate close to 44.6% means that variable alone does not distinguish risk much; 
# a category noticeably above or below that baseline (several percentage points, not a fraction of one)
# is a real candidate "associated factor."

by_race <- rate_by(nhanes_adults, "race_ethnicity")
by_income <- rate_by(nhanes_adults, "income_group")
by_age <- rate_by(nhanes_adults, "age_group")
by_smoking <- rate_by(nhanes_adults, "smoking_status")
by_activity <- rate_by(nhanes_adults, "activity_level")

by_race; by_income; by_age; by_smoking; by_activity


# Correlation with the target
# What a correlation value means here?: ranges from -1 to 1.
# Near 0 means barely any linear relationship; further from 0 means stronger.
# avg_systolic / avg_diastolic will correlate very strongly (likely above 0.5).
correlations <- nhanes_adults %>%
  mutate(hypertension_bin = if_else(hypertension == "High", 1, 0)) %>%
  select(RIDAGEYR, BMXBMI, avg_systolic,avg_diastolic, hypertension_bin) %>%
  cor(use = "complete.obs") %>%
  as.data.frame() %>%
  tibble::rownames_to_column("variable") %>%
  select(variable, hypertension_bin) %>%
  filter(variable != "hypertension_bin") %>%
  arrange(desc(abs(hypertension_bin)))

correlations


# Prepare factor variables and split the data
# Why "factor(..., levels = c(...))" matters?: R's modelling functions treat a factor's first
# level as the reference category. Explicitly setting "levels=" guarantees "Never" smoker
# is always the baseline the model compares "Current" and "Former" against.
# Why split into train/test at all?: Evaluating a model on the same data
# it learned from measures memorization, not generalization.
# "set.seed(1) makes the "random" split reproducible.
# Why 70/30?: a common, reasonable default. Enough training data for several
# categorical predictors to estimate stable coefficients, while leaving a meaningfully sized test set.

model_data <- nhanes_adults %>%
  mutate(
    hypertension_bin = if_else(hypertension == "High", 1, 0),
    smoking_status = factor(smoking_status, levels = c("Never", "Former", "Current")),
    activity_level = factor(activity_level, levels = c("Low", "Moderate", "High")),
    race_ethnicity = factor(race_ethnicity),
    income_group = factor(income_group)
  ) %>%
  filter(!is.na(BMXBMI), !is.na(smoking_status), !is.na(activity_level),
         !is.na(race_ethnicity), !is.na(income_group))
set.seed(1)
train_idx <- sample(seq_len(nrow(model_data)), size = 0.7 * nrow(model_data))
train <- model_data[train_idx, ]
test <- model_data[-train_idx, ]

nrow(train); nrow(test)

# Compute the baseline
# What this is?: The accuracy from always predicting whichever class is more common.
# no model, no information used. Our value is close to 0.55 (matching the ~55% / 45% split from Task 3).

baseline_rate <- max(prop.table(table(train$hypertension_bin)))
baseline_rate

# Fit the logistic regression model
# Why logistic regression specifically?: The outcome is binary (High/Low),
# and logistic regression is the standard, interpretable model for that.
# unlike linear regression, it predicts a probability bounded 0-1,
# with coefficients that have a direct interpretation.
# it is also computationally simple and does not require turning.
# What family = binomial(link = "logit") means?: it tells glm() the 
# outcome is 0/1, modeled through the logistic (sigmoid) function,
# which turns an unbounded linear combination of predictors into a valid 0-1 probability.
# What to look for in summary(model): a coefficient table, one row per predictor.
# Estimate is on the log-odds scale.
# Pr(>|z|) is a p-value: conventionally, values below 0.05 are "statistically significant"
# RIDAGEYR(age) should come out strongly significant. It is one of the most robust
# well-established hypertension risk factors in the literature.

model <- glm(
  hypertension_bin ~ RIDAGEYR + BMXBMI + smoking_status + activity_level + race_ethnicity + income_group,
  data = train,
  family = binomial(link = "logit")
)

summary(model)


# Convert to odds ratios - the readable version
# What "exponentiate" does and why it matters?: raw coefficients are on the log-odds scale,
# not intuitive to read. Exponentiating converts each into an odds ratio.
# = 1 -> no effect
# > 1 -> associated with higher odds (e.g. OR of 2.0 for "Current smoker" means, holding other
# factors constant, current smokers have roughly double the odds of a "Never" smoker)
# < 1 -> associated with lower odds
# conf.int = TRUE adds a 95% confidence interval.
# if it includes 1, the effect is not statistically distinguishable from "no effect."
library(broom)
model_odds_ratios <- broom::tidy(model, exponentiate = TRUE, conf.int = TRUE)
model_odds_ratios

# Predict on the held-out test set, and evaluate.
# **What `type = "response"` does:** without it, `predict()` returns raw
# log-odds; `"response"` converts back to an actual 0–1 probability.
# Why threshold at 0.5:** the simplest, standard cutoff. A real design
# choice you could tune differently — worth mentioning in your report.
# How to read the confusion matrix:** rows are what your model predicted,
# columns are the real answer. The two off-diagonal cells are errors — a
# *false alarm* (predicted High, actually Low) and a *missed case*
#  (predicted Low, actually High). In a health-screening context, missed
# cases are usually the more costly error type, worth naming explicitly
# even though this project only optimizes for plain accuracy.
# What accuracy means and what to expect:** the proportion of correct
# test-set predictions. **The test that matters** is comparing this
# directly to `baseline_rate` from §4.5. Confirmed realistic range:
#  accuracy around **0.70–0.75** against a baseline near **0.55–0.71** — a
# modest, believable improvement, not a dramatic one. Below baseline means
# something's wrong (check for a coding error); suspiciously close to 1.0
# means suspect data leakage (e.g. accidentally including `avg_systolic` or
# `avg_diastolic` as a predictor, which would let the model "cheat" since
# those values are literally what built the outcome label).

test$pred_prob <- predict(model, newdata = test, type = "response")
test$pred_class <- if_else(test$pred_prob >= 0.5, 1, 0)

confusion_matrix <- table(Predicted = test$pred_class, Actual = test$hypertension_bin)
confusion_matrix

accuracy <- mean(test$pred_class == test$hypertension_bin)
accuracy


#dir.create("output", showWarnings = FALSE)

# Graph 1: hypertension rate by group (five charts, one function)

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

overall_rate <- mean(nhanes_adults$hypertension == "High") * 100

plot_rates <- function(rate_table, group_col, title, file, by_rate = TRUE) {
  rate_table$group <- as.character(rate_table[[group_col]])
  if (by_rate) {
    rate_table$group <- reorder(rate_table$group, rate_table$high_risk_pct)
  } else {
    rate_table$group <- factor(rate_table$group, levels = levels(rate_table[[group_col]]))
  }
  
  p <- ggplot(rate_table, aes(x = group, y = high_risk_pct)) +
    geom_col(fill = "#2F8F7F") +
    geom_hline(yintercept = overall_rate, linetype = "dashed", colour = "red") +
    geom_label(aes(label = paste0(sprintf("%.1f", high_risk_pct), "%  (n = ", n, ")")),
               hjust = -0.05, fill = "white", linewidth = 0) +
    coord_flip() +
    scale_y_continuous(expand = expansion(mult = c(0, 0.3))) +
    labs(title = title,
         subtitle = "Dashed line = overall rate (44.6%)",
         x = NULL, y = "Percent with high blood pressure") +
    theme_minimal()
  
  ggsave(file.path("output", "figures", file), p, width = 7.5, height = 4.5, dpi = 150)
  p
}

plot_rates(by_race, "race_ethnicity", "High blood pressure by race/ethnicity", "04-rate-race.png")
plot_rates(by_income, "income_group", "High blood pressure by income group", "04-rate-income.png")
plot_rates(by_age, "age_group", "High blood pressure by age group", "04-rate-age.png", by_rate = FALSE)
plot_rates(by_smoking, "smoking_status", "High blood pressure by smoking status", "04-rate-smoking.png")
plot_rates(by_activity, "activity_level", "High blood pressure by activity level", "04-rate-activity.png")

# Graph 2: odds ratios with confidence intervals

or_data <- model_odds_ratios %>% filter(term != "(Intercept)")

p_or <- ggplot(or_data, aes(x = estimate, y = reorder(term, estimate))) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "red") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high), colour = "#13233A") +
  scale_x_log10() +
  labs(title = "Odds ratios from the logistic regression",
       subtitle = "If a line crosses 1, the effect is not statistically distinguishable from no effect",
       x = "Odds ratio (log scale; 1 = no effect)", y = NULL) +
  theme_minimal()

ggsave("output/figures/04-odds-ratios.png", p_or, width = 8, height = 5.5, dpi = 150)
p_or

# Graph 3: confusion matrix

cm_df <- as.data.frame(confusion_matrix)

p_cm <- ggplot(cm_df, aes(x = Actual, y = Predicted, fill = Freq)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = Freq), size = 8) +
  scale_fill_gradient(low = "#F7F8FA", high = "#2F8F7F") +
  scale_x_discrete(labels = c("0" = "Actually Low", "1" = "Actually High")) +
  scale_y_discrete(limits = rev, labels = c("0" = "Predicted Low", "1" = "Predicted High")) +
  labs(title = "Predictions vs reality on the test set", x = NULL, y = NULL) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("output/figures/04-confusion-matrix.png", p_cm, width = 6, height = 4.5, dpi = 150)
p_cm

# Graph 4: predicted probability for each true group

test$actual_label <- if_else(test$hypertension_bin == 1, "Actually High", "Actually Low")

p_prob <- ggplot(test, aes(x = pred_prob, fill = actual_label)) +
  geom_histogram(bins = 30, colour = "white", show.legend = FALSE) +
  geom_vline(xintercept = 0.5, linetype = "dashed") +
  facet_wrap(~ actual_label, ncol = 1) +
  scale_fill_manual(values = c("Actually High" = "#E1A657", "Actually Low" = "#2F8F7F")) +
  labs(title = "Predicted probability of high blood pressure",
       subtitle = "Dashed line = the 0.5 cutoff. The more the two groups overlap, the harder they are to separate.",
       x = "Predicted probability", y = "Number of people") +
  theme_minimal()

ggsave("output/figures/04-predicted-probability.png", p_prob, width = 7, height = 6, dpi = 150)
p_prob

# Export results to `output/`

dir.create("output", showWarnings = FALSE)

# Segmented rates and model performance -> JSON, for the report and the React app
jsonlite::write_json(
  list(
    by_race   = by_race,
    by_income = by_income,
    by_age    = by_age,
    n_total   = nrow(nhanes_adults),
    model_accuracy    = accuracy,
    baseline_accuracy = baseline_rate
  ),
  "output/segmented_results.json",
  auto_unbox = TRUE, pretty = TRUE
)

# Model coefficients -> JSON, the bridge to the React app (Tutorial 2)
coefs <- coef(model)
coef_list <- as.list(coefs)
names(coef_list) <- names(coefs)
jsonlite::write_json(coef_list, "output/model_coefficients.json", auto_unbox = TRUE, pretty = TRUE)

# Readable tables, for anyone browsing the repo without R
write.csv(model_odds_ratios, "output/model_odds_ratios.csv", row.names = FALSE)
write.csv(as.data.frame(confusion_matrix), "output/confusion_matrix.csv", row.names = FALSE)

