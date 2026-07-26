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

  static const bool assignedDomainVisible = true;
  static const bool meterReadingOfflineEnabledInStage04 = true;
  static const bool collectionEnabledInStage04 = false;
  static const bool financialWorkflowsEnabledInStage04 = false;
}
