abstract final class OwnerFeatureManifest {
  static const List<String> plannedModules = [
    'dashboard',
    'generators',
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

  static const bool financialWorkflowsEnabledInStage01 = false;
}
