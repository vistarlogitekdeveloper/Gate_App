# Gate Entry & Reconciliation System - Backend API Specification

This document outlines the REST APIs required by the Flutter Cross-Platform application to function. The data models defined here represent the expected properties of JSON requests and responses.

## General Guidelines
- **Base URL**: `/api/v1`
- **Authentication**: Bearer JWT Tokens passed in the `Authorization: Bearer <token>` header.
- **Paging**: List endpoints should support standard pagination `?page=X&limit=Y` and return total records.
- **Response wrapping**: Ensure responses adhere to a consistent predictable standard format (e.g. `{"success": true, "data": { ... }, "error": null, "message": "..."}`).

---

## 1. Authentication & Users

### 1.1 User Login
Authenticates user and returns JWT + Role details. Roles are heavily used by the frontend for UI Guarding (RBAC).
- **URL**: `POST /auth/login`
- **Request Body**:
  ```json
  {
    "username": "admin",
    "password": "password123",
    "role": "admin" // Development/mock parameter (optional in prod)
  }
  ```
- **Response**:
  ```json
  {
    "token": "jwt_token_here",
    "userId": "U-101",
    "username": "admin",
    "role": "admin" // enum: "gate_security", "warehouse_executive", "warehouse_manager", "admin"
  }
  ```

---

## 2. Gate Entry Module

### 2.1 Get Gate Entries
Fetches list of active and past gate entries, with optional filters.
- **URL**: `GET /gate-entries`
- **Query Params**: `page, limit, status, startDate, endDate`
- **Response**: List of `GateEntry` objects.

### 2.2 Create Gate Entry
Creates a new Gate Entry. Called by `gate_security` user.
- **URL**: `POST /gate-entries`
- **Request Body**:
  ```json
  {
    "challanNumber": "CH-1002",
    "vendorName": "Acme Corp",
    "vehicleNumber": "MH-12-AB-3456",
    "poNumber": "PO-9921",
    "gateDirection": "Gate In", // enum: "Gate In", "Gate Out"
    "materialCode": "MAT-A123", // Selected from Master Data / SAP
    "quantity": 50.0,
    "transporterName": "Fast Logistics",
    "attachmentFileName": "invoice.pdf" // Optional
  }
  ```
- **Response**: Returns created `GateEntry` object.
  ```json
  {
    "id": "GE-1001",
    "challanNumber": "CH-1002",
    "vendorName": "Acme Corp",
    "vehicleNumber": "MH-12-AB-3456",
    "poNumber": "PO-9921",
    "gateDirection": "Gate In",
    "materialCode": "MAT-A123",
    "quantity": 50.0,
    "transporterName": "Fast Logistics",
    "attachmentFileName": "invoice.pdf",
    "entryTime": "2026-03-01T10:30:00Z",
    "status": "Pending", // enum: "Pending", "Matched", "Exception"
    "createdBy": "security_guard_1"
  }
  ```

---

## 3. Reconciliation Module

### 3.1 Get Exceptions (Pending Reconciliation)
Retrieves the list of generated discrepancies/exceptions during the auto-match engine process between SAP and Gate Entry.
- **URL**: `GET /reconciliation/exceptions`
- **Response**:
  ```json
  [
    {
      "id": "EXC-5521",
      "gateEntryId": "GE-1005",
      "poNumber": "PO-9921",
      "status": "Quantity Mismatch", 
      // Categories: "Quantity Mismatch", "Wrong PO/Material GRN", "Duplicate GRN Detected", "GRN Not Posted", "Pending GRN", "Resolved"
      "description": "Challan quantity (150) exceeds allowed SAP PO quantity (100).",
      "createdAt": "2026-03-01T11:00:00Z",
      "resolvedAt": null,
      "resolvedBy": null
    }
  ]
  ```

### 3.2 Resolve Exception
Warehouse Manager resolves a pending exception (e.g. adjusts quantity, contacts vendor).
- **URL**: `POST /reconciliation/exceptions/:id/resolve`
- **Request Body**:
  ```json
  {
    "resolutionNotes": "Vendor accidentally shipped 50 extra. Adjusted in SAP to match."
  }
  ```
- **Response**: Updated `RecoException` object marking Status as "Resolved".

---

## 4. Dashboard & Metrics

### 4.1 Get Dashboard Statistics
Powers the main Dashboard overview for the Admin/Manager.
- **URL**: `GET /dashboard/metrics`
- **Response**:
  ```json
  {
    "totalGateEntriesToday": 14,
    "totalGateEntriesMonth": 342,
    "totalGrnPosted": 10,
    "pendingGrnCount": 3,
    "quantityMismatchCases": 1,
    "duplicateGrnCases": 0,
    "gateTat": 15, // in minutes
    "dockTat": 45, // in minutes
    "pendingGrnAging0To1": 2,
    "pendingGrnAging2To3": 1,
    "pendingGrnAgingMoreThan3": 0,
    "recentActivity": [ // Array mapping trailing 7 days
      { "day": "Mon", "entriesCount": 12 },
      { "day": "Tue", "entriesCount": 15 }
    ]
  }
  ```

---

## 5. Reports

### 5.1 Generalized Report Queries
Used to populate DataTables before exporting to Excel/PDF.
**URL Params for all reports:** `?startDate=X&endDate=Y&vendor=Z&poNumber=P`

- **Gate Entry Register**: `GET /reports/gate-entry`
  - Array containing properties: `gateEntryNo, date, vendor, poNumber, vehicleNo, material, status`
- **GRN Reconciliation Report**: `GET /reports/grn-recon`
  - Array containing properties: `gateEntryNo, grnNo, poNumber, challanNo, matchedStatus, quantityDiff`
- **Pending GRN Report**: `GET /reports/pending-grn`
  - Array containing properties: `gateEntryNo, poNumber, vendor, material, daysPending`
- **Audit Trail Report**: `GET /reports/audit-trail`
  - Array containing properties: `date, user, action, entity, changes`

### 5.2 Vehicle TAT Report *(pending backend support)*
The client (Flutter app) currently ships a client-derived Vehicle TAT export that
reuses `GET /gate-entries` and reports **Gate TAT = Gate Out − Gate In**. To
match the warehouse's `Inward TAT` workbook exactly (KB Cytiva format), the
backend must capture and expose four additional timestamps per gate entry, so
the client can compute **DIDO = Dock Out − Dock In** — the metric the ops team
actually tracks.

**Additional fields on the `GateEntry` object**:
```json
{
  "id": "GE-1001",
  ...existing fields...,
  "scheduleOkTime": "2026-08-01T06:50:00Z",  // Cleared for scheduling by warehouse exec
  "dockInTime":      "2026-08-01T07:15:00Z", // Vehicle actually reached the dock
  "dockOutTime":     "2026-08-01T07:32:00Z", // Vehicle left the dock after unload
  "shift":           "1ST",                  // Derivable from gate-in, but nice to have server-side canonical value
  "remarks":         "-"                      // Free-text (Remark 3 in workbook)
}
```

**New capture endpoints** (write side — one per lifecycle step):
- `POST /gate-entries/:id/schedule-ok`
  - Body: `{ "at": "2026-08-01T06:50:00Z" }` (optional; server may default to now)
  - Called by: `warehouse_executive`
- `POST /gate-entries/:id/dock-in`
  - Body: `{ "at": "2026-08-01T07:15:00Z", "dockNumber": "D-2" }` (dockNumber optional)
  - Called by: `warehouse_executive`
- `POST /gate-entries/:id/dock-out`
  - Body: `{ "at": "2026-08-01T07:32:00Z", "remarks": "-" }`
  - Called by: `warehouse_executive`

**New read endpoint** (dedicated report, so we're not paging through gate entries):
- `GET /reports/vehicle-tat?startDate=X&endDate=Y&vendor=Z&shift=1ST|2ND|3RD`
  - Response: array of rows matching the workbook's 12 columns:
    ```json
    [
      {
        "date":          "2026-08-01",
        "shift":         "3RD",
        "vendorName":    "ESSEM AUTO ELECTRICALS PVT LTD",
        "vehicleNo":     "MH14LS6236",
        "gateInTime":    "2026-08-01T12:15:00Z",
        "scheduleOkTime":"2026-08-01T12:20:00Z",
        "dockInTime":    "2026-08-02T00:21:00Z",
        "dockOutTime":   "2026-08-02T00:38:00Z",
        "didoMinutes":   17,
        "remark1":       "With TAT",                          // "With TAT" if didoMinutes < 60 else "Out of TAT"
        "remark2":       "Vehicle reported after 8:00 PM",   // set when gateIn outside 06:00–20:00 local
        "remark3":       ""                                    // free text
      }
    ]
    ```

**Derivation rules** (server-side, so the report and dashboard agree):
- `shift`: `1ST` = 06:00-13:59, `2ND` = 14:00-21:59, `3RD` = 22:00-05:59 (local warehouse tz).
- `remark1`: `didoMinutes < 60 ? "With TAT" : "Out of TAT"`.
- `remark2`: set the "after 8:00 PM" string iff `gateInLocalHour >= 20 || gateInLocalHour < 6`.
- `didoMinutes` = null if either dock timestamp missing (client renders "-").

**Client wiring**: once the endpoint above is live, replace the client's derived
export in [lib/features/reports/domain/services/report_export_service.dart](lib/features/reports/domain/services/report_export_service.dart)
(`_buildVehicleTatExcelBytes` / `_buildVehicleTatPdfBytes`) with a fetch from
`GET /reports/vehicle-tat`, and drop the shift/after-hours helpers from the
client — they'll come from the server.

---

## 6. Audit System
The Frontend strictly tracks user business actions (User logins, Exceptions Resolved, Entries Created) and hits the Audit POST API.
- **URL**: `POST /audit-logs`
- **Request Body**:
  ```json
  {
    "userId": "U-105",
    "role": "warehouse_manager",
    "action": "RESOLVE_EXCEPTION",
    "module": "Reconciliation",
    "description": "Resolved EXC-5521 with notes: Vendor error adjusted.",
    "timestamp": "2026-03-01T12:05:00Z"
  }
  ```
