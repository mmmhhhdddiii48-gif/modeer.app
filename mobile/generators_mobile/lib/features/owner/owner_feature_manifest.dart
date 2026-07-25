abstract final class OwnerFeatureManifest {
  static const List<String> plannedModules = [
    'dashboard',
    'generators',
    'routes',
    'subscribers',
    'collectors',
    'readings',
    'billingDrafts',
    'approvedInvoices',
    'debtLedger',
    'collections',
    'expensesAndFuel',
    'maintenance',
    'reports',
    'collectorSyncAudit',
  ];

  static const bool collectorProvisioningEnabled = true;
  static const bool realDomainContractsEnabled = true;
  static const bool verifiedAssignmentsEnabled = true;
  static const bool meterReadingOfflineEnabled = true;
  static const bool monthlyBillingDraftsEnabled = true;
  static const bool invoiceApprovalEnabledInStage06 = true;
  static const bool debtLedgerEnabledInStage06 = true;
  static const bool collectionEnabledInStage06 = false;
  static const bool receiptEnabledInStage06 = false;
  static const bool cashEffectEnabledInStage06 = false;
  static const bool hardDeleteEnabledInStage06 = false;
}
