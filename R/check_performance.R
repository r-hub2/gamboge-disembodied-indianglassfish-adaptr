#' Calculate the ideal design percentage
#'
#' Used internally by [check_performance()], calculates the ideal design
#' percentage as described in that function's documentation.
#'
#' @inheritParams setup_trial
#' @param sels a character vector specifying the selected arms (according to the
#'   selection strategies described in [extract_results()]).
#'
#' @return A single numeric value between `0` and `100` corresponding to the
#'   ideal design percentage.
#'
#' @keywords internal
#'
calculate_idp <- function(sels, arms, true_ys, highest_is_best) {
  sels_ns <- vapply_num(seq_along(arms), function(a) sum(sels == arms[a], na.rm = TRUE))
  exp_ys <- sum((sels_ns / sum(sels_ns)) * true_ys)
  idp <- 100 * (exp_ys - min(true_ys)) / (max(true_ys) - min(true_ys))
  if (highest_is_best) idp else 100 - idp
}


#' Check performance metrics for trial simulations
#'
#' Calculates performance metrics for a trial specification based on
#' simulation results from the [run_trials()] function, with bootstrapped
#' uncertainty measures if requested. Uses [extract_results()], which may be
#' used directly to extract key trial results without summarising. This function
#' is also used by [summary()] to calculate the performance metrics presented by
#' that function.
#'
#' @inheritParams extract_results
#' @param restrict single character string or `NULL`. If `NULL` (default),
#'   results are summarised for all simulations; if `"superior"`, results are
#'   summarised for simulations ending with superiority only; if `"selected"`,
#'   results are summarised for simulations ending with a selected arm only
#'   (according to the specified arm selection strategy for simulations not
#'   ending with superiority). Some summary measures (e.g., `prob_conclusive`)
#'   have substantially different interpretations if restricted, but are
#'   calculated nonetheless.
#' @param uncertainty single logical; if `FALSE` (default) uncertainty measures
#'   are not calculated, if `TRUE`, non-parametric bootstrapping is used to
#'   calculate uncertainty measures.
#' @param n_boot single integer (default `5000`); the number of bootstrap
#'   samples to use if `uncertainty = TRUE`. Values `< 100` are not allowed and
#'   values `< 1000` will lead to a warning, as results are likely to be
#'   unstable in those cases.
#' @param ci_width single numeric `>= 0` and `< 1`, the width of the
#'   percentile-based bootstrapped confidence intervals. Defaults to `0.95`,
#'   corresponding to 95% confidence intervals.
#' @param boot_seed single integer, `NULL` (default), or `"base"`. If a value is
#'   provided, this value will be used to initiate random seeds when
#'   bootstrapping with the global random seed restored after the function has
#'   run. If `"base"` is specified, the `base_seed` specified in [run_trials()]
#'   is used. Regardless of whether simulations are run sequentially or in
#'   parallel, bootstrapped results will be identical if a `boot_seed` is
#'   specified.
#'
#' @return A tidy `data.frame` with added class `trial_performance` (to control
#'   the number of digits printed, see [print()]), with the columns
#'   `"metric"` (described below), `"est"` (estimate of each metric), and the
#'   following four columns if `uncertainty = TRUE`: `"err_sd"`(bootstrapped
#'   SDs), `"err_mad"` (bootstrapped MAD-SDs, as described in [setup_trial()]
#'   and [stats::mad()]), `"lo_ci"`, and `"hi_ci"`, the latter two corresponding
#'   to the lower/upper limits of the percentile-based bootstrapped confidence
#'   intervals. Bootstrap estimates are **not** calculated for the minimum
#'   (`_p0`) and maximum values (`_p100`) of `size`, `sum_ys`, and `ratio_ys`,
#'   as non-parametric bootstrapping for minimum/maximum values is not
#'   sensible - bootstrap estimates for these values will be `NA`.\cr
#'   The following performance metrics are calculated:
#' \itemize{
#'   \item `n_summarised`: the number of simulations summarised.
#'   \item `size_mean`, `size_sd`, `size_median`, `size_p25`, `size_p75`,
#'     `size_p0`, `size_p100`: the mean, standard deviation, median as well as
#'     25-, 75-, 0- (min), and 100- (max) percentiles of the sample sizes
#'     (number of patients randomised in each simulated trial) of the summarised
#'     trial simulations.
#'   \item `sum_ys_mean`, `sum_ys_sd`, `sum_ys_median`, `sum_ys_p25`,
#'     `sum_ys_p75`, `sum_ys_p0`, `sum_ys_p100`: the mean, standard deviation,
#'     median as well as 25-, 75-, 0- (min), and 100- (max) percentiles of the
#'     total `sum_ys` across all arms in the summarised trial simulations (e.g.,
#'     the total number of events in trials with a binary outcome, or the sums
#'     of continuous values for all patients across all arms in trials with a
#'     continuous outcome). Always uses all outcomes from all randomised
#'     patients regardless of whether or not all patients had outcome data
#'     available at the time of trial stopping (corresponding to `sum_ys_all` in
#'     results from [run_trial()]).
#'   \item `ratio_ys_mean`, `ratio_ys_sd`, `ratio_ys_median`, `ratio_ys_p25`,
#'     `ratio_ys_p75`, `ratio_ys_p0`, `ratio_ys_p100`: the mean, standard
#'     deviation, median as well as 25-, 75-, 0- (min), and 100- (max)
#'     percentiles of the final `ratio_ys` (`sum_ys` as described above divided
#'     by the total number of patients randomised) across all arms in the
#'     summarised trial simulations.
#'   \item `prob_conclusive`: the proportion (`0` to `1`) of conclusive trial
#'     simulations, i.e., simulations not stopped at the maximum sample size
#'     without a superiority, equivalence or futility decision.
#'   \item `prob_superior`, `prob_equivalence`, `prob_futility`, `prob_max`: the
#'     proportion (`0` to `1`) of trial simulations stopped for superiority,
#'     equivalence, futility or inconclusive at the maximum allowed sample size,
#'     respectively.\cr
#'     **Note:** Some metrics may not make sense if summarised simulation
#'     results are `restricted`.
#'   \item `prob_select_*`: the selection probabilities for each arm and for no
#'     selection, according to the specified selection strategy. Contains one
#'     element per `arm`, named `prob_select_arm_<arm name>` and
#'     `prob_select_none` for the probability of selecting no arm.
#'   \item `rmse`, `rmse_te`: the root mean squared errors of the estimates for
#'     the selected arm and for the treatment effect, as described in
#'     [extract_results()].
#'   \item `mae`, `mae_te`: the median absolute errors of the estimates for
#'     the selected arm and for the treatment effect, as described in
#'     [extract_results()].
#'   \item `idp`: the ideal design percentage (IDP; 0-100%), see **Details**.
#'   }
#'
#' @details
#' The ideal design percentage (IDP) returned is based on
#' *Viele et al, 2020* \doi{10.1177/1740774519877836}  (and also described in
#' *Granholm et al, 2022* \doi{10.1016/j.jclinepi.2022.11.002}, which also
#' describes the other performance measures) and has been adapted to work for
#' trials with both desirable/undesirable outcomes and non-binary outcomes.
#' Briefly, the expected outcome is calculated as the sum of the true outcomes
#' in each arm multiplied by the corresponding selection probabilities (ignoring
#' simulations with no selected arm). The IDP is then calculated as:
#' - For desirable outcomes (`highest_is_best` is `TRUE`):\cr
#'   `100 * (expected outcome - lowest true outcome) / (highest true outcome - lowest true outcome)`
#' - For undesirable outcomes (`highest_is_best` is `FALSE`):\cr
#'   `100 - IDP calculated for desirable outcomes`
#'
#' @export
#'
#' @import parallel
#'
#' @importFrom stats sd median quantile
#'
#' @seealso
#' [extract_results()], [summary()], [plot_convergence()],
#' [plot_metrics_ecdf()], [check_remaining_arms()].
#'
#' @examples
#' # Setup a trial specification
#' binom_trial <- setup_trial_binom(arms = c("A", "B", "C", "D"),
#'                                  control = "A",
#'                                  true_ys = c(0.20, 0.18, 0.22, 0.24),
#'                                  data_looks = 1:20 * 100)
#'
#' # Run 10 simulations with a specified random base seed
#' res <- run_trials(binom_trial, n_rep = 10, base_seed = 12345)
#'
#' # Check performance measures, without assuming that any arm is selected in
#' # the inconclusive simulations, with bootstrapped uncertainty measures
#' # (unstable in this example due to the very low number of simulations
#' # summarised):
#' check_performance(res, select_strategy = "none", uncertainty = TRUE,
#' n_boot = 1000, boot_seed = "base")
#'
check_performance <- function(object, select_strategy = "control if available",
                              select_last_arm = FALSE, select_preferences = NULL,
                              te_comp = NULL, raw_ests = FALSE, final_ests = NULL,
                              restrict = NULL, uncertainty = FALSE, n_boot = 5000,
                              ci_width = 0.95, boot_seed = NULL,
                              cores = NULL) {
  # Check validity of restrict argument
  if (!is.null(restrict)) {
    if (!restrict %in% c("superior", "selected")) {
      stop0("restrict must be either NULL, 'superior' or 'selected'.")
    }
  }
  # Check validity of bootstrap arguments
  if (!isTRUE(uncertainty %in% c(TRUE, FALSE) & length(uncertainty) == 1)) {
    stop0("uncertainty must be either TRUE or FALSE.")
  }
  if (isTRUE(uncertainty)) {
    if (!verify_int(n_boot, min_value = 100)) {
      stop0("n_boots must be a single integer >= 100 (values < 1000 not recommended and will result in a warning).")
    } else if (n_boot < 1000) {
      warning0("values for n_boot < 1000 are not recommended, as they may cause instable results.")
    }
    if (isTRUE(is.null(ci_width) | is.na(ci_width) | !is.numeric(ci_width) |
               ci_width >= 1 | ci_width < 0) | length(ci_width) != 1) {
      stop0("ci_width must be a single numeric value >= 0 and < 1 if n_boot is not NULL.")
    }

    # Check and prepare seeds if relevant (only done if bootstrapping)
    if (!is.null(boot_seed)) {
      if (boot_seed == "base" & length(boot_seed) == 1) {
        boot_seed <- object$base_seed
        if (is.null(boot_seed)) {
          stop0("boot_seed is set to 'base', but object contains no base_seed.")
        }
      }
      if (!verify_int(boot_seed)) {
        stop0("boot_seed must be either NULL, 'base' or a single whole number.")
      } # Generate random seeds
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) { # A global random seed exists (not the case when called from parallel::parLapply)
        oldseed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
        on.exit(assign(".Random.seed", value = oldseed, envir = globalenv(), inherits = FALSE), add = TRUE, after = FALSE)
      }
      old_rngkind <- RNGkind("L'Ecuyer-CMRG", "default", "default")
      on.exit(RNGkind(kind = old_rngkind[1], normal.kind = old_rngkind[2], sample.kind = old_rngkind[3]), add = TRUE, after = FALSE)
      set.seed(boot_seed)
      seeds <- list(get(".Random.seed", envir = globalenv()))
      if (n_boot > 1) {
        for (i in 2:n_boot) {
          seeds[[i]] <- nextRNGStream(seeds[[i - 1]])
        }
      }
    } else { # NULL seeds if not used
      seeds <- rep(list(NULL), n_boot)
    }
  }

  # Extract results and values from trial specification object
  extr_res <- extract_results(object, select_strategy = select_strategy,
                              select_last_arm = select_last_arm,
                              select_preferences = select_preferences,
                              te_comp = te_comp, raw_ests = raw_ests,
                              final_ests = final_ests, cores = cores)

  arms <- object$trial_spec$trial_arms$arms
  true_ys <- object$trial_spec$trial_arms$true_ys
  highest_is_best <- object$trial_spec$highest_is_best
  n_rep <- object$n_rep

  # Prepare output object
  res <- data.frame(metric = c("n_summarised", "size_mean", "size_sd", "size_median",
                               "size_p25", "size_p75", "size_p0", "size_p100",
                               "sum_ys_mean", "sum_ys_sd", "sum_ys_median",
                               "sum_ys_p25", "sum_ys_p75", "sum_ys_p0", "sum_ys_p100",
                               "ratio_ys_mean", "ratio_ys_sd", "ratio_ys_median",
                               "ratio_ys_p25", "ratio_ys_p75", "ratio_ys_p0", "ratio_ys_p100",
                               "prob_conclusive", "prob_superior", "prob_equivalence",
                               "prob_futility", "prob_max", paste0("prob_select_", c(paste0("arm_", arms), "none")),
                               "rmse", "rmse_te", "mae", "mae_te", "idp"),
                    est = NA, err_sd = NA, err_mad = NA, lo_ci = NA, hi_ci = NA)

  # Restrict simulations summarised
  if (is.null(restrict)) {
    restrict_idx <- rep(TRUE, n_rep)
  } else if (restrict == "superior") {
    restrict_idx <- !is.na(extr_res$superior_arm)
  } else {
    restrict_idx <- !is.na(extr_res$selected_arm)
  }
  n_restrict <- sum(restrict_idx)

  # Extract results
  res$est <- c(n_restrict,
               summarise_num(extr_res$final_n[restrict_idx]),
               summarise_num(extr_res$sum_ys[restrict_idx]),
               summarise_num(extr_res$ratio_ys[restrict_idx]),
               mean(extr_res$final_status[restrict_idx] != "max"),
               mean(extr_res$final_status[restrict_idx] == "superiority"),
               mean(extr_res$final_status[restrict_idx] == "equivalence"),
               mean(extr_res$final_status[restrict_idx] == "futility"),
               mean(extr_res$final_status[restrict_idx] == "max"),
               vapply_num(arms, function(a) sum(extr_res$selected_arm[restrict_idx] == a, na.rm = TRUE) / n_restrict),
               mean(is.na(extr_res$selected_arm[restrict_idx])),
               sqrt(mean(extr_res$sq_err[restrict_idx], na.rm = TRUE)) %f|% NA,
               sqrt(mean(extr_res$sq_err_te[restrict_idx], na.rm = TRUE)) %f|% NA,
               median(abs(extr_res$err[restrict_idx]), na.rm = TRUE) %f|% NA,
               median(abs(extr_res$err_te[restrict_idx]), na.rm = TRUE) %f|% NA,
               calculate_idp(extr_res$selected_arm[restrict_idx], arms, true_ys, highest_is_best) %f|% NA)

  # Simply object or do bootstrapping
  if (!uncertainty) { # No bootstrapping
    res <- res[, 1:2]
  } else { # Bootstrapping

    # Define bootstrap function
    performance_bootstrap_batch <- function(cur_seeds,
                                            extr_res,
                                            restrict,
                                            n_rep,
                                            rows) {
      # Restore seed afterwards if existing
      if (exists(".Random.seed", envir = globalenv())) {
        oldseed <- get(".Random.seed", envir = globalenv())
        on.exit(assign(".Random.seed", value = oldseed,
                       envir = globalenv()), add = TRUE, after = FALSE)
      }

      # Prepare matrix
      n_boot <- length(cur_seeds)
      boot_mat <- matrix(rep(NA, rows * n_boot), ncol = n_boot)

      # Bootstrap loop
      for (b in 1:n_boot) {
        # Set seed (if wanted) and bootstrap re-sample
        if (!is.null(cur_seeds[[b]])) {
          assign(".Random.seed", value = cur_seeds[[b]], envir = globalenv())
        }
        extr_boot <- extr_res[sample(n_rep, size = n_rep, replace = TRUE), ]
        # Restriction
        if (is.null(restrict)) {
          restrict_idx <- rep(TRUE, n_rep)
        } else if (restrict == "superior") {
          restrict_idx <- !is.na(extr_boot$superior_arm)
        } else {
          restrict_idx <- !is.na(extr_boot$selected_arm)
        }
        n_restrict <- sum(restrict_idx)

        boot_mat[, b] <- c(n_restrict,
                           summarise_num(extr_boot$final_n[restrict_idx]),
                           summarise_num(extr_boot$sum_ys[restrict_idx]),
                           summarise_num(extr_boot$ratio_ys[restrict_idx]),
                           mean(extr_boot$final_status[restrict_idx] != "max"),
                           mean(extr_boot$final_status[restrict_idx] == "superiority"),
                           mean(extr_boot$final_status[restrict_idx] == "equivalence"),
                           mean(extr_boot$final_status[restrict_idx] == "futility"),
                           mean(extr_boot$final_status[restrict_idx] == "max"),
                           vapply_num(arms, function(a) sum(extr_boot$selected_arm[restrict_idx] == a, na.rm = TRUE) / n_restrict),
                           mean(is.na(extr_boot$selected_arm[restrict_idx])),
                           sqrt(mean(extr_boot$sq_err[restrict_idx], na.rm = TRUE)) %f|% NA,
                           sqrt(mean(extr_boot$sq_err_te[restrict_idx], na.rm = TRUE)) %f|% NA,
                           median(abs(extr_boot$err[restrict_idx]), na.rm = TRUE) %f|% NA,
                           median(abs(extr_boot$err_te[restrict_idx]), na.rm = TRUE) %f|% NA,
                           calculate_idp(extr_boot$selected_arm[restrict_idx], arms, true_ys, highest_is_best) %f|% NA)
      }
      boot_mat
    }

    # If cores is NULL, use defaults
    if (is.null(cores)) {
      cl <- .adaptr_cluster_env$cl # Load default cluster if existing
      # If cores is not specified by setup_cluster(), use global option or 1
      cores <- .adaptr_cluster_env$cores %||% getOption("mc.cores", 1)
    } else { # cores specified, ignore defaults
      cl <- NULL
    }

    # Get bootstrap estimates
    if (cores == 1) { # Single core
      boot_mat <- performance_bootstrap_batch(cur_seeds = seeds, extr_res = extr_res,
                                              restrict = restrict, n_rep = n_rep, rows = nrow(res))
    } else { # Multiple cores
      # Setup new temporary cluster if needed
      if (is.null(cl)) { # Set up new, temporary cluster
        cl <- makePSOCKcluster(cores)
        on.exit(stopCluster(cl), add = TRUE, after = FALSE)
        clusterEvalQ(cl, RNGkind("L'Ecuyer-CMRG", "default", "default"))
      }
      # Derive chunks
      seed_chunks <- lapply(1:cores, function(x) {
        size <- ceiling(n_boot / cores)
        start <- (size * (x-1) + 1)
        seeds[start:min(start - 1 + size, n_boot)]
      })
      # Bootstrap
      boot_mat <- do.call(cbind,
                          clusterApply(cl = cl, x = seed_chunks, fun = performance_bootstrap_batch,
                                       extr_res = extr_res, restrict = restrict, n_rep = n_rep, rows = nrow(res)))
    }

    # Summarise bootstrap results
    res$err_sd <- apply(boot_mat, 1, sd, na.rm = TRUE) %f|% NA
    res$err_mad <- apply(boot_mat, 1, function(x) median(abs(x - median(x, na.rm = TRUE)), na.rm = TRUE) * 1.4826 ) %f|% NA
    res$lo_ci <- apply(boot_mat, 1, quantile, probs = (1 - ci_width)/2, na.rm = TRUE, names = FALSE) %f|% NA
    res$hi_ci <- apply(boot_mat, 1, quantile, probs = 1 - (1 - ci_width)/2, na.rm = TRUE, names = FALSE) %f|% NA
    # NAs for p0-/p100-bootstrap estimates
    res[res$metric %in% c("size_p0", "size_p100", "sum_ys_p0", "sum_ys_p100", "ratio_ys_p0", "ratio_ys_p100"),
        c("err_sd", "err_mad", "lo_ci", "hi_ci")] <- NA
  }

  # Return result
  class(res) <- c("trial_performance", "data.frame")
  res
}
