abstract final class OwnerFeatureManifest {
  static const List<String> activeModules = [
    'dashboard',
    'generators',
    'routes',
    'subscribers',
    'collectors',
    'readings',
    'monthlyInvoices',
  ];

  static const bool collectorProvisioningEnabled = true;
  static const bool realDomainContractsEnabled = true;
  static const bool verifiedAssignmentsEnabled = true;
  static const bool meterReadingOfflineEnabled = true;
  static const bool readingPeriodLockEnabled = true;
  static const bool directMonthlyInvoicesEnabled = true;
  static const bool draftWorkflowEnabled = false;
  static const bool reviewWorkflowEnabled = false;
  static const bool approvalWorkflowEnabled = false;
  static const bool separateDebtLedgerEnabled = false;
  static const bool collectionEnabled = false;
  static const bool hardDeleteEnabled = false;
}
