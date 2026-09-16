class ApiEndpoints {
  // Auth
  static const String login = '/auth/login';
  static const String me = '/auth/me';

  // Dashboard
  static const String dashboardSecurity = '/dashboard/security';

  // Gate Entries
  static const String gateEntries = '/gate-entries';
  // Scan a photographed challan/invoice into a draft gate entry. Reads the
  // paperwork so the guard does not type it; see ScanReviewSheet.
  static const String gateEntryScan = '/gate-entries/scan';
  static String gateEntryVerify(String id) => '/gate-entries/$id/verify';
  static String gateEntryApprove(String id) => '/gate-entries/$id/approve';
  static String gateEntryClose(String id) => '/gate-entries/$id/close';
  static String gateEntryDetails(String id) => '/gate-entries/$id';

  // Reconciliation & Exceptions
  static const String reconciliation = '/reconciliations';
  static const String exceptions = '/reconciliation/exceptions';

  // Reports
  //
  // These must match src/modules/gate/dist/routes/report.routes.js. The gate
  // entry register is '/reports/gate-entry' (singular) — the plural spelling
  // used here before returned 404, and '/reports/exceptions' has no route at
  // all, so it is gone rather than left as a trap. Exceptions are served by
  // [exceptions] above.
  static const String reportGateEntry = '/reports/gate-entry';
  static const String reportReconciliation = '/reports/reconciliation';
  static const String reportGrnRecon = '/reports/grn-recon';
  static const String reportPendingGrn = '/reports/pending-grn';
  static const String reportAuditTrail = '/reports/audit-trail';
  static const String reportDashboardSummary = '/reports/dashboard-summary';

  // SAP / GRN
  static const String grnImport = '/sap/grns/import';

  // Users
  static const String users = '/users';
  static String userDetails(String id) => '/users/$id';

  // Vendor Master
  static const String vendorMaster = '/vendor-master';
  static String vendorMasterDetails(String id) => '/vendor-master/$id';
}
