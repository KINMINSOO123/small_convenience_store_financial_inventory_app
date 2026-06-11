# Convenience Store Financial & Inventory Management System

## Overview

This project is a cross-platform financial and inventory management application designed for small convenience stores. It helps shopkeepers manage stock, record purchases, track expenses, and generate monthly financial statements in a simple and efficient way.

The system is built using Flutter, allowing deployment on both Android devices and Windows 11 computers. It operates offline using a local SQLite database and supports manual data synchronization between devices.

---

## Key Features

### Inventory Management

* Add and manage product records manually
* Track product quantity and original purchase cost
* Categorize products for easy filtering
* Monitor product expiry dates
* FIFO (First-In First-Out) inventory tracking

### Financial Management

* Double-entry bookkeeping system
* Record purchase transactions
* Track inventory costs and expenses
* Maintain financial consistency and accuracy

### Reporting

* Generate monthly financial statements
* View profit and loss summaries
* Inventory valuation reports
* Expiry date monitoring reports

### Cross-Platform Support

* Android application (APK installation)
* Windows 11 desktop application
* Offline-first system (no internet required)

---

## Technology Stack

* Framework: Flutter
* Language: Dart
* Local Database: SQLite
* IDE: Visual Studio
* Platforms:

  * Android
  * Windows 11

---

## Database System

The application uses a local SQLite database stored directly on the user’s device.

### Why SQLite?

* Lightweight and fast
* Works offline
* No server required
* Reliable for financial and inventory data

Each device maintains its own independent database file.

---

## Data Synchronization

The system uses **manual synchronization** between devices.

### How It Works:

1. Export data from Device A (JSON or database file)
2. Transfer file via USB, cloud storage, or messaging apps
3. Import data into Device B

### Advantages:

* Simple to implement
* No internet required
* Full user control over data transfer

---

## System Workflow

1. Shopkeeper adds product purchase entries manually
2. System records:

   * Product details
   * Quantity
   * Cost price
   * Expiry date
3. Inventory is updated using FIFO method
4. Financial transactions are recorded using double-entry accounting
5. Monthly financial reports are generated

---

## FIFO Inventory Method

The system uses FIFO (First-In First-Out) to manage inventory costs.

* Older stock is assumed to be sold first
* Ensures accurate cost tracking
* Helps calculate real profit margins

---

## Double-Entry Accounting

Each financial transaction includes:

* Debit entry
* Credit entry

This ensures that all accounts remain balanced and accurate.

---

## Installation

### Android Installation

1. Copy APK file to Android device
2. Enable “Install from Unknown Sources”
3. Install the application
4. Open and start using

### Windows Installation

1. Run the installer or executable file
2. Follow installation steps
3. Launch application from desktop or start menu

---

## Target Users

* Small convenience store owners
* Mini market operators
* Small retail business owners
* Shopkeepers needing simple accounting and inventory tools

---

## Benefits

* Easy to use for non-technical users
* Works fully offline
* Reduces manual bookkeeping errors
* Helps track stock and expiry dates
* Provides monthly financial insights
* Low-cost solution for small businesses

---

## Future Improvements

* Barcode scanning support
* Cloud backup and optional synchronization
* Multi-user access system
* Sales point-of-sale (POS) module
* Advanced analytics dashboard
* Automatic financial reporting improvements

---

## Conclusion

This system provides a simple yet powerful solution for small convenience store management. By combining inventory tracking, FIFO valuation, double-entry accounting, and financial reporting, it helps shopkeepers manage their business efficiently using only a mobile phone or Windows computer.
