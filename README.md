# pmvalsampsizepexa

<!-- badges: start -->
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- badges: end -->

A **ModelsCloud wrapper** for [`pmvalsampsize`](https://cran.r-project.org/package=pmvalsampsize),
which computes the **minimum sample size required to externally validate** an
existing clinical prediction model with a binary outcome, using the criteria of
Riley et al. (*Stat Med* 2021) and Archer et al. (2020).

> **This is a study-design calculator, not a patient-level risk model.** It
> answers "how large must my validation dataset be?", not "what is this
> patient's risk?".

> **This package contains none of the methodology.** The criteria and their
> implementation live in `pmvalsampsize`; this repo only adapts them to the
> ModelsCloud calling convention and adds two guards the hosted setting needs
> (below).

---

## Installation

```r
# install.packages("remotes")
remotes::install_git("https://github.com/raminrzn/pmvalsampsizepexa", ref = "main")
```

---

## Quick start

```r
library(pmvalsampsizepexa)

model_run(get_default_input())
#> $sample_size
#> [1] 20975
#> $events
#> [1] 377.55
#> $criteria
#>                 criterion Samp_size Perf    SE CI_width
#> 1        Criteria 1 - O/E     20975  1.0 0.051      0.2
#> 2     Criteria 2 - C-slope      4563  1.0 0.051      0.2
#> 3 Criteria 3 - C statistic      4252  0.8 0.026      0.1
#> 4                Final SS     20975  1.0 0.051      0.2
```

---

## Inputs

Three fields are mandatory:

| Field | Meaning |
|---|---|
| `type` | Must be `"binary"` — see the limitation below |
| `prevalence` | Anticipated outcome prevalence in the validation sample |
| `cstatistic` | The existing model's anticipated C-statistic |

Plus **exactly one** description of the linear predictor distribution:

| Field | Meaning |
|---|---|
| `lpnormal` | `[mean, SD]` on the linear-predictor scale |
| `lpbeta` | `[alpha, beta]` of a beta-distributed predicted risk |
| `lpcstat` | An anticipated C-statistic to derive the LP from — **slow, see below** |

Optional: `cslope`, `csciwidth`, `oe`, `oeciwidth`, `cstatciwidth`, `simobs`
(default 1,000,000), `seed`, and the net-benefit fields (`sensitivity`,
`specificity`, `threshold`, `nbciwidth`).

---

## Two things this wrapper guards

**Only binary outcomes work.** `pmvalsampsize` 0.1.0 implements a single
`if (type == "b")` branch; a continuous or survival request falls through and
fails with `object 'out' not found`, which tells the caller nothing. This
wrapper rejects those types up front with the actual reason. That is an upstream
limitation, not a decision made here — if `pmvalsampsize` grows the other
branches, this check should be relaxed.

**`lpcstat` can run unboundedly.** When the simulated event proportion does not
match the requested prevalence, `pmvalsampsize` falls back to an iterative
search. In testing, `lpcstat = 0.8` with `prevalence = 0.018` had not returned
after several minutes, while `lpnormal` and `lpbeta` answer in about a second.
On a hosted service that is a request that never comes back, so `model_run()`
takes a `time_limit` (default 120 seconds) and fails with an actionable message
suggesting `lpnormal` or `lpbeta` instead. Pass `time_limit = Inf` to disable.

---

## Output

| Field | Meaning |
|---|---|
| `sample_size` | The binding minimum N |
| `events` | Implied number of outcome events |
| `criteria` | One row per criterion (O/E ratio, calibration slope, C-statistic) plus the binding `Final SS` row |
| `se_oe`, `se_cslope`, `se_cstat` | Standard errors achieved at that N |

---

## ModelsCloud entry points

| Function | Description |
|---|---|
| `model_run(model_input)` | Size one validation study. |
| `get_sample_input(n)` | Example designs (`lpnormal` and `lpbeta` forms). |
| `get_default_input()` | A rare-outcome example, ready to modify. |
| `gateway(...)` | The platform's dispatcher; defaults to `model_run`. |

### Raw HTTP

```bash
curl -X POST https://core.modelscloud.resp.core.ubc.ca/call/v2/<ns>/pmvalsampsizepexa \
  -H "Authorization: Bearer <ACCESS_KEY_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"funcInput": {"model_input": {
        "type": "binary", "prevalence": 0.018,
        "cstatistic": 0.8, "lpnormal": [-5, 2.5]
      }}}'
```

---

## References

> Riley RD, Debray TPA, Collins GS, et al. Minimum sample size for external
> validation of a clinical prediction model with a binary outcome.
> *Stat Med.* 2021;40(19):4230–4251.
> doi:[10.1002/sim.9025](https://doi.org/10.1002/sim.9025)

> Archer L, Snell KIE, Ensor J, et al. Minimum sample size for external
> validation of a clinical prediction model with a continuous outcome.
> *Stat Med.* 2021;40(1):133–146.
> doi:[10.1002/sim.8766](https://doi.org/10.1002/sim.8766)

Underlying implementation: [`pmvalsampsize`](https://cran.r-project.org/package=pmvalsampsize)
(Joie Ensor).

## License

GPL-3, matching `pmvalsampsize`. Methodology © its original authors; wrapper
implementation © Ramin Rezaeianzadeh.
