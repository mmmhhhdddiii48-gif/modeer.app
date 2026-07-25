abstract final class CollectorFeatureManifest {
  static const List<String> plannedModules = [
    'assignedGenerators',
    'assignedRoutes',
    'assignedSubscribers',
    'meterReadings',
    'fullOrPartialCollections',
    'notes',
    'ownHistory',
    'syncStatus',
  ];

  static const List<String> explicitlyDeniedModules = [
    'profits',
    'allExpenses',
    'ownerSettings',
    'otherCollectorsData',
  ];

  static const bool assignedDomainVisibleInStage03 = true;
  static const bool financialWorkflowsEnabledInStage03 = false;
}
