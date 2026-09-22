# Reference values come from calling pmvalsampsize directly with the same
# design parameters. simobs is left at its default so the seeded simulation
# matches the upstream call exactly.

test_that("model_run reproduces pmvalsampsize for the default design", {
  out <- model_run(get_default_input())
  ref <- pmvalsampsize::pmvalsampsize(type = "b", prevalence = 0.018,
                                      cstatistic = 0.8, lpnormal = c(-5, 2.5),
                                      graph = FALSE)
  expect_equal(out$sample_size, ref$sample_size)
  expect_equal(out$events, ref$events)
  expect_equal(out$type, "binary")
})

test_that("criteria table becomes rows with a criterion column", {
  out <- model_run(get_default_input())
  expect_s3_class(out$criteria, "data.frame")
  expect_true("criterion" %in% names(out$criteria))
  # The headline figure must be the binding (largest) criterion.
  expect_equal(max(out$criteria$Samp_size), out$sample_size)
})

test_that("lpbeta is an accepted alternative to lpnormal", {
  out <- model_run(get_sample_input()$lp_beta)
  expect_gt(out$sample_size, 0)
})

test_that("only binary is offered, and the reason is accurate", {
  # pmvalsampsize 0.1.0 implements only the binary branch; other types fail
  # upstream with "object 'out' not found", which tells the caller nothing.
  expect_error(model_run(type = "continuous", prevalence = 0.1, cstatistic = 0.7),
               "only the binary-outcome branch")
  expect_error(model_run(type = "survival", prevalence = 0.1, cstatistic = 0.7),
               "only the binary-outcome branch")
  expect_error(model_run(type = "poisson", prevalence = 0.1, cstatistic = 0.7),
               "Unrecognised")
})

test_that("missing required fields are named in the error", {
  expect_error(model_run(type = "binary", prevalence = 0.018),
               "Missing required variable")
  expect_error(model_run(type = "binary", prevalence = 0.018, cstatistic = 0.8),
               "LP distribution is required")
})

test_that("supplying two LP distributions is rejected", {
  expect_error(
    model_run(type = "binary", prevalence = 0.018, cstatistic = 0.8,
              lpnormal = c(-5, 2.5), lpbeta = c(0.5, 0.5)),
    "exactly one LP distribution"
  )
})

test_that("the time guard aborts with an actionable message", {
  # lpcstat can send pmvalsampsize into an iterative search that does not
  # terminate promptly; on a hosted service that would hang the request.
  expect_error(
    model_run(type = "binary", prevalence = 0.018, cstatistic = 0.8,
              lpcstat = 0.8, simobs = 50000, time_limit = 5),
    "exceeded 5s"
  )
})

test_that("aliases map onto canonical names", {
  a <- model_run(get_default_input())
  b <- model_run(outcome = "binary", outcome_prevalence = 0.018,
                 auc = 0.8, lp_normal = c(-5, 2.5))
  expect_equal(a$sample_size, b$sample_size)
})

test_that("a JSON null is treated as an absent optional field", {
  expect_no_error(
    out <- model_run(list(type = "binary", prevalence = 0.018, cstatistic = 0.8,
                          lpnormal = c(-5, 2.5), sensitivity = NULL, seed = NULL))
  )
  expect_equal(out$sample_size, model_run(get_default_input())$sample_size)
})

test_that("get_sample_input(n) limits entries and validates n", {
  expect_length(get_sample_input(1), 1L)
  expect_error(get_sample_input(0), "positive integer")
})
