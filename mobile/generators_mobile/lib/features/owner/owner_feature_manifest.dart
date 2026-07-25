abstract final class OwnerFeatureManifest {
  static const List<String> plannedModules = [
    'dashboard',
    'generators',
    'routes',
    'subscribers',
    'collectors',
    'readings',
    'billingDrafts',
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
  static const bool readingPeriodLockEnabled = true;
  static const bool monthlyBillingDraftsEnabledInStage05 = true;
  static const bool tariffSnapshotsEnabledInStage05 = true;
  static const bool hardDeleteEnabledInStage05 = false;
  static const bool collectionEnabledInStage05 = false;
  static const bool debtEnabledInStage05 = false;
}
