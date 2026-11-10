import 'package:flutter/foundation.dart';

import '../project/project_index.dart';
import '../project/project_service.dart';

/// Loads and filters the project list for the dashboard.
class DashboardController extends ChangeNotifier {
  DashboardController(this.service);

  final ProjectService service;

  List<ProjectRecord> projects = [];
  List<ProjectRecord> recent = [];
  String query = '';
  ProjectSort sort = ProjectSort.lastModified;
  bool loading = true;
  Object? error;
  bool _disposed = false;

  Future<void> refresh() async {
    loading = true;
    _notify();
    try {
      projects = await service.listProjects(query: query, sort: sort);
      recent = await service.recentProjects(limit: 5);
      error = null;
    } catch (e) {
      error = e;
    }
    loading = false;
    _notify();
  }

  void setQuery(String q) {
    query = q;
    refresh();
  }

  void setSort(ProjectSort s) {
    sort = s;
    refresh();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
