import '../../../shared/api/crm_cloud_api.dart';
import '../../../shared/models/crm_customer.dart';

class CustomersRepository {
  Future<Map<String, dynamic>> getCustomers({
    String? search,
    String? status,
    String? tag,
    String? lifecycleStage,
    String? segmentId,
    int? page,
    int? limit,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (tag != null && tag.isNotEmpty) queryParams['tag'] = tag;
    if (lifecycleStage != null && lifecycleStage.isNotEmpty) {
      queryParams['lifecycleStage'] = lifecycleStage;
    }
    if (segmentId != null && segmentId.isNotEmpty) {
      queryParams['segmentId'] = segmentId;
    }
    if (page != null) queryParams['page'] = page.toString();
    if (limit != null) queryParams['limit'] = limit.toString();

    final path = Uri(
      path: '/crm/customers',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    ).toString();
    final response = await CrmCloudApi.get(path);
    return response;
  }

  Future<Map<String, dynamic>> createCustomer(CrmCustomer customer) async {
    final response = await CrmCloudApi.post(
      '/crm/customers',
      customer.toJson(),
    );
    return response;
  }

  Future<Map<String, dynamic>> updateCustomer(
    String id,
    CrmCustomer customer,
  ) async {
    final response = await CrmCloudApi.put(
      '/crm/customers/$id',
      customer.toJson(),
    );
    return response;
  }

  Future<Map<String, dynamic>> deleteCustomer(String id) async {
    final response = await CrmCloudApi.delete('/crm/customers/$id');
    return response;
  }

  Future<Map<String, dynamic>> importCustomers(
    List<Map<String, dynamic>> rows,
  ) {
    return CrmCloudApi.post('/crm/customers/import', {'rows': rows});
  }

  Future<Map<String, dynamic>> exportCustomers({String? segmentId}) {
    final query = segmentId == null || segmentId.isEmpty
        ? null
        : {'segmentId': segmentId};
    final path = Uri(
      path: '/crm/exports/customers',
      queryParameters: query,
    ).toString();
    return CrmCloudApi.get(path);
  }
}
