import 'package:alpha_crm/features/tasks/providers/crm_tasks_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CrmTask.fromJson strips leading [id] prefix from group name',
    () {
      final json = {
        'id': 'task-1',
        'title': 'Chốt sale khóa học Video Marketing',
        'groupId': {
          'name': '[1229] AgentX LV1',
          'accountId': 'acc-1',
          'groupId': 'group-1',
        },
      };

      final task = CrmTask.fromJson(json);

      expect(task.groupName, 'AgentX LV1');
    },
  );

  test(
    'CrmTask.fromJson leaves clean group name unchanged',
    () {
      final json = {
        'id': 'task-2',
        'title': 'Other Task',
        'groupId': {
          'name': 'AgentX LV2',
          'accountId': 'acc-1',
          'groupId': 'group-2',
        },
      };

      final task = CrmTask.fromJson(json);

      expect(task.groupName, 'AgentX LV2');
    },
  );
}
