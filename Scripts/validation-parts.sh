# shellcheck shell=sh disable=SC2034 # read by the scripts that source this file
# What each part of Scripts/validate-local.sh runs. That script reads these lists, and
# Scripts/verify-validation-parts.sh holds the repository to them, so a package, probe, test target or
# suite added later cannot be left out of every part unnoticed.
#
# packages   the Mac tests of mac_packages and mac_probes, the build of built_probes, the document and
#            Release checks, RenderCore's tests in the simulator and app_unit_test_target
# harness    the test targets of harness_probe
# ui-text    text_size_suites of app_screen_test_target
# ui-flows   every other suite of app_screen_test_target, then dark_suites again in dark appearance

mac_packages="FilmDomain MediaCatalog RenderFixtures RenderCore FilmPersistence NativeAdapters EntitlementCore FilmRuntime"
mac_probes="TrialCommitStudy DevelopmentProcessExit"
built_probes="AssetReviewGenerator"
harness_probe="PopulatedJournalHarness"
# Probes with their own commands and evidence, which validation has never run (each probe's README).
separate_probes="ExportPrivacyHarness LookReviewBoards NativeAdaptersCompileProbe ReceiptScenarioHarness SetupAccessibilityProbe TrialKeychainProbe"

harness_test_targets="PopulatedJournalHarnessTests"
app_unit_test_target="ImmerseTests"
app_screen_test_target="ImmerseUITests"
text_size_suites="ContentSizeTests"
dark_suites="JournalFlowTests MovieCapacityUITests FilmStockUITests LowStorageUITests"
