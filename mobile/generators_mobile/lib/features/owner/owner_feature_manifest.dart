abstract final class OwnerFeatureManifest {
  static const List<String> plannedModules = [
    'dashboard',
    'generators',
    'routes',
    'subscribers',
    'collectors',
    'readings',
    'invoices',
    'collections',
    'expensesAndFuel',
    'maintenance',
    'reports',
    'collectorSyncAudit',
  ];

  static const bool collectorProvisioningEnabled = true;
  static const bool realDomainContractsEnabled = true;
  static const bool verifiedAssignmentsEnabled = true;
  static const bool meterReadingOfflineEnabledInStage04 = true;
  static const bool readingPeriodLockEnabledInStage04 = true;
  static const bool hardDeleteEnabledInStage04 = false;
  static const bool billingEnabledInStage04 = false;
  static const bool collectionEnabledInStage04 = false;
}
