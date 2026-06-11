# Inventory Add-Item Proposed Solution

## Goal
Fix the inventory flow where tapping **Add item** inside a category and submitting the form does not add the item.

## Proposed solution
1. Normalize the category and product name before saving so whitespace does not create a mismatch between the selected category and the stored category.
2. Keep the add-item validation strict enough to block empty or invalid values, but avoid rejecting a valid category because of casing or trailing spaces.
3. Make the save path surface the real failure instead of hiding it behind a generic snackbar.
4. Refresh the inventory state after the save attempt so the UI reflects the newest data immediately.
5. If the save partially succeeds, treat it as success instead of showing a false error message.

## Expected behavior after the fix
- Pressing **Add item** inside a category saves the item successfully.
- The item appears in the selected category after submission.
- No false error snackbar appears for a successful save.
- The selected category stays stable even if the stored value has whitespace or case differences.

## Implementation approach
- Update `lib/screens/inventory_screen.dart` to use the trimmed selected category when opening the add-item dialog.
- Update `lib/services/inventory_service.dart` to trim item name and category before inserting.
- Update `lib/controllers/inventory_controller.dart` to notify listeners even if the service throws after a partial save.
- Keep the fix narrow and local to the actual add-item path.

## Verification
1. Add a new item from a category.
2. Confirm the item appears in the list immediately after save.
3. Confirm no error snackbar appears for a valid item.
4. Run analyzer checks on the touched files.