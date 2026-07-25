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

  static const bool assignmentsVisibleInStage02 = true;
  static const bool financialWorkflowsEnabledInStage02 = false;
}
