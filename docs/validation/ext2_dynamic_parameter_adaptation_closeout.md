# EXT2 Dynamic-Parameter Adaptation Qualification — Closeout

## Scope

EXT2 asked a deliberately narrow question:

> **Which additional 2RC parameters, if any, are actually qualified for continuous online adaptation on the available LG INR18650 MJ1 evidence?**

The track does **not** replace the released frozen 2RC-EKF baseline, the released gated Bayesian `R0` adaptation, EXT1 K=4, or the frozen Simulink assets. All EXT2 work was performed as external/shadow qualification.

The parameterization used for dynamic-parameter qualification was

```text
theta = [R0, R1, tau1, R2, tau2]
tau1 = R1*C1
tau2 = R2*C2
```

rather than estimating `R` and `C` independently.

## Final disposition

| Candidate | Continuous online adaptation | Other disposition |
|---|---|---|
| `R0` | **Qualified within released gated Bayesian v1.0 scope** | Existing released path |
| `R1 + tau1` | **Not qualified** | Pulse/event calibration remains possible future work |
| `R2 + tau2` | **Not qualified — closed** | Event-based re-identification remains plausible |
| `R1 + tau1 + R2 + tau2` | **Not qualified** | HPPC pulse+relaxation batch re-identification only |
| Charging-baseline correction | Not an online parameter target | Condition-compatible model-form evidence only |
| SOC-axis remapping | Not justified as a model replacement | Sensitivity analysis only |

The central result is:

> **Recoverability and identifiability were necessary but not sufficient for online adaptation.**
> `R2/tau2` could be recovered in synthetic tests and was informative under suitable excitation, but the measured-voltage optimum was not transferable across SOC, frequency, and excitation conditions. Continuous `R2/tau2` adaptation was therefore rejected under the available evidence.

## Evidence chain

| Stage | Purpose | Result | Consequence |
|---|---|---|---|
| B1-1 | Synthetic injected-ground-truth recovery for `R2/tau2` | **PASS** | Matched-model recoverability established |
| B1-2A | SOC/state/window readiness | **PASS** | Real-voltage qualification allowed |
| B1-2B | Original real-voltage `R2/tau2` target consistency | **FAIL** | Do not promote adaptation |
| B1-2C | Residual failure attribution | Diagnostic | Common-mode baseline bias dominates nominal voltage error |
| B1-2D/E | SOC-axis / effective-capacity plausibility | Diagnostic | A larger effective capacity reduces bias but is not independently supported as physical capacity |
| B1-2F/G | Charge/discharge pseudo-OCV and SOC-axis directionality | Diagnostic | Direction/history effects remain material across tested SOC-axis conventions |
| B1-2H | Independent low-rate charging-baseline correction on selected DC-AC windows | **PASS locally** | Strong local/window model-form evidence |
| B1-2I | `R2/tau2` re-audit after baseline control | **FAIL** | Continuous `R2/tau2` candidate formally closed |
| B1-2J | HPPC SOC-label provenance reconstruction | **INCONCLUSIVE** | Do not relocate frozen LUT SOC nodes |
| C1 | Full 1C trajectory transfer of the charging-baseline correction | **FAIL / partial support** | Do not promote the correction to a universal charge-OCV branch |
| C1A | Full-trajectory SOC-axis sensitivity | **SOC_AXIS_MAPPING_NOT_PRIMARY** | SOC-axis convention is not the primary explanation of C1 failure |

## Key numerical evidence

### Local/window charging-baseline validation

An independently derived low-rate charging-baseline correction improved all **18/18** selected DC-AC validation windows.

- median nominal RMSE: **36.940 mV**
- median corrected RMSE: **7.621 mV**
- median absolute-bias reduction: **85.98%**

This is strong evidence that a charging-baseline/model-form mismatch exists under those tested conditions.

It is **not** evidence that the correction is a universal OCV branch or equilibrium hysteresis model.

### Full-trajectory transfer

The same frozen correction was then evaluated prospectively on the historical 1C full-charge trajectory over approximately 17–85% SOC.

- frozen RMSE: **23.165 mV**
- corrected RMSE: **19.286 mV**
- RMSE improvement: **16.75%**
- frozen centered RMSE: **8.638 mV**
- corrected centered RMSE: **12.543 mV**

All seven prospective transfer gates failed.

The failure was strongly SOC dependent: high-SOC bins improved, while the 17–30% bin was severely over-corrected.

### SOC-axis sensitivity

C1A rebuilt the 0.1C-derived correction independently on three pre-existing SOC conventions:

- `FROZEN_QREF` — 3.335 Ah
- `NOMINAL_3P5` — 3.500 Ah
- `SELF_NORMALIZED` — each trajectory normalized by its own measured terminal-anchor throughput

The `FROZEN_QREF` path reproduced C1 with **0 mV** parity error.

The best corrected full-trajectory result among the three axes was `NOMINAL_3P5`, but its corrected-RMSE gain over `FROZEN_QREF` was only **6.27%**, below the predeclared partial-support criterion. The low-SOC gain was **9.162 mV**, also below the predeclared threshold.

Final classification:

```text
SOC_AXIS_MAPPING_NOT_PRIMARY
```

Therefore SOC-axis convention alone does not explain the full-trajectory transfer failure.

## Why `R2/tau2` was closed

The important distinction is:

```text
identifiable != transferable
```

Under useful MID/SLOW excitation, the slow branch carried substantially more practical information than the fast branch. Synthetic recovery also showed that `R2/tau2` can be recovered when the model is matched and the truth is known.

However, on measured voltage, the optimum `R2/tau2` scaling changed materially with SOC region, excitation frequency, excitation amplitude, and baseline/model-form treatment.

After the independently derived B1-2H charging-baseline correction was frozen and applied, the target-consistency gates still failed. The parameter pair was therefore treated as a condition-dependent mismatch absorber rather than a stable physical online target.

## HPPC SOC provenance

The B1-2J provenance audit reconstructed much of the HPPC chronology, but incomplete authoritative current coverage between pulse states and physical SOC anchors prevented an independent reconstruction of absolute HPPC SOC.

Final classification:

`HPPC_SOC_PROVENANCE_INCONCLUSIVE`

This result does **not** prove that the historical HPPC SOC labels are wrong. The frozen LUT SOC coordinates are therefore left unchanged.
## HPPC pulse+relaxation remains useful

EXT2 does **not** conclude that the dynamic RC parameters are useless.

Dedicated HPPC pulse+relaxation windows substantially improve multi-timescale separation compared with ordinary periodic excitation. This supports a different architecture:

> **event-based / maintenance / RPT-style batch re-identification**

rather than continuous multi-parameter adaptation.

## Claim boundary

Supported:

- SOC-dependent 2RC-EKF state estimation for the documented MJ1 dataset and validated SOC range;
- released gated Bayesian `R0` adaptation within its v1.0 evidence scope;
- strong local/window evidence for a charging-baseline/model-form mismatch;
- rejection of continuous `R2/tau2` adaptation under the available historical-data evidence;
- HPPC pulse+relaxation as a credible future event-based re-identification route.

Not supported:

- continuous online estimation of all 2RC parameters;
- production-ready online `R2/tau2` adaptation;
- a universal charge-direction OCV correction;
- proof of electrochemical hysteresis;
- proof that the historical HPPC SOC labels are wrong;
- cross-cell or cross-temperature generalization.

## Reopen condition

The historical-data EXT2 track is closed. It should be reopened only with new controlled evidence, ideally including multiple fresh LG MJ1 cells, controlled chamber temperature, continuous authoritative current logging, explicit full/empty SOC anchors, low-rate charge/discharge OCV characterization, multiple C-rate full trajectories, a new HPPC pulse+relaxation campaign, and at least one independent holdout cell.
