# Extension Track 1 — K=4 Rolling-Posterior Candidate Closeout

## Status

**Closed as a frozen extension candidate. Not promoted to an independently validated v1.1 release.**

The released v1.0 assets remain unchanged. Extension Track 1 changes only the Bayesian posterior-memory policy in a separate candidate implementation.

## Motivation

The frozen v1.0 cumulative Bayesian posterior improved the original fast development condition and transferred positively to two lower-amplitude fast native cases, but an additional high-amplitude sensitivity case (Case C, 0.2C + 0.8C) exposed aggregate regression.

Diagnostic ablation showed that removing autocorrelation weighting or robust-sigma weighting did not repair Case C. Local-posterior and rolling-memory tests instead identified long cumulative memory as the dominant observed failure mechanism.

## Candidate definition

The extension candidate uses the original Bayesian prior plus the most recent **K=4 accepted-window likelihoods**.

Unchanged relative to frozen v1.0:

- state vector and state transition;
- SOC-dependent 2RC parameter tables;
- measurement equation structure;
- excitation gate;
- prior and alpha grid;
- quadratic nuisance projection;
- robust residual scale;
- autocorrelation weighting;
- window eligibility logic;
- EKF Q/R/P0;
- all plant dynamics.

Only posterior memory is changed.

## K selection

Finite memory lengths `K = {1, 2, 4, 8, 16, 32}` were screened on A/B/C.

The selection rule was defined **after viewing the sweep**, so it is not preregistered:

> among finite K values preserving plant invariance, choose the largest K that is non-degrading versus Frozen on all current A/B/C cases and non-degrading versus frozen v1.0 on formal A/B.

This rule selects **K=4**. The purpose is to favour the longest available smoothing memory subject to the observed no-regression screen, not to minimize training RMSE.

## Aggregate evidence

| Case | Evidence role | K4 vs Frozen | K4 vs frozen v1.0 |
|---|---|---:|---:|
| A: 0.2C + 0.3C, ≈0.144 Hz | Formal native | −1.917% | −0.518% |
| B: 0.3C + 0.4C, ≈0.144 Hz | Formal native | −1.725% | −1.522% |
| C: 0.2C + 0.8C, ≈0.144 Hz | Sensitivity only | −0.403% | −2.094% |

Implementation checks:

- standalone K=4 core parity: PASS;
- integrated Simulink parity: PASS;
- plant/state-transition invariance: PASS;
- gate-closed fallback equivalence: PASS.

## Preserved negative evidence

### Sensor-bias qualification

The predeclared K=4 sensor-bias qualification remains **FAIL**.

The only qualification failures occur in Case A at ±20 mA current offset, where accepted-update count shifts by −2 against the predefined `|ΔN| ≤ 1` threshold. The result is not relaxed retrospectively.

Matched diagnostics later showed that:

- frozen v1.0 exhibits the same update-count shifts on the same A/B datasets;
- K=4 amplifies internal final-alpha current-offset sensitivity;
- most of that sensitivity follows the chain
  `current offset → shadow-SOC drift → R0(SOC) LUT index shift → alpha compensation`;
- output-level SOC and posterior-voltage sensitivity did not increase in proportion to final-alpha sensitivity.

These diagnostics explain the engineering meaning of the failure; they do not convert FAIL to PASS.

### No independent holdout

`EXP_0037`, initially considered as an archived holdout candidate, contains the entire 13,354-sample development electrical sequence with exactly matching voltage and current samples. It is therefore a representation of the same physical run and is ineligible.

No untouched independent fast-band holdout remains in the current archive.

## Leave-one-condition-out stability

Internal leave-one-condition-out selection gives:

- B+C → hold out A: selects K=4, A PASS;
- A+C → hold out B: selects K=4, B PASS;
- A+B → hold out C: selects K=8, held-out C degrades **+0.381%** versus Frozen.

Aggregate result: **2/3 PASS**.

This shows that Case C is a material stress constraint in the selection of K=4. Because the rolling-memory architecture itself was developed after observing A/B/C, this is internal model-selection stability evidence, not prospective independent validation.

## SOC-local limitation

Case C ends at approximately **78.07% SOC** and is therefore sensitivity-only.

Five-percentage-point SOC analysis shows:

| SOC band | K4 vs Frozen |
|---|---:|
| 20–25% | +3.025% |
| 25–30% | −0.368% |
| 30–35% | −19.551% |
| 35–40% | −8.437% |
| 40–45% | −6.321% |
| 45–50% | −11.618% |
| 50–55% | −19.417% |
| 55–60% | **+29.385%** |
| 60–65% | **+45.590%** |
| 65–70% | **+2.738%** |
| 70–75% | **+7.473%** |
| 75–78.07% | **+40.740%** |

The aggregate Case-C gain therefore masks sustained high-SOC local regression beginning around 55% SOC.

## Mechanistic attribution

### Shadow-to-EKF target divergence

A fixed-state conditional-alpha oracle was evaluated on the realized K4 EKF state path.

For Case C at ≥55% SOC:

- mean shadow-window alpha: **1.01453**;
- mean EKF conditional-oracle alpha: **1.00031**;
- mean divergence: **+0.01422**;
- fraction of windows with shadow alpha above the EKF oracle: **96.55%**.

Related divergence is also present in A/B. Therefore shadow-to-EKF target mismatch is an architecture-level property, not a Case-C-only explanation.

### Exact residual-correction geometry

For each realized SOC bin,

`e_K4 = e_Frozen + ΔV`

and therefore

`SSE_K4 − SSE_Frozen = 2 e_Frozenᵀ ΔV + ||ΔV||²`.

The cross term is directional; the quadratic term is the correction-energy cost.

The Case-C high-SOC evidence shows:

- **55–60% SOC:** state-path degradation is material; forcing alpha=1 on the realized K4 state path is already worse than Frozen.
- **60–65% SOC:** the K4 state path with alpha=1 is better than Frozen, but the adaptive-alpha layer over-corrects strongly and reverses the benefit.
- **65–70% and 70–75% SOC:** the same pattern remains; beneficial state-path behaviour is offset by alpha-layer over-correction.
- **75–78.07% SOC:** both the state-path contribution and adaptive-layer contribution are unfavourable.

Accordingly, the bounded mechanistic interpretation is:

> the K=4 candidate increases tracking responsiveness and follows shadow-model identification targets more locally; under high-amplitude/high-SOC Case C, those targets can be too aggressive for the EKF-useful measurement correction. The resulting correction energy can exceed the available residual-cancellation benefit, producing local high-SOC regression.

The conditional oracle and alpha=1 paths are diagnostic counterfactuals that reuse K4 states; they are not independent closed-loop redesign validations.

## Claim boundary

### Supported

- K=4 is a reproducible rolling-posterior extension candidate.
- K=4 improves aggregate A/B and aggregate Case-C sensitivity performance on the current evidence set.
- Long cumulative posterior memory is the dominant observed mechanism behind the original aggregate Case-C failure.
- Case-C high-SOC local regression is real and is mechanistically associated with excessive correction energy, especially adaptive-alpha over-correction over approximately 60–75% SOC.

### Not supported

- independent fast-band generalization of K=4;
- universal SOC-local improvement;
- independent cross-frequency generalization;
- cross-temperature or cross-cell generalization;
- interpreting `alpha_R0` as an independently measured physical R0 drift;
- promotion of K=4 to an independently validated v1.1 release.

## Development discipline

The v1.0 development case and A/B/C are consumed development/model-selection evidence for this extension family.

Do not retune K, gate, prior, likelihood, or EKF settings on these cases and then reuse the same cases as independent validation.

Any future architecture modification defines a new candidate and requires a new prospective validation protocol.
