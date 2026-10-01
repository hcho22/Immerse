# Film Runtime

`FilmProcessor` owns native Development, editing, explicit export and removal.
The ordinary app constructs `FilmProcessor(root:)`. Trial/capture serialization
is separately owned by `TrialCoordinator`; these Development hooks do not alter it.

## Development Observation

The optional `developmentObserver` initializer argument is absent by default.
Every callback and its post-suspension cancellation check is inside `if let
observer`; the default path has no observer await, logging, persistence or job.
No shipping setting or launch argument installs one.

`DevelopmentStage` names five existing phases: before begin, after durable
assignments, after rendering before persistence, after persisted master/clip,
and before reveal/cleanup. The last distinguishes an individual Instant reveal,
whole-Film reveal and source cleanup. Rendering/persistence callbacks occur only
for newly produced master/clip assets, not already-persisted ones. The Movie
assembly is not an additional checkpoint. Standalone export/cleanup operations
do not acquire an observer; the hooks belong only to the Development worker.

An observer may suspend or throw. After it returns, cancellation is checked
before the next side effect. The existing owner propagates errors and retires
its job/removal guard. Persisted assignments/media survive; a thrown callback is
not a transaction rollback. In particular, before source cleanup the reveal may
already be durable. Discard-driven reassembly has already removed its old private
Movie before its Development observer can run. Callers must recover/retry using
the same durable repository; never interpret an exception as restoring deletion.

Observation is a test integration boundary, not a generalized task-state API.
No gate can make native permission, export, capture or physical retention pass.

## Affected Checks

```sh
swift test --package-path Packages/FilmRuntime --filter 'DevelopmentObserverTests|FilmProcessorTests|FilmExportTests|SoundtrackTests'
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/ExportPrivacyHarness/run-simulator.sh development UNIQUE-LABEL
```

Use only an explicitly authorized, initially stopped simulator. The second
command hosts the package's same observer tests in the separate non-shipping
ExportPrivacyHarness target; it does not install the shipping app or call Photos,
Security, Camera, microphone, StoreKit or network. Native generated media and
snapshots remain under that harness's Documents/DevelopmentScenarios and are
copied into the run's evidence. XCTest asserts native decode/hash results.
Read `Evidence/DevelopmentObserver/036/` for current results and missing evidence.
