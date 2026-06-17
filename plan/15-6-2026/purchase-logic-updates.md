Overview

This document describes the implementation of a Supplier Return System for the Small Convenience Store Inventory & Financial Management Application.

The purpose of this feature is to prevent inventory and financial data corruption caused by deleting or cancelling purchases after some of the purchased stock has already been sold.

Instead of deleting purchase records, the system will create a Supplier Return transaction that records stock being returned to the supplier while maintaining a complete audit trail.

Problem Statement
Current Situation

Example:

Purchase

Purchase Entry P001

Item	Quantity
Coke	100

Inventory:

Coke = 100
Sales

Sell 30 Coke.

Inventory:

Coke = 70
Cancel Purchase

If Purchase P001 is deleted:

Inventory = 0

or

Inventory = -30

This causes:

Incorrect inventory quantity
Incorrect financial reports
Broken sales history
Loss of audit records
Solution

Do not delete purchases.

Instead:

Keep the original purchase.
Create a Supplier Return transaction.
Deduct returned stock from inventory.
Record the financial value of returned goods.
Preserve complete transaction history.
Business Rules
Rule 1

Completed purchases cannot be deleted.

Completed Purchase
        ↓
      Locked
Rule 2

A Supplier Return must reference an existing Purchase Entry.

Example:

Supplier Return SR001
Reference Purchase: P001
Rule 3

Return quantity cannot exceed available stock.

Example:

Purchased: 100
Sold: 30
Current Stock: 70

Allowed:

Return 50
Return 70

Not Allowed:

Return 80
Return 100
Rule 4

Every return must create inventory movement records.

Inventory movement:

Purchase +100
Sales -30
Supplier Return -20

Current stock:

50
Rule 5

Original purchase records must remain unchanged.

Never modify:

purchase_entries
purchase_entry_items

after completion.

Database Design
supplier_returns

Stores supplier return headers.

Field	Type
id	INTEGER PK
return_date	TEXT
purchase_id	INTEGER FK
memo	TEXT
total_amount	REAL
status	TEXT

Example:

SR001
2026-06-15
P001
Damaged products
50.00
Completed
supplier_return_items

Stores returned items.

Field	Type
id	INTEGER PK
return_id	INTEGER FK
item_id	INTEGER FK
purchase_item_id	INTEGER FK
quantity	INTEGER
unit_cost	REAL
subtotal	REAL

Example:

Coke
20
2.00
40.00
Inventory Processing
Purchase
Purchase 100 Coke

Inventory:

+100
Sales
Sell 30 Coke

Inventory:

-30
Supplier Return
Return 20 Coke

Inventory:

-20

Remaining:

50
User Interface
Supplier Return List Screen

Display:

Supplier Returns
────────────────────

SR001
15/06/2026
RM 50.00

SR002
16/06/2026
RM 80.00

Functions:

Create Return
View Return
Delete Draft Return
Create Supplier Return Screen
Step 1

Select Purchase Entry

Purchase P001
15/06/2026
Step 2

Display Purchase Items

Coke
Purchased: 100
Available: 70

Bread
Purchased: 20
Available: 20
Step 3

Enter Return Quantity

Coke
Return: 20

Validation:

Return <= Available Quantity
Step 4

Save Return

System:

Create Supplier Return
Update Inventory
Create Inventory Movement
Financial Impact

Supplier Return decreases inventory asset value.

Example:

Purchase:
100 × RM2.00
= RM200

Return:

20 × RM2.00
= RM40

Inventory Value:

RM200 - RM40
= RM160
Audit Trail

Every transaction remains visible.

Example:

Purchase P001
+100

Sales S001
-30

Supplier Return SR001
-20

Current stock:

50

The system can always reconstruct inventory history.

Advantages
Data Integrity

No stock corruption.

Financial Accuracy

Inventory valuation remains correct.

Auditability

All actions are recorded.

Real-World Practice

Matches professional inventory systems such as:

SAP Business One
Oracle NetSuite
Odoo
QuickBooks Enterprise
Future Enhancements
Return Reasons
Damaged
Expired
Wrong Item
Supplier Recall
Overstock
Supplier Credit Notes

Record money owed back by supplier.

Partial Returns

Return part of a purchase multiple times.

Example:

Purchase 100

Return 20
Return 10
Return 15

Remaining = 55
Inventory Movement Ledger

Maintain a complete stock movement history.

Final Design Decision

The system will:

✅ Never delete completed purchases

✅ Use Supplier Returns to reverse stock

✅ Maintain inventory accuracy

✅ Maintain financial accuracy

✅ Preserve full audit trail

✅ Support partial and multiple returns

✅ Follow real-world inventory management practices used in professional business systems

and can build the inventory movement table already

Tracks all stock changes for audit and reporting.

**Table: `inventory_movements`**
- id
- item_id
- batch_id
- movement_type (e.g., PURCHASE, SALE, ADJUSTMENT)
- quantity
- unit_cost
- movement_date
- reference_type
- reference_id