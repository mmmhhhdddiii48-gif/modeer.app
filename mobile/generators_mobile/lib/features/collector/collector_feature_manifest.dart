abstract final class CollectorFeatureManifest {
  static const List<String> plannedModules = [
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

  static const bool financialWorkflowsEnabledInStage01 = false;
}
