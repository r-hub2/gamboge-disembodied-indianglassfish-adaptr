test_that("Trial with normally distributed outcome is set up correctly", {
  norm_trial <- setup_trial_norm(
    arms = c("Control", "New A", "New B", "New C"),
    true_ys = c(15, 20, 14, 13),
    sds = c(2, 2.5, 1.9, 1.8),
    max_n = 500,
    look_after_every = 50,
    control = "Control",
    control_prob_fixed = "sqrt-based fixed",
    highest_is_best = TRUE,
    soften_power = 0.5
  )

  expect_snapshot(norm_trial)
})


test_that("Trial with binomially distributed outcome is set up correctly", {
  setup <- setup_trial_binom(
    arms = c("Arm A", "Arm B", "Arm C"),
    true_ys = c(0.25, 0.20, 0.30),
    min_probs = rep(0.15, 3),
    data_looks = seq(from = 300, to = 2000, by = 100),
    equivalence_prob = 0.9,
    equivalence_diff = 0.05,
    soften_power = 0.5
  )
  expect_snapshot(setup)

  setup <- setup_trial_binom(
    arms = c("Arm A", "Arm B", "Arm C"),
    true_ys = c(0.25, 0.20, 0.30),
    fixed_probs = c(0.2, NA, NA),
    start_probs = c(0.2, 0.4, 0.4),
    min_probs = c(NA, 0.2, 0.2),
    data_looks = seq(from = 300, to = 2000, by = 100),
    equivalence_prob = 0.9,
    equivalence_diff = 0.05,
    soften_power = 0.5
  )
  expect_snapshot(setup)

  expect_error(
    setup_trial_binom(
      arms = c("Arm A", "Arm B", "Arm C"),
      true_ys = c(0.25, 0.20, 0.30),
      fixed_probs = c(0.15, NA, NA),
      min_probs = rep(0.15, 3),
      data_looks = seq(from = 300, to = 2000, by = 100),
      equivalence_prob = 0.9,
      equivalence_diff = 0.05,
      soften_power = 0.5
    )
  )
})

test_that("Custom trial with log-normally distributed outcome is set up correctly", {
  get_ys_lognorm <- function(allocs) {
    y <- numeric(length(allocs))
    means <- c("Control" = 2.2, "Experimental A" = 2.1, "Experimental B" = 2.3)
    for (arm in names(means)) {
      ii <- which(allocs == arm)
      y[ii] <- rlnorm(length(ii), means[arm], 1.5)
    }
    y
  }

  get_draws_lognorm <- function(arms, allocs, ys, control, n_draws) {
    draws <- list()
    logys <- log(ys)
    for (arm in arms){
      ii <- which(allocs == arm)
      n <- length(ii)
      if (n > 1) {
        draws[[arm]] <- exp(rnorm(n_draws, mean = mean(logys[ii]), sd = sd(logys[ii])/sqrt(n - 1)))
      } else {
        draws[[arm]] <- exp(rnorm(n_draws, mean = mean(logys), sd = 1000 * (max(logys) - min(logys))))
      }
    }
    do.call(cbind, draws)
  }

  lognorm_trial <- setup_trial(
    arms = c("Control", "Experimental A", "Experimental B"),
    true_ys = exp(c(2.2, 2.1, 2.3)),
    fun_y_gen = get_ys_lognorm,
    fun_draws = get_draws_lognorm,
    max_n = 5000,
    look_after_every = 200,
    control = "Control",
    control_prob_fixed = "sqrt-based",
    equivalence_prob = 0.9,
    equivalence_diff = 0.5,
    equivalence_only_first = TRUE,
    highest_is_best = FALSE,
    fun_raw_est = function(x) exp(mean(log(x))) ,
    robust = TRUE,
    description = "continuous, log-normally distributed outcome",
    add_info = "SD on the log scale for all arms: 1.5"
  )

  expect_snapshot(lognorm_trial)
})

test_that("validate setup trial specifications", {
  via_validate <- validate_trial(
    arms = c("A", "B", "C"),
    control = "B",
    true_ys = c(0.25, 0.20, 0.30),
    fun_y_gen = adaptr:::get_ys_binom(c("A", "B", "C"), c(0.25, 0.20, 0.30)),
    fun_draws = adaptr:::get_draws_binom,
    fun_raw_est = mean,
    min_probs = rep(0.15, 3),
    data_looks = seq(from = 300, to = 2000, by = 100),
    equivalence_prob = 0.9,
    equivalence_diff = 0.05,
    equivalence_only_first = FALSE,
    futility_prob = 0.95,
    futility_diff = 0.05,
    futility_only_first = FALSE,
    soften_power = 0.5,
    highest_is_best = TRUE,
    description = "test",
    robust = TRUE
  )

  via_setup <- setup_trial_binom(
    arms = c("A", "B", "C"),
    control = "B",
    true_ys = c(0.25, 0.20, 0.30),
    min_probs = rep(0.15, 3),
    data_looks = seq(from = 300, to = 2000, by = 100),
    equivalence_prob = 0.9,
    equivalence_diff = 0.05,
    equivalence_only_first = FALSE,
    futility_prob = 0.95,
    futility_diff = 0.05,
    futility_only_first = FALSE,
    soften_power = 0.5,
    highest_is_best = TRUE,
    description = "test",
    robust = TRUE
  )

  # Process functions for comparison (ignoring environment, bytecode, etc.)
  for (s in c("via_validate", "via_setup")) {
    temp_s <- get(s)
    for (f in c("fun_y_gen", "fun_draws", "fun_raw_est"))
      temp_s[[f]] <- deparse(temp_s[[f]])
    assign(s, temp_s)
  }

  expect_equal(via_validate, via_setup)
})


test_that("setup/validate_trial functions errors on invalid inputs", {
  expect_error(validate_trial(arms = NULL))
  expect_error(validate_trial(arms = c("A", "A", "B")))
  expect_error(validate_trial(arms = "A"))
  expect_error(validate_trial(arms = c(1, 2, 3), control = 1))
  expect_error(validate_trial(arms = c("A", "B", "C"), control_prob_fixed = 0.4,
                              data_looks = 1:5 * 100))
  expect_error(validate_trial(arms = c("A", "B", "C"), control = "A",
                              control_prob_fixed = "sqrt-based", start_probs = rep(1/3, 3)))
  expect_error(validate_trial(arms = c("A", "B", "C"), control = "A", control_prob_fixed = "sqrt-based fixed",
                              fixed_probs = rep(1/3, 3)))
  expect_error(validate_trial(arms = c("A", "B", "C"), control = "A", control_prob_fixed = "sqrt-based start",
                              fixed_probs = rep(1/3, 3)))
  expect_error(validate_trial(arms = c("A", "B", "C"), control = "A", control_prob_fixed = "match",
                              start_probs = c(0.3, 0.3, 0.4)))
  expect_error(validate_trial(arms = c("A", "B", "C"), control = "A", control_prob_fixed = "match",
                              fixed_probs = c(1/3, NA, NA), data_looks = 1:5 * 100))

  expect_error(validate_trial(arms = c("A", "B", "C"), start_probs = rep(0.25, 4)))
  expect_error(validate_trial(arms = 1:3, start_probs = rep(0.32, 3)))
  expect_error(validate_trial(arms = 1:3, min_probs = rep(-0.01, 3)))
  expect_error(validate_trial(arms = 1:3, start_probs = c(NA, 0.5, 0.5)))
  expect_error(validate_trial(arms = 1:3, start_probs = c(0.2, 0.3, 0.5), min_probs = c(0.3, NA, NA)))
  expect_error(validate_trial(arms = 1:3, start_probs = c(0.2, 0.3, 0.5), max_probs = c(NA, NA, 0.4)))
  expect_error(validate_trial(arms = 1:3, start_probs = c(0.2, 0.3, 0.5), fixed_probs = c(0.2, NA, NA),
                              min_probs = c(0.1, NA, NA)))
  expect_error(validate_trial(arms = 1:3, start_probs = c(0.5, 0.25, 0.25), min_probs = c(0.5, 0.1, 0.1),
                              max_probs = c(0.5, NA, NA)))

  expect_error(validate_trial(arms = 1:3, rescale_probs = "invalid"))
  expect_error(validate_trial(arms = 1:3, rescale_probs = c("fixed", "both")))
  expect_error(validate_trial(arms = 1:2, rescale_probs = "both"))
  expect_error(validate_trial(arms = 1:3, control = 1, control_prob_fixed = "sqrt-based fixed",
                              rescale_probs = "fixed", data_looks = 1:5 * 100))
  expect_error(validate_trial(arms = 1:3, rescale_probs = "fixed"))
  expect_error(validate_trial(arms = 1:3, control = 1, control_prob_fixed = "sqrt-based",
                              rescale_probs = "fixed"))
  expect_error(validate_trial(arms = 1:3, rescale_probs = "limits"))

  expect_error(validate_trial(arms = 1:3, data_looks = c(100, 100, 200)))
  expect_error(validate_trial(arms = 1:3, data_looks = c(100, 200, 300), look_after_every = 100, max_n = 300))
  expect_error(validate_trial(arms = 1:3))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, randomised_at_looks = c(200, 199, 300)))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, randomised_at_looks = 1:3 * 99))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, randomised_at_looks = 1:3 * 100 + 2.5))

  expect_error(validate_trial(arms = c("A", "B", "C"), control = "D", data_looks = 1:3 * 100))
  expect_error(validate_trial(arms = c("A", "B", "C"), control = "A", data_looks = 1:3 * 100,
                              control_prob_fixed = c(0.3, 0.2, 0.1)))

  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, inferiority = -0.01))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, inferiority = 0.01 * 1:2))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, superiority = 1.01))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, inferiority = 1 - 0.01 * 1:2))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, inferiority = 0.99, superiority = 0.95))

  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, highest_is_best = 0))

  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, equivalence_prob = 0.9))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, equivalence_prob = 1 - 0.01 * 1:2,
                              equivalence_diff = 0.1))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, equivalence_prob = 1 - 0.01 * 1:3,
                              equivalence_diff = -0.1))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, equivalence_only_first = TRUE))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, equivalence_prob = 0.9,
                              equivalence_diff = 0.1, equivalence_only_first = TRUE))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, control = 1,
                              equivalence_prob = 0.9, equivalence_diff = 0.1))

  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, futility_prob = 0.9))
  expect_error(validate_trial(arms = 1:3, control = 1, data_looks = 1:3 * 100, futility_prob = 0.9))
  expect_error(validate_trial(arms = 1:3, control = 1, data_looks = 1:3 * 100,
                              futility_prob = 1 - 0.01 * 1:2, futility_diff = 0.1, futility_only_first = TRUE))
  expect_error(validate_trial(arms = 1:3, control = 1, data_looks = 1:3 * 100,
                              futility_prob = 0.9, futility_diff = 0.1 * 1:3, futility_only_first = TRUE))
  expect_error(validate_trial(arms = 1:3, control = 1, data_looks = 1:3 * 100,
                              futility_prob = 0.9, futility_diff = 0.1, futility_only_first = NA))

  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, soften_power = 1 - 0.01 * 1:2))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, soften_power = 1.01))

  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 0.1 * 1:3,
                              cri_width = c(1.01, 0.9)))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3, n_draws = 10))
  expect_warning(setup_trial_binom(arms = 1:3, data_looks = 1:3 * 100, true_ys = 0.1 * 1:3, n_draws = 500))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3, robust = NA))

  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3,
                              fun_y_gen = function(...) 1))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                              fun_y_gen = get_ys_binom(1:3, 1:3 * 0.1), fun_draws = "invalid fun"))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                              fun_y_gen = get_ys_binom(1:3, 1:3 * 0.1), fun_draws = function(...) 1))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1, fun_y_gen = "invalid fun"))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                              fun_y_gen = get_ys_binom(1:3, 1:3 * 0.1), fun_draws = get_draws_binom,
                              fun_raw_est = function(...) NA))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                              fun_y_gen = get_ys_binom(1:3, 1:3 * 0.1), fun_draws = get_draws_binom,
                              fun_raw_est = "invalid fun"))
  expect_error(setup_trial_binom(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                                 description = TRUE))
  expect_error(validate_trial(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                              fun_y_gen = get_ys_binom(1:3, 1:3 * 0.1), fun_draws = get_draws_binom,
                              fun_raw_est = mean, add_info = c("some", "info")))

  expect_error(setup_trial_binom(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3))
  expect_error(setup_trial_binom(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                                 equivalence_prob = 0.9, equivalence_diff = 2))
  expect_error(setup_trial_binom(arms = 1:3, control = 1, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1,
                                 futility_prob = 0.9, futility_diff = 2, futility_only_first = TRUE))

  expect_error(setup_trial_norm(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3, sds = -1))
  expect_error(setup_trial_norm(arms = 1:3, data_looks = 1:3 * 100))

  expect_error(setup_trial_binom(arms = 1:3, max_n = 28.9, look_after_every = 1.23, true_ys = 1:3 * 0.1))
  expect_error(setup_trial_binom(arms = 1:3, true_ys = 1:3 * 0.1, data_looks = 100 / 3 * 1:3))

  expect_error(setup_trial_binom(arms = 1:3, data_looks = 1:3 * 100, true_ys = 1:3 * 0.1, inferiority = 0.35))

  expect_error(setup_trial(arms = 1:3, true_ys = 1:3, data_looks = 1:3 * 100,
                           fun_y_gen = function(x) rnorm(length(x)),
                           fun_draws = function(...) matrix(1:9, ncol = 3)))
})
