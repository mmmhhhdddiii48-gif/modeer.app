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
  static const bool realDomainContractsEnabledInStage03 = true;
  static const bool verifiedAssignmentsEnabledInStage03 = true;
  static const bool hardDeleteEnabledInStage03 = false;
  static const bool financialWorkflowsEnabledInStage03 = false;
}
