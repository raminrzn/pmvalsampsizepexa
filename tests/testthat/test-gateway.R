test_that("gateway dispatches func='model_run' and returns JSON", {
  js <- gateway(func = "model_run", model_input = get_default_input())
  expect_type(js, "character")
  parsed <- jsonlite::fromJSON(js)
  expect_equal(parsed$sample_size, model_run(get_default_input())$sample_size)
  expect_true("criteria" %in% names(parsed))
})

test_that("gateway defaults func to model_run and strips control fields", {
  js <- gateway(model_input = get_default_input(), api_key = "x",
                session_id = "y", execution_id = "z",
                callback_url = "https://example.invalid/cb")
  expect_equal(jsonlite::fromJSON(js)$sample_size,
               model_run(get_default_input())$sample_size)
})

test_that("gateway with no input falls back to the default design", {
  expect_equal(jsonlite::fromJSON(gateway())$sample_size,
               model_run(get_default_input())$sample_size)
})

test_that("gateway preserves full numeric precision", {
  parsed <- jsonlite::fromJSON(gateway(func = "model_run",
                                       model_input = get_default_input()))
  ref <- model_run(get_default_input())
  expect_equal(parsed$se_cstat, ref$se_cstat, tolerance = 1e-12)
})

test_that("gateway handles no-arg dispatch to the helpers", {
  expect_true("type" %in% names(jsonlite::fromJSON(gateway(func = "get_default_input"))))
})
