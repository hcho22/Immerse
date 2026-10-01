# Preparation Observations

Native simulator build and the first hosted/UI runs passed without changing their
source or assertions. The following preparation issues are retained separately:

- A read-only `simctl get_app_container` after unit-1 had already completed and
  shut down the owned simulator returned state Shutdown/code 405. No restart was
  needed; the runner had retained the scenario directories before shutdown.
- Xcode's UI launch log repeatedly reports debugger-version snapshot StoreError
  0 / no debugger version. Both tests actually executed and passed; the warnings
  are retained and not described as warning-free execution.
- First offline UI inspection failed at line 50 comparing DevelopmentRun:
  completedSequences `[1,2]` versus `[2,1]`. That field is a Swift Set, not ordered
  chronology. The comparison now normalizes only this set's order; raw snapshots
  remain untouched. Film capture chronology and treatment assignments still
  require full equality.
- That inspection also exposed JavaScript JSON Number precision loss for UInt64
  seeds. The checker now uses macOS Ruby's standard JSON parser to retain integers,
  converting only values outside JavaScript's safe-integer range to exact decimal
  strings. No regex JSON parser or rounded seed comparison is used for final
  evidence. This is offline inspection tooling, not native source or media changes.
- Boot transcripts had terminal trailing whitespace. The readable `boot.log`
  copies normalize only that whitespace; `boot.log.raw.gz` preserves the exact
  original bytes beside each copy.

Ordinary `_exit(79)` and injected writer errors remain distinct from physical
power loss or PhotoKit failure. No failed physical criterion was converted to a
pass; missing native permissions/Photos/device capabilities remain untested.
