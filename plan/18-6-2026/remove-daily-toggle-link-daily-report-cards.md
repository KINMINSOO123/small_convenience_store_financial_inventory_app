Remove Daily Toggle & Link Daily Report Cards
===============================================

Current State
-------------
- `ReportingScreen` has a Daily/Monthly toggle (`_showDaily` state)
- Tapping "Daily" replaces the entire screen with `_buildDailyBody()` — an
  inline P&L summary, sales breakdown, top sellers, expenses, and inventory
  alerts
- `_buildDailyBody()` has "View Full Report" buttons that navigate to
  `DailyReportDetailScreen`
- The monthly view has a "Daily reports" section with `_DailyReportList` —
  expandable cards per day showing sales/expenses/profit summary
- `_DailyReportList` cards only expand inline; they don't navigate to the
  detail screen
- `DailyReportDetailScreen` already accepts `initialDate` and has its own
  date picker, CSV/PDF export, and WhatsApp share
- `daily_report_screen.dart` was already deleted (orphan, not wired anywhere)

Problem
-------
The Daily toggle view (`_buildDailyBody`) and `DailyReportDetailScreen`
overlap significantly — both show P&L summary, sales breakdown, expenses,
inventory alerts. The inline daily view is redundant since the detail screen
already has everything plus export/share.

Goal
----
Remove the Daily toggle and inline daily body entirely. Instead, make each
Card in `_DailyReportList` tappable so it navigates directly to
`DailyReportDetailScreen` with that day's date as `initialDate`.


Phase 1: Remove the Daily toggle and _buildDailyBody
------------------------------------------------------

In `lib/screens/reporting_screen.dart`:

1. Remove the `_showDaily` state variable (line 45):
   `bool _showDaily = false;`

2. Simplify the header Row — remove the Daily/Monthly toggle button
   (lines 88-98). Keep only the "Reporting" title text.

3. Remove the conditional rendering in `build()`:
   - Line 66: `if (_showDaily) { return _buildDailyBody(context); }`
   - Line 319: `if (_showDaily) _buildDailyBody(context),`

4. Remove these methods entirely:
   - `Widget _buildDailyBody(BuildContext context)` (lines 328-474)
   - `Widget _dailySection(String title, List<Widget> children)` (lines 477-494)
   - `Widget _pnlRow(...)` (lines 497-522)
   - `String _fmt(double value)` (line 525)
   - `void _openDailyDetail()` (lines 527-538)

5. Remove the `import 'daily_report_detail_screen.dart';` (line 17)
   — navigation will be handled by `_DailyReportList` via a callback
   instead of a direct import in this class.

Files: lib/screens/reporting_screen.dart (modify)


Phase 2: Make _DailyReportList cards navigate to DailyReportDetailScreen
-------------------------------------------------------------------------

In `lib/screens/reporting_screen.dart`, modify the `_DailyReportList` widget:

1. Add an `onTap` callback parameter:
   `final void Function(DateTime date)? onTap;`

2. Wrap each Card (or ExpansionTile) with `InkWell` so tapping the card
   calls `onTap?.call(report.date)`.

3. In `_ReportingScreenState`, pass `onTap` that navigates:
   ```
   onTap: (date) {
     Navigator.of(context).push(
       MaterialPageRoute(
         builder: (_) => DailyReportDetailScreen(
           inventoryController: _inventoryController,
           purchaseController: _purchaseController,
           expensesController: _expensesController,
           salesController: _salesController,
           supplierReturnController: _supplierReturnController,
           initialDate: date,
         ),
       ),
     );
   },
   ```

4. Re-add the `import 'daily_report_detail_screen.dart';` at the top
   (since it's now needed for navigation from `_DailyReportList` usage).

The import was removed in Phase 1 because `_openDailyDetail` was removed,
but now it's needed again for the `onTap` callback.

Design decision: Use a callback rather than passing controllers directly
to `_DailyReportList` to keep the widget decoupled from the detail screen.

Files: lib/screens/reporting_screen.dart (modify)


Phase 3: Cleanup
-----------------

1. Verify `daily_report_screen.dart` no longer exists (already deleted).

2. Remove unused `_fmt` method if it was only used by `_buildDailyBody`
   and `_pnlRow`. Check if `_formatDate` is still needed (it's used by
   `_DailyReportList` and CSV/PDF export methods, so it stays).

3. Run `flutter analyze` to confirm no errors.

Files: lib/screens/reporting_screen.dart (verify)


Implementation Order
--------------------
1. Phase 1: Remove Daily toggle, _showDaily, _buildDailyBody, _dailySection,
   _pnlRow, _fmt, _openDailyDetail
2. Phase 2: Add onTap callback to _DailyReportList, wire navigation
3. Phase 3: Verify build and analysis


Summary of Files to Modify
----------------------------
| File | Change |
|------|--------|
| lib/screens/reporting_screen.dart | Remove Daily toggle + inline daily body; add onTap navigation from _DailyReportList cards to DailyReportDetailScreen |

No new files created. No changes to daily_report_detail_screen.dart,
home_shell.dart, or reporting_service.dart.