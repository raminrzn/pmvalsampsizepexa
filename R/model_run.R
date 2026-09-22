# ---------------------------------------------------------------------------
# ModelsCloud API surface for pmvalsampsize.
#
# Riley RD, Debray TPA, Collins GS, et al. Minimum sample size for external
# validation of a clinical prediction model with a binary outcome.
# Stat Med. 2021;40(19):4230-4251. doi:10.1002/sim.9025
#
# The methodology and its implementation are pmvalsampsize; nothing here
# re-implements them. This file only adapts the calling convention and adds two
# guards the hosted setting needs (see .pmv_time_limit and the type check).
# ---------------------------------------------------------------------------

.pmv_args <- c("type", "cslope", "csciwidth", "oe", "oeciwidth", "cstatistic",
               "cstatciwidth", "simobs", "lpnormal", "lpbeta", "lpcstat",
               "tolerance", "increment", "oeseincrement", "prevalence", "seed",
               "sensitivity", "specificity", "threshold", "nbciwidth",
               "nbseincrement")

.pmv_alias <- c(
  outcome = "type", outcome_type = "type", model_type = "type",
  c_statistic = "cstatistic", auc = "cstatistic",
  outcome_prevalence = "prevalence",
  calibration_slope = "cslope", c_slope = "cslope",
  oe_ratio = "oe", observed_expected = "oe",
  lp_normal = "lpnormal", lp_beta = "lpbeta", lp_cstat = "lpcstat",
  n_sim = "simobs", simulations = "simobs"
)

# pmvalsampsize 0.1.0 implements only the binary branch: its body is a single
# `if (type == "b")` that assigns the result object. Any other type falls
# through and fails with "object 'out' not found", which tells the caller
# nothing. Reject those up front with an accurate reason.
.pmv_type <- function(x) {
  if (is.null(x) || length(x) != 1L || is.na(x)) {
    stop("`type` is required, and must be \"binary\".", call. = FALSE)
  }
  key <- tolower(trimws(as.character(x)))
  if (key %in% c("b", "binary", "binomial", "logistic")) return("b")
  if (key %in% c("c", "continuous", "linear", "s", "survival", "time-to-event",
                 "time_to_event", "cox")) {
    stop("`type` = \"", x, "\" is not supported: pmvalsampsize ",
         utils::packageVersion("pmvalsampsize"),
         " implements only the binary-outcome branch. ",
         "Use type = \"binary\", or size a continuous/survival validation by hand.",
         call. = FALSE)
  }
  stop('Unrecognised `type`: "', x, '". Use "binary".', call. = FALSE)
}

.pmv_normalize <- function(model_input, dots) {
  if (is.null(model_input)) {
    if (length(dots) == 0) return(NULL)
    model_input <- dots
  }
  # JSON null for an absent optional field arrives as NULL and would break the
  # do.call below; absent and null mean the same thing here.
  if (is.list(model_input) && !is.data.frame(model_input)) {
    model_input <- model_input[!vapply(model_input, is.null, logical(1))]
    if (length(model_input) == 0) return(NULL)
  }
  out <- as.list(model_input)
  names(out) <- tolower(names(out))
  for (a in intersect(names(out), names(.pmv_alias))) {
    canon <- .pmv_alias[[a]]
    if (!canon %in% names(out)) names(out)[match(a, names(out))] <- canon
  }
  out[intersect(names(out), .pmv_args)]
}

.pmv_criteria <- function(m) {
  df <- as.data.frame(m, stringsAsFactors = FALSE)
  df <- cbind(criterion = rownames(m), df, stringsAsFactors = FALSE)
  rownames(df) <- NULL
  names(df) <- gsub("^_|_$", "", gsub("[^A-Za-z0-9]+", "_", names(df)))
  df
}

#' Minimum sample size to validate a prediction model (ModelsCloud entry point)
#'
#' Computes the minimum sample size required to externally validate an existing
#' multivariable clinical prediction model with a **binary** outcome, using the
#' criteria of Riley et al. (*Stat Med* 2021) and Archer et al. (2020).
#'
#' @details
#' Inputs may arrive **wrapped** under `model_input` or **unwrapped** as named
#' arguments, and common aliases are mapped to canonical names (`auc` ->
#' `cstatistic`, `simulations` -> `simobs`).
#'
#' Three fields are mandatory: `prevalence`, `cstatistic`, and exactly one
#' description of the linear predictor distribution — `lpnormal` (mean and SD),
#' `lpbeta` (alpha and beta), or `lpcstat` (an anticipated C-statistic).
#'
#' **`lpcstat` can be very slow.** When the simulated event proportion does not
#' match the requested prevalence, pmvalsampsize falls back to an iterative
#' search that is not guaranteed to terminate quickly; a hosted call would
#' otherwise hang indefinitely. `time_limit` bounds it and fails with an
#' actionable message. `lpnormal` and `lpbeta` return in about a second.
#'
#' Only binary outcomes are supported, because that is all pmvalsampsize 0.1.0
#' implements — continuous and survival types are rejected rather than passed
#' through to an obscure internal error.
#'
#' This is a study-design calculator, not a patient-level risk model.
#'
#' @param model_input A named list (or one-row data frame) with `type`
#'   (`"binary"`), `prevalence`, `cstatistic`, and one of `lpnormal`, `lpbeta`
#'   or `lpcstat`. Optional: `cslope`, `csciwidth`, `oe`, `oeciwidth`,
#'   `cstatciwidth`, `simobs`, `seed`, and the net-benefit fields
#'   (`sensitivity`, `specificity`, `threshold`, `nbciwidth`). If `NULL` and
#'   nothing is supplied via `...`, [get_default_input()] is used.
#' @param ... Alternative to `model_input`: the fields as named arguments.
#' @param time_limit Seconds to allow before aborting, guarding against the
#'   `lpcstat` iterative search. Default 120; `Inf` disables the guard.
#'
#' @return A named list with the headline `sample_size`, the implied number of
#'   `events`, the precision achieved for each target (O/E ratio, calibration
#'   slope, C-statistic), and `criteria` — a data frame with one row per
#'   sample-size criterion plus the binding "Final SS" row.
#'
#' @references
#' Riley RD, Debray TPA, Collins GS, et al. Minimum sample size for external
#' validation of a clinical prediction model with a binary outcome.
#' *Stat Med.* 2021;40(19):4230-4251. \doi{10.1002/sim.9025}
#'
#' Archer L, Snell KIE, Ensor J, et al. Minimum sample size for external
#' validation of a clinical prediction model with a continuous outcome.
#' *Stat Med.* 2021;40(1):133-146. \doi{10.1002/sim.8766}
#'
#' @examples
#' model_run(get_default_input())
#' @export
model_run <- function(model_input = NULL, ..., time_limit = 120) {
  args <- .pmv_normalize(model_input, list(...))
  if (is.null(args)) args <- get_default_input()

  args$type <- .pmv_type(args$type)

  missing <- setdiff(c("prevalence", "cstatistic"), names(args))
  if (length(missing) > 0) {
    stop("Missing required variable(s): ", paste(missing, collapse = ", "),
         ". Accepted names (incl. aliases) are documented in ?model_run.",
         call. = FALSE)
  }

  lp <- intersect(c("lpnormal", "lpbeta", "lpcstat"), names(args))
  if (length(lp) == 0) {
    stop("An LP distribution is required: supply one of lpnormal (mean, SD), ",
         "lpbeta (alpha, beta) or lpcstat (anticipated C-statistic).",
         call. = FALSE)
  }
  if (length(lp) > 1) {
    stop("Supply exactly one LP distribution; got: ",
         paste(lp, collapse = ", "), ".", call. = FALSE)
  }

  # graph = TRUE would try to open a device on a headless container.
  args$graph <- FALSE
  args$trace <- FALSE
  args <- lapply(args, function(v) if (length(v) == 1L) unname(v) else unname(v))

  res <- tryCatch({
    if (is.finite(time_limit)) {
      setTimeLimit(elapsed = time_limit, transient = TRUE)
      on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
    }
    do.call(pmvalsampsize::pmvalsampsize, args)
  }, error = function(e) {
    msg <- conditionMessage(e)
    if (grepl("reached elapsed time limit|reached CPU time limit", msg)) {
      stop("Calculation exceeded ", time_limit, "s and was aborted. This ",
           "happens when `lpcstat` triggers pmvalsampsize's iterative search. ",
           "Describe the linear predictor with `lpnormal` or `lpbeta` instead, ",
           "or raise `time_limit`.", call. = FALSE)
    }
    stop(e)
  })

  out <- list(
    type        = res$type,
    sample_size = res$sample_size,
    events      = res$events,
    prevalence  = res$prevalence,
    cstatistic  = res$cstatistic,
    criteria    = .pmv_criteria(res$results_table)
  )
  for (f in c("oe", "se_oe", "lb_oe", "ub_oe", "width_oe", "cslope",
              "se_cslope", "csciwidth", "se_cstat", "cstatciwidth")) {
    v <- res[[f]]
    if (!is.null(v) && !all(is.na(v))) out[[f]] <- v
  }
  out
}

#' Example validation sample-size inputs
#'
#' Two ways of describing the same linear predictor distribution. `lpcstat` is
#' deliberately absent: it can trigger a long iterative search (see
#' [model_run()]), so it is a poor default to copy.
#'
#' @param n Optional positive integer; if supplied, the first `n` examples are
#'   returned. Defaults to all.
#' @param ... Additional fields supplied by the platform; ignored.
#' @return A named list of example input lists.
#' @seealso [model_run()], [get_default_input()]
#' @examples
#' get_sample_input()
#' @export
get_sample_input <- function(n = NULL, ...) {
  out <- list(
    lp_normal = list(type = "binary", prevalence = 0.018, cstatistic = 0.8,
                     lpnormal = c(-5, 2.5)),
    lp_beta = list(type = "binary", prevalence = 0.018, cstatistic = 0.8,
                   lpbeta = c(0.5, 0.5))
  )
  if (!is.null(n)) {
    if (!is.numeric(n) || length(n) != 1L || n < 1L) {
      stop("`n` must be a single positive integer.", call. = FALSE)
    }
    out <- out[seq_len(min(as.integer(n), length(out)))]
  }
  out
}

#' Default validation sample-size input
#'
#' A rare binary outcome (1.8% prevalence), an existing model with a
#' C-statistic of 0.8, and a normally distributed linear predictor.
#'
#' @param ... Additional fields supplied by the platform; ignored.
#' @return A named list of default design parameters.
#' @seealso [model_run()], [get_sample_input()]
#' @examples
#' get_default_input()
#' @export
get_default_input <- function(...) {
  list(
    type       = "binary",
    prevalence = 0.018,
    cstatistic = 0.8,
    lpnormal   = c(-5, 2.5)
  )
}
