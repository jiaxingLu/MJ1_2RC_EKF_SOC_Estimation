# A8c repository artifact correspondence

Base commit: 282965ea083d37bc0f3c7392a454880f3beb0c90

The integration check compared the following repository artifacts with the uploaded A8a snapshot before copying documentation. No estimator, MAT or SLX was replaced.

| Repository path | Check | SHA-256 |
|---|---|---|
| matlab/mj1_ekf_step.m | UTF-8 text; BOM removed and CRLF/CR mapped to LF only | 608256c02b3dc9028d0be81ad103ffb07b08adadb9be7c16a33928df58504b6f |
| matlab/mj1_interp_params.m | UTF-8 text; BOM removed and CRLF/CR mapped to LF only | edeb49fa31efcfc86c442168c15207f1d4747a2ef8fe5e39b135f04c329b66b6 |
| matlab/mj1_state_transition.m | UTF-8 text; BOM removed and CRLF/CR mapped to LF only | 52483c56117b9acbb222ea34fbef28d5000ae3b451e45be44aeb7b67e68d1ddb |
| matlab/mj1_F_jacobian.m | UTF-8 text; BOM removed and CRLF/CR mapped to LF only | d03a808a31e31a7bc6500feaa659189be3b14c922549d9105f84f8355bd42efa |
| matlab/mj1_H_jacobian.m | UTF-8 text; BOM removed and CRLF/CR mapped to LF only | 3aafdf706795f1c4ef80ce212464a52721a97a027060191e78c77296c2f12781 |
| matlab/mj1_measurement.m | UTF-8 text; BOM removed and CRLF/CR mapped to LF only | 71dffec818cfb71dc09897ee7aa642156404ce98da24f0da3fe28969a3054941 |
| data/mj1_v02_model.mat | exact file bytes | de065506094efbc731a0b7530b2b953d0c52d08b7c0ff483a7195b8e2d27b0ec |
| data/mj1_holdout_50to17.mat | exact file bytes | dec9f1406916924598664bbcd72f6ca78daa6ae22c0837c39a60a92d001cdc9d |
| model/MJ1_2RC_EKF_v02_S2_Final.slx | exact file bytes | da96ed2f14521ac3f5fcdc805640a2eff8e4dc87acb9ede25fe5167ad104b2b0 |

This is file correspondence, not a fresh MATLAB/Simulink execution, certification of every dependency, or a clean-clone runtime test. Relocating the runner or changing its paths requires a separate runtime check.

The existing A8c manifest remains unchanged. Its CSV entries include CRLF bytes, so scoped Git attributes disable newline conversion for that evidence directory. The verifier is kept as LF text. Archived statuses and numeric results are not rewritten.
