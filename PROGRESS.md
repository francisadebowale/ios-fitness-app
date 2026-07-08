# Progress

## Done

- Removed template Item.swift and references: searched the Xcode project and found no Item.swift files or references to remove.
- Reviewed NutritionCalculator: totals now explicitly start at zero, remaining values intentionally allow negatives when over goal, and progress helpers guard against zero goals.
- Added in-memory sample data for SwiftUI previews.
- Added previews for the main screens, including dark mode and large Dynamic Type variants.
- Added date selection on Home so past days can be viewed.
- Added date selection on Log Food so food can be logged for past days.
- Added food entry editing from Home by tapping an entry.
- Added food entry deletion from Home and from the edit sheet.
- Added Save as Meal from the food entry editor.
- Added saved meal quantity multiplier and Swift-only macro scaling when logging a saved meal.
- Added search to Saved Meals.
- Added input validation for required names and non-negative nutrition values.
- Added conditional number/decimal keyboard hints for iOS while keeping the macOS build green.
- Added calorie ring and macro progress bars on Home.
- Grouped Home entries by meal type with calorie subtotals.
- Added reusable empty states across Home, Saved Meals, Settings, and Assistant.
- Added a keyboard Done button for number fields in Log Food, Edit Food, Saved Meals, and Settings.
- Added keyboard dismissal by scrolling and tapping outside numeric fields.
- Reworked Settings into a goal summary plus explicit Edit Goals, Save, and Cancel flow.
- Labeled Settings goal fields with Calories, Protein, Carbs, Fat and kcal/g units.
- Added saved meal logging feedback with a short checkmark banner and light iOS success haptic.
- Added SavedFood SwiftData model and registered it in the app model container.
- Added Saved Foods inside the Meals tab behind a segmented Meals/Foods picker.
- Added a context-aware + button: Meals opens a saved meal form; Foods offers Scan Label, Choose Photo, and Enter Manually.
- Added camera/photo picker flow for nutrition labels on iOS.
- Added local Vision OCR via VNRecognizeTextRequest.
- Added Swift-only nutrition label parser with missing-field reporting, "of which" row skipping, kcal preference, nearby-line value handling, comma decimal support, and sanity warnings.
- Added editable Saved Food review screen with missing values highlighted and Retake / Enter Manually handling for poor scans.
- Added Saved Food gram logging with Swift-only per-100g scaling.
- Added camera and photo library usage descriptions to target Info build settings.
- Phase 2a: updated Vision OCR to pass image orientation from camera/photo images.
- Phase 2a: confirmed OCR uses .accurate recognition and language correction remains off.
- Phase 2a: added OCR observation capture with text, bounding box, and confidence.
- Phase 2a: added layout parser that reconstructs rows from text positions and prefers per-100g columns before falling back to plain text parsing.
- Phase 2a: added a Debug section on Saved Food review with parser name, raw OCR text, and reconstructed rows.
- Phase 2b: added Qwen OCR-cleanup prompt builder, strict JSON result type, and Swift JSON parser.
- Phase 2b: wired scan flow to try the AI extraction hook, then fall back to the layout parser.
- Added bundled local Qwen loading through MLX from the app resource folder `Qwen3-1.7B-4bit`, with no network download path.
- Connected Qwen OCR cleanup to the saved-food label scanner.
- Connected the Assistant tab to local Qwen with Swift-built context for goals, totals, remaining values, entries, saved meals, and saved foods.

## Tested

- Built successfully after removing/checking Item.swift.
- Built successfully after NutritionCalculator review.
- Built successfully after the feature batch.
- Build-for-testing succeeded, but no test target is exposed in the project structure.
- Built successfully after the four bug fixes.
- Build-for-testing succeeded after the four bug fixes.
- Built successfully after Saved Foods and scan pipeline work.
- Build-for-testing succeeded after Saved Foods and scan pipeline work.
- Ran Xcode snippet verification for label parser samples A, B, C, D, E and 45g scaling; all checks passed.
- Built successfully after Phase 2a OCR/layout changes.
- Ran Xcode snippet verification for samples A-E, 45g scaling, and synthetic per-100g/serving column layout; all checks passed.
- Build-for-testing succeeded after Phase 2a OCR/layout changes.
- Built successfully after Phase 2b extraction plumbing.
- Ran Xcode snippet verification for Qwen JSON response parsing and prompt generation; checks passed.
- Build-for-testing succeeded after Phase 2b extraction plumbing.
- Built successfully after local Qwen runtime wiring for label cleanup and Assistant.
- Build-for-testing succeeded after local Qwen runtime wiring.
- Active test plan still reports 0 tests.

## Needs Francis

- Add or expose a real unit test target so NutritionCalculator, NutritionLabelParser, and SavedFoodCalculator tests can be added as XCTest/Testing tests. The available project currently has only the app target and 0 tests in the active test plan.
- Suggested Xcode steps: File > New > Target > iOS Unit Testing Bundle, name it `MyFitnessPal DupeTests`, set host application to `MyFitnessPal Dupe`, add it to the active scheme/test plan, then tell me and I will add the real sample-label tests.
- Preview capture tooling is not currently exposed in the available Xcode tools. I added preview variants and verified the project builds, but could not capture screenshots for visual inspection.
- MLXGuidedGeneration is not currently visible in the project/package symbols or linked products, so label cleanup uses strict prompting plus Swift JSON parsing and validation for now.

## Blocked

- Unit tests for NutritionCalculator: blocked by missing test target / unavailable test target.
- Unit tests for NutritionLabelParser and SavedFoodCalculator: blocked by missing test target. Parser/scaling behavior was verified with Xcode RunCodeSnippet instead.
- Phase 2a sample label tests as real Cmd+U tests: blocked by missing unit test target.
- Forced JSON decoding with MLXGuidedGeneration: blocked because no `MLXGuidedGeneration` APIs/products are visible in the current project dependencies.

