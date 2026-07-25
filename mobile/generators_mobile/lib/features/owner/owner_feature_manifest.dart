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

  static const bool collectorProvisioningEnabledInStage02 = true;
  static const bool collectorAssignmentFoundationEnabledInStage02 = true;
  static const bool financialWorkflowsEnabledInStage02 = false;
}
