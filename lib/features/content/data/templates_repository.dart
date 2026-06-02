import '../../../shared/api/crm_cloud_api.dart';
import '../../../shared/models/crm_template.dart';

class TemplatesRepository {
  Future<Map<String, dynamic>> getTemplates({
    String? search,
    String? type,
    String? category,
    bool? isQuick,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (type != null && type.isNotEmpty) queryParams['type'] = type;
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (isQuick != null) queryParams['isQuick'] = isQuick.toString();

    final path = Uri(
      path: '/crm/templates',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    ).toString();
    final response = await CrmCloudApi.get(path);
    return response;
  }

  Future<Map<String, dynamic>> createTemplate(CrmTemplate template) async {
    final response = await CrmCloudApi.post(
      '/crm/templates',
      template.toJson(),
    );
    return response;
  }

  Future<Map<String, dynamic>> updateTemplate(
    String id,
    CrmTemplate template,
  ) async {
    final response = await CrmCloudApi.put(
      '/crm/templates/$id',
      template.toJson(),
    );
    return response;
  }

  Future<Map<String, dynamic>> deleteTemplate(String id) async {
    final response = await CrmCloudApi.delete('/crm/templates/$id');
    return response;
  }
}
