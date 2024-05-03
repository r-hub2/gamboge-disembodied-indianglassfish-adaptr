## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.align = "center",
  fig.width = 6
)

## -----------------------------------------------------------------------------
library(adaptr)

setup_cluster(2)

## -----------------------------------------------------------------------------
binom_trial <- setup_trial_binom(
  arms = c("Arm A", "Arm B", "Arm C"),
  true_ys = c(0.25, 0.25, 0.25),
  min_probs = rep(0.20, 3),
  data_looks = seq(from = 300, to = 2000, by = 100),
  randomised_at_looks = c(seq(from = 400, to = 2000, by = 100), 2000),
  equivalence_prob = 0.9,
  equivalence_diff = 0.05,
  soften_power = 0.5
)

print(binom_trial, prob_digits = 3)

## -----------------------------------------------------------------------------
print(binom_trial, prob_digits = 2)

## -----------------------------------------------------------------------------
# Calibrate the trial specification
calibrated_binom_trial <- calibrate_trial(
  trial_spec = binom_trial,
  n_rep = 1000, # 1000 simulations for each step (more generally recommended)
  base_seed = 4131, # Base random seed (for reproducible results)
  target = 0.05, # Target value for calibrated metric (default value)
  search_range = c(0.9, 1), # Search range for superiority stopping threshold
  tol = 0.01, # Tolerance range
  dir = -1 # Tolerance range only applies below target
)

# Print result (to check if calibration is successful)
calibrated_binom_trial

## -----------------------------------------------------------------------------
# Calculate performance metrics with uncertainty measures
binom_trial_performance <- check_performance(
  calibrated_binom_trial$best_sims,
  select_strategy = "best",
  uncertainty = TRUE, # Calculate uncertainty measures
  n_boot = 1000, # 1000 bootstrap samples (more typically recommended)
  ci_width = 0.95, # 95% confidence intervals (default)
  boot_seed = "base" # Use same random seed for bootstrapping as for simulations
)

# Print results 
print(binom_trial_performance, digits = 2)

## -----------------------------------------------------------------------------
binom_trial_summary <- summary(
  calibrated_binom_trial$best_sims,
  select_strategy = "best"
)

print(binom_trial_summary, digits = 2)

## -----------------------------------------------------------------------------
binom_trial_results <- extract_results(
  calibrated_binom_trial$best_sims,
  select_strategy = "best"
)

nrow(binom_trial_results) # Number of rows/simulations

head(binom_trial_results) # Print the first rows

## -----------------------------------------------------------------------------
check_remaining_arms(
  calibrated_binom_trial$best_sims,
  ci_width = 0.95 # 95% confidence intervals (default)
)

## -----------------------------------------------------------------------------
plot_convergence(
  calibrated_binom_trial$best_sims,
  metrics = c("size mean", "prob_superior", "prob_equivalence"),
  # select_strategy can be specified, but does not affect the chosen metrics
)

## -----------------------------------------------------------------------------
plot_convergence(
  calibrated_binom_trial$best_sims,
  metrics = c("size mean", "prob_superior", "prob_equivalence"),
  n_split = 4
)

## -----------------------------------------------------------------------------
plot_status(
  calibrated_binom_trial$best_sims,
  x_value = "total n" # Total number of randomised patients at X-axis
)

## -----------------------------------------------------------------------------
plot_status(
  calibrated_binom_trial$best_sims,
  x_value = "total n",
  arm = NA # NA for all arms or character vector for specific arms
)

## -----------------------------------------------------------------------------
binom_trial_calib_diff <- setup_trial_binom(
  arms = c("Arm A", "Arm B", "Arm C"),
  true_ys = c(0.25, 0.20, 0.30), # Different outcomes in the arms
  min_probs = rep(0.20, 3),
  data_looks = seq(from = 300, to = 2000, by = 100),
  randomised_at_looks = c(seq(from = 400, to = 2000, by = 100), 2000),
  # Stopping rules for inferiority/superiority explicitly defined
  # using the calibration results
  inferiority = 1 - calibrated_binom_trial$best_x,
  superiority = calibrated_binom_trial$best_x,
  equivalence_prob = 0.9,
  equivalence_diff = 0.05,
  soften_power = 0.5
)

## -----------------------------------------------------------------------------
binom_trial_diff_sims <- run_trials(
  binom_trial_calib_diff,
  n_rep = 1000, # 1000 simulations (more generally recommended)
  base_seed = 1234, # Reproducible results
  sparse = FALSE # Return additional results for visualisation
)

## -----------------------------------------------------------------------------
check_performance(
  binom_trial_diff_sims,
  select_strategy = "best",
  uncertainty = TRUE,
  n_boot = 1000, # 1000 bootstrap samples (more typically recommended)
  ci_width = 0.95,
  boot_seed = "base"
)

## -----------------------------------------------------------------------------
plot_status(binom_trial_diff_sims, x_value = "total n")

## -----------------------------------------------------------------------------
plot_status(binom_trial_diff_sims, x_value = "total n", arm = NA)

## -----------------------------------------------------------------------------
plot_history(
  binom_trial_diff_sims,
  x_value = "total n",
  y_value = "prob"
)

## -----------------------------------------------------------------------------
plot_history(
  binom_trial_diff_sims,
  x_value = "total n",
  y_value = "n all"
)

## -----------------------------------------------------------------------------
citation(package = "adaptr")

