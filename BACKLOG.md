# Backlog

- [x] Remove template Item.swift and any references
- [x] Review NutritionCalculator (totals, remaining, negative remaining, zero entries)
- [ ] Blocked: Unit tests for NutritionCalculator
- [x] Sample data and previews for every main screen
- [x] Edit and delete food entries
- [x] Date picker on home screen to view and log past days
- [x] "Save as meal" from a food entry
- [x] Log a saved meal with a quantity multiplier
- [x] Search on Saved Meals
- [x] Input validation and number keyboards
- [x] Calorie ring and macro progress bars on home screen
- [x] Group entries by meal type with subtotals
- [x] Empty states
- [x] Dark mode and Dynamic Type check on all screens

## Bugs

- [x] Number pad keyboard can't be dismissed anywhere in the app. Add a "Done" button above the keyboard on every number field, and let tapping outside or scrolling dismiss it
- [x] Settings: after editing a daily goal there's no clear way to finish and get back to the normal screen. Add a clear save/done flow
- [x] Settings: goal fields have no labels. Label each one (Calories, Protein, Carbs, Fat) with units (kcal, g)
- [x] Tapping a saved meal to log it gives no feedback. Add a short confirmation (e.g. checkmark animation or banner, plus a light haptic)

## New Feature: Saved Foods

- [x] New "Saved Foods" section alongside Saved Meals
- [x] A saved food stores nutrition per 100g: calories, protein, carbs, fat. Optionally also a serving size in grams
- [x] Add a food by taking a photo of a nutrition label, or picking one from the photo library
- [x] Use Apple's on-device Vision text recognition to read the label, then parse the values in Swift (not with a model)
- [x] Always show the parsed values in an editable form so I can fix mistakes before saving
- [x] Also allow adding a food manually without a photo
- [x] When logging a saved food, I enter the grams I ate and the app scales the nutrition from the per 100g values
- [x] Add the camera and photo library usage descriptions needed for permissions
- [ ] Blocked: Add unit tests for the label parsing (use sample label text) and the gram scaling maths

## Label Scanning Phase 2a

- [x] Pass camera/photo image orientation to Vision
- [x] Keep recognitionLevel .accurate and language correction off
- [x] Return Vision OCR observations with bounding boxes and confidence
- [x] Reconstruct rows and columns from text positions before parsing
- [x] Prefer per 100g values when serving columns are also present
- [x] Add raw OCR text and reconstructed rows debug section to review screen
- [ ] Blocked: Convert sample labels into real Cmd+U tests after a unit test target exists

## Label Scanning Phase 2b

- [x] Add strict JSON result type for Qwen OCR cleanup
- [x] Add prompt builder that tells Qwen to use per 100g only and never serving columns
- [x] Add Swift JSON parser for Qwen response
- [x] Wire scan flow to try AI extraction hook before falling back to layout parser
- [x] Add MLX Swift packages and connect local Qwen runtime
- [x] Add Qwen3-1.7B-4bit folder reference to app bundle resources
- [x] Connect Qwen to Assistant tab with Swift-built app context
- [ ] Blocked: Use MLXGuidedGeneration for forced label JSON output when the package/product is available
