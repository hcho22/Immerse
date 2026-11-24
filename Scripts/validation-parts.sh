# shellcheck shell=sh disable=SC2034 # read by the scripts that source this file
# What each part of Scripts/validate-local.sh runs. That script reads these lists, and
# Scripts/verify-validation-parts.sh holds the repository to them, so a package, probe, test target or
# suite added later cannot be left out of every part unnoticed.
#
# packages   the Mac tests of mac_packages and mac_probes, the build of built_probes, the document and
#            Release checks, the v2 backend's tests (backend), RenderCore's tests in the simulator and
#            app_unit_test_target
# harness    the test targets of harness_probe
# ui-text    text_size_suites of app_screen_test_target
# ui-flows   every other suite of app_screen_test_target, then dark_suites again in dark appearance
# mini-app   the App Clip's size against Apple's cap (Scripts/verify-app-clip-size.sh) and mini_app_screen_test_target

mac_packages="FilmDomain MediaCatalog RenderFixtures RenderCore FilmPersistence NativeAdapters EntitlementCore FilmRuntime ImmerseServer"
# The v2 backend (Backend/README.md): its Convex function tests against the local stand-ins, then the same functions
# end to end on Convex's own local backend. Both need Node and MinIO.
backend="Backend"
mac_probes="TrialCommitStudy DevelopmentProcessExit"
built_probes="AssetReviewGenerator"
harness_probe="PopulatedJournalHarness"
# Probes with their own commands and evidence, which validation has never run (each probe's README).
separate_probes="ExportPrivacyHarness LookReviewBoards NativeAdaptersCompileProbe ReceiptScenarioHarness SetupAccessibilityProbe TrialKeychainProbe"

harness_test_targets="PopulatedJournalHarnessTests"
app_unit_test_target="ImmerseTests"
app_screen_test_target="ImmerseUITests"
text_size_suites="ContentSizeTests"
dark_suites="JournalFlowTests MovieCapacityUITests FilmStockUITests LowStorageUITests HostingUITests"
# The mini-app (v2 Stage 3): the App Clip's own scheme and its screen tests, whose sources are mini_app_screen_tests.
mini_app_scheme="ImmerseClip"
mini_app_screen_test_target="ImmerseClipUITests"
mini_app_screen_tests="App/Immerse/ClipUITests"
