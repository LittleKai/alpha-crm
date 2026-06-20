// Industry prompt templates + extraction-goal labels for the group AI summary
// wizard. The selected/edited prompt is sent to the cloud summarizer and the
// goals drive which sections the model emphasises.

class SummaryGoal {
  final String key;
  final String label;

  const SummaryGoal(this.key, this.label);
}

/// Extraction goals shown as checkboxes in the wizard. Keys must match the
/// backend `GOAL_INSTRUCTIONS` map in `crmGroupSummary.js`.
const List<SummaryGoal> kSummaryGoals = [
  SummaryGoal('leads', 'Khách quan tâm / hỏi mua (lead nóng)'),
  SummaryGoal('questions', 'Câu hỏi chưa được trả lời'),
  SummaryGoal('complaints', 'Phàn nàn / khiếu nại'),
  SummaryGoal('actions', 'Việc cần làm (follow-up)'),
  SummaryGoal('trends', 'Chủ đề nổi bật / xu hướng'),
];

class IndustryTemplate {
  final String key;
  final String label;
  final String prompt;

  const IndustryTemplate({
    required this.key,
    required this.label,
    required this.prompt,
  });
}

const List<IndustryTemplate> kIndustryTemplates = [
  IndustryTemplate(
    key: 'generic',
    label: 'Chung (Generic)',
    prompt:
        'Bạn là chuyên gia CRM/marketing. Tóm tắt hội thoại nhóm Zalo cho đội bán hàng. '
        'Nêu rõ ai đang quan tâm, câu hỏi chưa trả lời và việc cần làm tiếp theo.',
  ),
  IndustryTemplate(
    key: 'retail',
    label: 'Bán lẻ / E-commerce',
    prompt:
        'Bạn là chuyên gia bán hàng bán lẻ. Tóm tắt nhóm Zalo, tập trung vào: khách hỏi giá/khuyến mãi, '
        'hỏi tồn kho/size/màu, ý định mua, đơn hàng cần chốt, và phàn nàn về sản phẩm/giao hàng.',
  ),
  IndustryTemplate(
    key: 'realestate',
    label: 'Bất động sản',
    prompt:
        'Bạn là chuyên viên môi giới bất động sản. Tóm tắt nhóm Zalo, tập trung vào: khách quan tâm dự án/căn hộ, '
        'ngân sách, nhu cầu (ở/đầu tư), lịch xem nhà, và các câu hỏi pháp lý/giá cần phản hồi.',
  ),
  IndustryTemplate(
    key: 'education',
    label: 'Giáo dục / Khóa học',
    prompt:
        'Bạn là tư vấn tuyển sinh. Tóm tắt nhóm Zalo, tập trung vào: phụ huynh/học viên quan tâm khóa học, '
        'hỏi học phí/lịch học, băn khoăn cần giải đáp, và học viên cần chăm sóc để đăng ký.',
  ),
  IndustryTemplate(
    key: 'spa',
    label: 'Spa / Làm đẹp',
    prompt:
        'Bạn là tư vấn viên spa/thẩm mỹ. Tóm tắt nhóm Zalo, tập trung vào: khách quan tâm dịch vụ/liệu trình, '
        'hỏi giá/ưu đãi, đặt lịch hẹn, phản hồi sau dịch vụ và khách cần chăm sóc lại.',
  ),
];

IndustryTemplate industryTemplateByKey(String key) {
  return kIndustryTemplates.firstWhere(
    (t) => t.key == key,
    orElse: () => kIndustryTemplates.first,
  );
}
