# Project Roadmap & Planning

This directory contains detailed implementation plans for upcoming features and bug fixes.

## Current Focus: Core Reliability
We are currently focusing on fixing critical flow issues in the inventory management system.

- **[SQL NOT NULL Constraint Fix](./sql-not-null-constraint-plan.md)**: Resolving the SQLite constraint error during item addition.
- **[Inventory Add-Item Flow](./inventory-add-item.md)**: Improving the UX and data normalization for adding items.

## Upcoming Milestones

### 1. Financial MVP Enhancements
- **Expenses MVP**: Implementation of a dedicated screen and service for tracking store expenses.
- **Double-Entry Validation**: Strengthening the journal entry system to ensure financial consistency.

### 2. Data Portability & Sync
- **CSV Export/Import**: Finalizing the CSV workflows for inventory and sales data.
- **FIFO Export/Import**: Ensuring purchase history (batches) can be moved between devices while maintaining FIFO integrity.

### 3. Inventory Intelligence
- **Expiry Date Sync**: Implementing logic to sync item-level expiry dates with the earliest available batch expiry.
- **Low Stock Thresholds**: Refining how low stock is calculated and displayed across the app.

## How to use these plans
1. **Review**: Read the `.md` file for the specific feature you are working on.
2. **Execute**: Follow the "Planned steps" or "Implementation approach" section.
3. **Verify**: Use the "Verification" or "Success criteria" to ensure the task is complete.
4. **Update**: Once a plan is fully implemented, move it to a `completed/` folder (if created) or mark it as done in this README.

---
*Last Updated: 2026-06-10*
