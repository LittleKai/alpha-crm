import '../../../shared/api/crm_cloud_api.dart';

class CustomerSegment {
  final String id;
  final String name;
  final Map<String, dynamic> filters;

  const CustomerSegment({
    required this.id,
    required this.name,
    required this.filters,
  });

  static CustomerSegment fromJson(Map<String, dynamic> json) {
    return CustomerSegment(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      filters: json['filters'] is Map
          ? Map<String, dynamic>.from(json['filters'] as Map)
          : const {},
    );
  }
}

class SegmentsRepository {
  Future<Map<String, dynamic>> getSegments() {
    return CrmCloudApi.get('/crm/segments');
  }

  Future<Map<String, dynamic>> createSegment(
    String name,
    Map<String, dynamic> filters,
  ) {
    return CrmCloudApi.post('/crm/segments', {
      'name': name,
      'filters': filters,
    });
  }

  Future<Map<String, dynamic>> deleteSegment(String id) {
    return CrmCloudApi.delete('/crm/segments/$id');
  }

  Future<Map<String, dynamic>> previewSegment(String id) {
    return CrmCloudApi.post('/crm/segments/$id/preview', {});
  }
}
