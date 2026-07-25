import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/domain_repository.dart';
import '../domain/generator_domain.dart';

part 'domain_generators_tab.dart';
part 'domain_routes_tab.dart';
part 'domain_subscribers_tab.dart';
part 'domain_list_shell.dart';
part 'domain_generator_dialog.dart';
part 'domain_route_dialog.dart';
part 'domain_subscriber_dialog.dart';

final class DomainManagementPage extends StatelessWidget {
  const DomainManagementPage({
    required this.repository,
    required this.tenantId,
    super.key,
  });

  final DomainRepository repository;
  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المولدات والمسارات والمشتركين'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.electrical_services_outlined), text: 'المولدات'),
              Tab(icon: Icon(Icons.route_outlined), text: 'المسارات'),
              Tab(icon: Icon(Icons.people_outline), text: 'المشتركون'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GeneratorsTab(repository: repository, tenantId: tenantId),
            _RoutesTab(repository: repository, tenantId: tenantId),
            _SubscribersTab(repository: repository, tenantId: tenantId),
          ],
        ),
      ),
    );
  }
}

