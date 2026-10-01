# Full Capacity Runtime Checkpoint 043

Continuation from checkpoint `b3948b1091b8942656629c9b8fe407d3c7b1c251`.
This checkpoint covers bounded package-level software behavior for full Camera
capacities and final Instant reveal using synthetic native media fixtures. It is
not hardware capture timing, physical storage-pressure, real camera save
recovery, iPhone 11 performance or full-v1 acceptance.

## Source Change

`FilmProcessorTests` now includes three capacity tests:

- Full Disposable 27 and 6x6 12 photo rolls persist every source, remain sealed
  at capacity, reject extra captures, and reveal every frame only after explicit
  Development.
- A full Instant 10 pack reveals exactly one newly saved print per Development
  pass, keeps earlier prints byte-stable, reveals the tenth/final print, never
  becomes roll-development eligible and rejects an eleventh exposure.
- Full Super 8 200-second and 16mm 165-second Movie Films persist exact consumed
  and remaining duration accounting, stay sealed before Development and reject
  over-budget clips after capacity is full.

## Executed Gate

Environment: macOS 26.6.2, Swift 6.3.2.

```sh
swift test --package-path Packages/FilmRuntime --filter 'FilmProcessorTests/testFull'
```

Initial result: build passed, three tests executed and failed on assertion shape.
The production/domain contract for an extra capture after full capacity is
`FilmDomainError.captureAlreadyComplete`, not `noRemainingExposures` or
`insufficientRemainingCapacity`. Assertions were updated to preserve that
contract.

Final result: three selected tests passed, zero failures:

- `testFullInstantPackRevealsFinalPrintIndividuallyAndRejectsEleventhExposure`
- `testFullMovieCapacitiesAreDurableAndRejectOverBudgetClips`
- `testFullPhotoRollCapacitiesStaySealedUntilExplicitDevelopment`

```sh
swift test --package-path Packages/FilmRuntime
```

Result after adding the capacity tests: 42 package tests passed, zero failures.

Relevant source hash:

| Source | SHA-256 |
| --- | --- |
| `Packages/FilmRuntime/Tests/FilmRuntimeTests/FilmProcessorTests.swift` | `088f2c1fb2e6ef2fda74bef3975764a8e54e55828195a8fbbec12f9fa64d1ecb` |

## Limits

These tests use repository/processor code and generated synthetic media. They do
not run native camera capture, AVFoundation callbacks, physical low-storage
paths, long-duration Movie rendering, iPhone 11 timing, real backup/restore or
device thermal/performance budgets. Exact physical-capacity rituals in
`Evidence/NativeApp/manual-validation.md` remain unaccepted.
