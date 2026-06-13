# 🏪 Small Convenience Store Inventory & Financial System

This project is a full-featured inventory and accounting system designed for a small convenience store. It manages inventory, purchases, sales, stock batches, and financial journal entries using a structured relational database.

---

## 📊 Database Overview

The system is built around inventory tracking, batch management, sales processing, and double-entry accounting.

---

## 📦 Core Modules

### 1. Inventory Management
Stores all product information.

**Table: `inventory_items`**
- id (Primary Key)
- name
- category
- selling_price
- low_stock_threshold

**Table: `inventory_categories`**
- name

---

### 2. Purchasing Module
Handles purchases and item receiving.

**Table: `purchase_entries`**
- id
- purchase_date
- memo
- total_cost

**Table: `purchase_entry_items`**
- id
- purchase_id
- item_id
- quantity
- unit_cost
- expiry_date

---

### 3. Stock Batch Tracking
Tracks stock received from each purchase for expiry and costing control.

**Table: `stock_batches`**
- id
- item_id
- purchase_item_id
- quantity
- remaining_qty
- unit_cost
- expiry_date
- received_at

---

### 4. Sales Module
Handles customer sales transactions.

**Table: `sales_entries`**
- id
- entry_date
- memo
- amount

**Table: `sales_entry_items`**
- id
- sales_id
- item_id
- quantity
- unit_price
- cost_of_goods_sold
- subtotal

---

### 5. Inventory Movement Log
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

---

### 6. Accounting System (Double Entry)

The system includes a basic accounting module using journal entries.

**Table: `journal_entries`**
- id
- entry_date
- memo
- total
- type

**Table: `journal_lines`**
- id
- entry_id
- account_id
- debit
- credit

**Table: `accounts`**
- id
- name
- type (Asset, Liability, Equity, Revenue, Expense)

---

## 🔄 System Workflow

### Purchase Flow
1. Create `purchase_entries`
2. Add items into `purchase_entry_items`
3. Generate `stock_batches`
4. Record `inventory_movements`
5. Create journal entry (inventory increase, cash/credit decrease)

---

### Sales Flow
1. Create `sales_entries`
2. Add items into `sales_entry_items`
3. Reduce `stock_batches` (FIFO recommended)
4. Record `inventory_movements`
5. Create journal entry:
   - Debit: Cash/Receivable
   - Credit: Sales Revenue
   - Record COGS (Cost of Goods Sold)

---

## 📌 Key Design Concepts

### ✔ Batch-Based Inventory
Each purchase creates a stock batch to track:
- expiry date
- unit cost
- remaining quantity

### ✔ FIFO Stock Management
Sales should deduct stock using FIFO (First In First Out).

### ✔ Audit Trail
All stock changes are recorded in `inventory_movements`.

### ✔ Double Entry Accounting
Every financial transaction is recorded using:
- journal_entries (header)
- journal_lines (debit/credit lines)

---

## 🚀 Future Improvements (Optional)

- Add financial reports (P&L, Balance Sheet)

---

## 🧑‍💻 Author
Built as part of a small convenience store inventory & financial management system project.