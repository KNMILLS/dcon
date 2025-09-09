# Test Suite Checklist

- [x] Add core utils: `tests/utils/test_assert.gd`, `tests/utils/test_report.gd`
- [x] Create unified runner: `tests/TestSuite.tscn`, `tests/test_suite.gd`
- [x] Integrate Milestone 0 tests: spawn, movement, camera binding, SubViewport
- [x] Add Milestone 1 tests: visor mode switching, glitch intensity vs memory pressure
- [ ] Wire CI headless run: `godot4 --headless --path . --quiet --scene res://tests/TestSuite.tscn`
- [ ] Publish JSON artifact: `user://test_report.json`
- [ ] Extend for M2+: add `_run_m2_*` sections and tests

Notes
- Prefer `user://` for reports.
- Keep logs quiet; reserve errors for FAIL.
- Tests should auto-quit and print one-line summary.
