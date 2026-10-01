#!/usr/bin/env python3
"""Verify archived A8c evidence. This does not execute MATLAB or Simulink.

Python standard library only. Default root is the parent of this script's
``tools`` directory. Source CSVs are read without interpolation or shifting.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

EVIDENCE = Path('results/validation/A8c')
CASES = ('correct_init', 'minus20pp', 'plus15pp')


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding='utf-8-sig', newline='') as handle:
        return list(csv.DictReader(handle))


def number(row: dict[str, str], key: str) -> float:
    value = float(row[key])
    require(math.isfinite(value), f'Non-finite {key}')
    return value


def flag(value: str) -> bool:
    require(value.lower() in ('1', '0', 'true', 'false'), 'Invalid Boolean value')
    return value.lower() in ('1', 'true')


def rms(values: list[float]) -> float:
    require(bool(values), 'Cannot compute RMS on an empty sequence')
    return math.sqrt(math.fsum(value * value for value in values) / len(values))


def verify(root: Path) -> dict:
    root = root.resolve()
    folder = root / EVIDENCE
    manifest = json.loads((folder / 'A8c_package_manifest.json').read_text(encoding='utf-8'))
    seen = set()
    for item in manifest['files']:
        relative = Path(item['path'])
        require(not relative.is_absolute() and '..' not in relative.parts,
                'Unsafe path in manifest')
        require(item['path'] not in seen, 'Duplicate manifest path')
        seen.add(item['path'])
        path = root / relative
        require(path.is_file(), f'Missing packaged file: {relative}')
        require(path.resolve().is_relative_to(root), f'File escapes root: {relative}')
        blob = path.read_bytes()
        require(len(blob) == item['bytes'], f'Size mismatch: {relative}')
        require(hashlib.sha256(blob).hexdigest() == item['sha256'],
                f'Hash mismatch: {relative}')

    a_status = read_csv(folder / 'A8a_status.csv')
    require(len(a_status) == 1 and a_status[0]['BaselineReplay'] == 'MATCHED_A7A_BASELINE',
            'A8a baseline status is not matched')
    a_checks = read_csv(folder / 'A8a_regression_checks.csv')
    require(len(a_checks) == 40 and all(flag(r['Passed']) for r in a_checks),
            'A8a check count/pass mismatch')
    for row in a_checks:
        require(number(row, 'MaxDifference') <= number(row, 'Tolerance'),
                f"A8a tolerance failed: {row['CheckName']}")
    b_status = read_csv(folder / 'A8b_status.csv')
    require(len(b_status) == 1, 'A8b status count mismatch')
    require(b_status[0]['Execution'] == 'COMPLETED', 'A8b did not complete')
    require(b_status[0]['Parity'] == 'PASS_FOR_TESTED_1S_HOLDOUT_CASES',
            'A8b limited-scope parity did not pass')
    require(b_status[0]['ReleaseDecision'] == 'NOT_RELEASED',
            'Original release boundary was changed')

    b_checks = read_csv(folder / 'A8b_signal_checks.csv')
    require(len(b_checks) == 15, 'Expected 15 runtime signal checks')
    check_by_key = {(r['InitialCase'], r['Signal']): r for r in b_checks}
    require(len(check_by_key) == 15, 'Duplicate runtime checks')
    for row in b_checks:
        require(flag(row['Passed']), 'Runtime check is not marked passed')
        require(number(row, 'MaxAbsDifference') <= number(row, 'Tolerance'),
                'Recorded runtime error exceeds tolerance')

    groups = defaultdict(list)
    for row in read_csv(folder / 'A8b_trace.csv'):
        groups[row['InitialCase']].append(row)
    require(set(groups) == set(CASES), 'Unexpected initialization cases')
    reference = read_csv(folder / 'A8c_holdout_reference.csv')
    require(len(reference) == 1165, 'Reference sample count mismatch')
    b_summary = {r['InitialCase']: r for r in read_csv(folder / 'A8b_summary.csv')}
    a_metrics = {r['InitialCase']: r for r in read_csv(folder / 'A8a_baseline_metrics.csv')}
    require(set(b_summary) == set(CASES), 'Summary case mismatch')

    case_result = []
    signals = (
        ('A8b_SOC', 'MATLAB_SOC', 'Simulink_SOC', 100.0),
        ('A8b_Vpost', 'MATLAB_Vpost', 'Simulink_Vpost', 1000.0),
        ('A8b_Innovation', 'MATLAB_Innovation', 'Simulink_Innovation', 1000.0),
    )
    for case in CASES:
        rows = groups[case]
        require(len(rows) == 1165, f'Sample count mismatch: {case}')
        for k, (row, ref) in enumerate(zip(rows, reference)):
            require(number(row, 'Time_s') == k == number(ref, 'Time_s'),
                    f'Time sequence mismatch: {case}/{k}')
            require(abs(number(row, 'LoggedCurrent_A') - number(ref, 'Current_A')) <= 1e-10,
                    'Current input differs from reference')
            require(abs(number(row, 'LoggedMeasuredVoltage_V') - number(ref, 'Voltage_V')) <= 1e-10,
                    'Voltage input differs from reference')
            require(number(row, 'LoggedCurrent_A') == -3.4,
                    'Test is not the archived constant-current record')
        maximum = {}
        for signal, matlab_key, simulink_key, scale in signals:
            errors = [scale * (number(r, simulink_key) - number(r, matlab_key)) for r in rows]
            max_error = max(abs(e) for e in errors)
            threshold = number(check_by_key[(case, signal)], 'Tolerance')
            require(max_error <= threshold, f'Decoded CSV parity failed: {case}/{signal}')
            maximum[signal] = max_error
        soc_errors = [100*(number(r, 'Simulink_SOC') - number(ref, 'SOC_ref'))
                      for r, ref in zip(rows, reference)]
        voltage_errors = [1000*(number(r, 'Simulink_Vpost') - number(ref, 'Voltage_V'))
                          for r, ref in zip(rows, reference)]
        soc_rms = rms(soc_errors)
        voltage_rms = rms(voltage_errors)
        require(abs(soc_rms - number(b_summary[case], 'Simulink_SOC_RMSE_vsReference_pp')) < 1e-7,
                'SOC RMSE does not reproduce summary')
        require(abs(voltage_rms - number(b_summary[case], 'Simulink_Vpost_RMSE_mV')) < 1e-6,
                'Voltage RMSE does not reproduce summary')
        require(abs(soc_rms - number(a_metrics[case], 'SOC_RMSE_pp')) < 1e-6,
                'Simulink SOC metric differs from baseline')
        clamp_count = sum(abs(number(r, 'Simulink_SOC')-.17) < 1e-10 for r in rows)
        require(clamp_count == 34, 'Archived SOC lower-clamp count changed')
        case_result.append({'case': case, 'samples': len(rows),
                            'decoded_csv_maximum_differences': maximum,
                            'soc_rmse_vs_reference_pp': soc_rms,
                            'posterior_voltage_rmse_mV': voltage_rms,
                            'lower_clamp_sample_count': clamp_count})

    ekf = read_csv(folder / 'A7a_EKF_regression.csv')
    require(len(ekf) == 12, 'Expected 12 A7a EKF rows')
    baseline = {r['InitialCase']: r for r in ekf if r['Version'] == 'Baseline'}
    require(set(baseline) == set(CASES), 'Missing A7a baseline')
    candidate = [r for r in ekf if r['Version'] != 'Baseline']
    require(len(candidate) == 9, 'Expected 9 fixed-candidate EKF cases')
    for row in candidate:
        base = baseline[row['InitialCase']]
        for metric, delta in [('SOC_RMSE_pp', 'DeltaSOC_RMSE_pp'),
                              ('PosteriorVoltage_RMSE_mV', 'DeltaPosteriorVoltage_RMSE_mV')]:
            require(abs(number(row, metric)-number(base, metric)-number(row, delta)) < 1e-8,
                    'A7a EKF change column mismatch')
        require(number(row, 'DeltaSOC_RMSE_pp') > 0,
                'Archived candidate SOC tradeoff changed')
        require(number(row, 'DeltaPosteriorVoltage_RMSE_mV') < 0,
                'Archived candidate voltage tradeoff changed')

    td = read_csv(folder / 'A7a_TD_summary.csv')
    require(len(td) == 18, 'Expected 18 A7a time-domain summary rows')
    for row in td:
        for base, cand, delta in [('Base_ComplexRMSE_mOhm', 'Candidate_ComplexRMSE_mOhm', 'DeltaComplex_mOhm'),
                                  ('Base_RawRMSE_mV', 'Candidate_RawRMSE_mV', 'DeltaRaw_mV')]:
            require(abs(number(row, cand)-number(row, base)-number(row, delta)) < 1e-8,
                    'A7a time-domain change column mismatch')
        if row['EvidenceRole'] == 'Primary':
            change = number(row, 'DeltaComplex_mOhm')
            require(change < 0 if row['Frequency'] == '10tau' else change > 0,
                    'Primary frequency tradeoff differs from archived result')

    return {'archive_verification': 'PASS_FOR_PACKAGED_EVIDENCE',
            'matlab_or_simulink_executed': False,
            'manifest_files_verified': len(manifest['files']),
            'a8a_passed_checks': len(a_checks), 'a8b_passed_signal_checks': len(b_checks),
            'cases': case_result,
            'candidate_default_adoption': 'NOT_ADOPTED',
            'deployment_release': 'NOT_RELEASED',
            'scope': 'Archived 1 s constant-current record; no independent SOC truth validation.'}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1],
                        help='Repository/overlay root that contains docs, results and tools')
    args = parser.parse_args()
    try:
        result = verify(args.root)
    except (OSError, ValueError, KeyError, TypeError, csv.Error, json.JSONDecodeError) as error:
        print(f'ARCHIVE_VERIFICATION_FAILED: {error}', file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
