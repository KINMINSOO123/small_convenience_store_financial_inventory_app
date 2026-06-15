# UI Enhancement: Purchases, Sales, Expenses, Reports

## Design Principle
Same as inventory: **make key monetary values scannable by right-aligning them in the title row**, with secondary context in the subtitle. This creates a visual column of amounts that can be compared at a glance.

---

## 1. Purchases Screen (`purchases_screen.dart`)

### Current
```
[Receipt icon]  2026-06-15         [chevron]
               $59.88 [Active pill]
```
- Amount is inside subtitle mixed with a status badge
- Hard to compare totals across entries

### Proposed
```
[Receipt icon]  2026-06-15              59.88
               Active                  [chevron]
```
- **Title row**: date on the left, total amount right-aligned and bold (`titleMedium` + `fontWeight: w600`)
- **Subtitle**: status label ("Active" or "Cancelled") — plain text, no pill badge
- **Leading avatar**: cancelled purchases use `errorContainer`; active uses `primaryContainer`
- **Trailing**: keep chevron icon

### Specific changes to the ListTile (lines ~570-638):
- `title`: `Row` → `Expanded(child: Text(date))` + `Text(total, style: bold)`
- `subtitle`: `Text(statusLabel)` — simple text (remove the Row with dollar sign and Container status pill)
- `leading`: CircleAvatar background color = `errorContainer` if cancelled, `primaryContainer` if active
- `trailing`: `Icon(Icons.chevron_right)` (unchanged)

---

## 2. Sales Screen (`sales_screen.dart`)

### Current
```
[POS icon]  2026-06-15         [chevron]
            $59.88 · Sale
```
- Amount mixed with memo in subtitle
- No visual hierarchy between amount and context

### Proposed
```
[POS icon]  2026-06-15              59.88
            Sale memo              [chevron]
```
- **Title row**: date on the left, total amount right-aligned and bold
- **Subtitle**: memo text (or "Sale" if empty)
- **Trailing**: keep chevron

### Specific changes to the ListTile (lines ~406-437):
- `title`: `Row` → `Expanded(child: Text(date))` + `Text(total, style: bold)`
- `subtitle`: `Text(memo)` (remove the `$total · ` prefix)

---

## 3. Expenses Screen (`expenses_screen.dart`)

### Current
```
[Payments icon]  Rent · 1500.00         [⋮ menu]
                 2026-06-15 · Monthly
```
- Category and amount combined in one string in the title
- Hard to compare amounts across entries

### Proposed
```
[Payments icon]  Rent                  1500.00  [⋮ menu]
                  2026-06-15 · Monthly
```
- **Title row**: category on the left, amount right-aligned and bold
- **Subtitle**: date · memo
- **Trailing**: keep `PopupMenuButton` (⋮)

### Specific changes to the ListTile (lines ~357-402):
- `title`: `Row` → `Expanded(child: Text(category))` + `Text(amount, style: bold)`
- `subtitle`: `Text('$dateStr · $memo')`
- `trailing`: keep existing `PopupMenuButton`

---

## 4. Reports Screen (`reporting_screen.dart`)

### Current `_ReportList` items:
- `trailing: Text(line.total.toStringAsFixed(2))` — uses default text style
- Amount is right-aligned but not visually prominent

### Proposed
- Change trailing text style to `titleMedium` with `fontWeight: FontWeight.w600` for consistency

### Specific change (line ~639):
```dart
trailing: Text(
  line.total.toStringAsFixed(2),
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w600,
  ),
),
```

---

## Files to Modify

| File | Change |
|------|--------|
| `lib/screens/purchases_screen.dart` | Restructure purchase ListTile: bold right-aligned total, status as plain subtitle text, cancelled avatar uses errorContainer |
| `lib/screens/sales_screen.dart` | Restructure sale ListTile: bold right-aligned total, memo as subtitle |
| `lib/screens/expenses_screen.dart` | Restructure expense ListTile: bold right-aligned amount, category + date restructured |
| `lib/screens/reporting_screen.dart` | Bold trailing amount in `_ReportList` |

## Implementation Order

1. Purchases screen
2. Sales screen
3. Expenses screen
4. Reports screen
5. Run `flutter analyze`