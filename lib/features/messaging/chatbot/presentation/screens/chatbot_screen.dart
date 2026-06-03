import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_text_styles.dart';
import '../../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../../shared/widgets/app_alert.dart';
import '../../../../../shared/widgets/app_badge.dart';
import '../../../../../shared/widgets/app_button.dart';
import '../../../../../shared/widgets/app_card.dart';
import '../../../../../shared/widgets/app_dialog.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/app_table.dart';
import '../../../../../shared/widgets/app_tabs.dart';
import '../../providers/chatbot_provider.dart';
import '../../../../auth/providers/crm_auth_provider.dart';
import '../../../../../shared/api/crm_cloud_api.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _soulController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();
  double _tempValue = 0.7;
  String _selectedModel = chatbotDefaultAiModel;

  final TextEditingController _testMessageController = TextEditingController();
  String? _playgroundResponse;
  bool _isPlaying = false;

  @override
  void dispose() {
    _promptController.dispose();
    _soulController.dispose();
    _rulesController.dispose();
    _testMessageController.dispose();
    super.dispose();
  }

  Future<void> _sendTestMessage() async {
    final msg = _testMessageController.text.trim();
    if (msg.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _playgroundResponse = null;
    });

    final response = await CrmCloudApi.post('/crm/chatbot/test', {
      'message': msg,
      'aiModel': _selectedModel,
      'systemPrompt': _promptController.text,
      'soulPrompt': _soulController.text,
      'responseRules': _rulesController.text,
      'temperature': _tempValue,
    });

    setState(() {
      _isPlaying = false;
    });

    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _playgroundResponse = response['data']['text']?.toString();
      });
      ref.read(crmAuthProvider.notifier).refreshSubscription();
    } else {
      setState(() {
        _playgroundResponse =
            'Lỗi: ${response['message'] ?? "Không nhận được phản hồi từ AI."}';
      });
    }
  }

  Future<void> _showCreateRuleDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final drafts = [_KeywordRuleDraft()];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: 'Tạo kịch bản chatbot mới',
              icon: Icons.smart_toy_outlined,
              width: 640,
              actions: [
                AppDialogAction(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppDialogAction(
                  text: 'Tạo kịch bản',
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    final validDrafts = drafts
                        .where(
                          (draft) =>
                              draft.keyword.text.trim().isNotEmpty &&
                              draft.response.text.trim().isNotEmpty,
                        )
                        .toList();
                    if (validDrafts.isEmpty) return;

                    final notifier = ref.read(chatbotProvider.notifier);
                    for (var i = 0; i < validDrafts.length; i += 1) {
                      final ruleName = nameController.text.trim().isEmpty
                          ? validDrafts[i].keyword.text.trim()
                          : validDrafts.length == 1
                          ? nameController.text.trim()
                          : '${nameController.text.trim()} #${i + 1}';
                      await notifier.addRule(
                        validDrafts[i].keyword.text,
                        validDrafts[i].response.text,
                        name: ruleName,
                        description: descriptionController.text,
                      );
                    }
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên kịch bản *',
                      hintText: 'VD: Tư vấn sản phẩm',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      hintText: 'Mô tả ngắn về kịch bản này',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppSpacing.borderRadiusM,
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.rule_folder_outlined,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s),
                            Text(
                              'Quy tắc trả lời',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.m),
                        for (var i = 0; i < drafts.length; i += 1) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Quy tắc #${i + 1}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (drafts.length > 1)
                                IconButton(
                                  tooltip: 'Xóa quy tắc',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    final removed = drafts.removeAt(i);
                                    removed.dispose();
                                    setDialogState(() {});
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s),
                          TextField(
                            controller: drafts[i].keyword,
                            decoration: const InputDecoration(
                              labelText: 'Từ khóa kích hoạt',
                              hintText: 'VD: giá, bao nhiêu, price',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.m),
                          TextField(
                            controller: drafts[i].response,
                            minLines: 4,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              labelText: 'Phản hồi tự động',
                              hintText:
                                  'Nội dung trả lời khi phát hiện từ khóa...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s),
                          Text(
                            'Định dạng: **in đậm** *in nghiêng* __gạch chân__ ~~gạch ngang~~',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (i < drafts.length - 1) ...[
                            const SizedBox(height: AppSpacing.m),
                            const Divider(
                              height: 1,
                              color: AppColors.borderSoft,
                            ),
                            const SizedBox(height: AppSpacing.m),
                          ],
                        ],
                        const SizedBox(height: AppSpacing.m),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton(
                            text: 'Thêm quy tắc',
                            icon: Icons.add_rounded,
                            variant: AppButtonVariant.outline,
                            onPressed: () {
                              drafts.add(_KeywordRuleDraft());
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
    descriptionController.dispose();
    for (final draft in drafts) {
      draft.dispose();
    }
  }

  // ignore: unused_element
  Future<void> _showLegacyCreateRuleDialog(BuildContext context) async {
    final keywordController = TextEditingController();
    final responseController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tạo kịch bản chatbot'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keywordController,
                  decoration: const InputDecoration(
                    labelText: 'Từ khóa',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                TextField(
                  controller: responseController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung phản hồi',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(chatbotProvider.notifier)
                    .addRule(keywordController.text, responseController.text);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
    keywordController.dispose();
    responseController.dispose();
  }

  Future<void> _showAddKnowledgeDialog(
    BuildContext context,
    ChatbotNotifier notifier,
  ) async {
    final titleController = TextEditingController();
    final keywordsController = TextEditingController();
    final contentController = TextEditingController();
    PlatformFile? pickedFile;
    Map<String, dynamic>? uploadedFile;
    var isUploading = false;
    String? uploadError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickAndUploadFile() async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                withData: true,
                type: FileType.any,
              );
              if (result == null || result.files.isEmpty) return;
              final file = result.files.single;
              if (file.bytes == null) {
                setDialogState(() {
                  pickedFile = file;
                  uploadedFile = null;
                  uploadError =
                      'Không đọc được nội dung file. Hãy chọn file có thể truy cập trực tiếp.';
                });
                return;
              }

              setDialogState(() {
                pickedFile = file;
                uploadedFile = null;
                uploadError = null;
                isUploading = true;
              });

              final response = await notifier.uploadKnowledgeFile(
                filename: file.name,
                bytes: file.bytes!,
                contentType: _guessContentType(file.name),
              );

              setDialogState(() {
                isUploading = false;
                if (response['success'] == true && response['data'] is Map) {
                  uploadedFile = Map<String, dynamic>.from(
                    response['data'] as Map,
                  );
                } else {
                  uploadError = (response['message'] ?? 'Upload file thất bại.')
                      .toString();
                }
              });
            }

            return AppDialog(
              title: 'Thêm tài liệu kiến thức mới',
              icon: Icons.description_outlined,
              width: 640,
              actions: [
                AppDialogAction(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppDialogAction(
                  text: 'Thêm tài liệu',
                  icon: Icons.add_rounded,
                  onPressed: isUploading
                      ? null
                      : () {
                          final title = titleController.text.trim();
                          final keywords = keywordsController.text.trim();
                          final content = contentController.text.trim();
                          if (title.isEmpty || content.isEmpty) return;

                          final fileUrl = uploadedFile?['publicUrl']
                              ?.toString();
                          final fileName =
                              uploadedFile?['filename']?.toString() ??
                              pickedFile?.name;
                          final text = [
                            'Tiêu đề tài liệu: $title',
                            if (keywords.isNotEmpty)
                              'Từ khóa kích hoạt: $keywords',
                            'Nội dung kiến thức bắt buộc:\n$content',
                            if (fileUrl != null && fileUrl.isNotEmpty)
                              'File/ảnh đính kèm:\n- Tên: $fileName\n- URL: $fileUrl\n- Quy tắc gửi: AI chỉ chọn file/ảnh này khi nội dung khách hỏi khớp từ khóa hoặc nội dung kiến thức; agent Zalo trên máy người dùng sẽ thực hiện gửi file/ảnh thật.',
                          ].join('\n\n');

                          notifier.addKnowledgeDocument(text).then((_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã thêm kiến thức: $title'),
                                ),
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          });
                        },
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề tài liệu *',
                      hintText: 'VD: Chính sách giao hàng',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: keywordsController,
                    decoration: const InputDecoration(
                      labelText: 'Từ khóa kích hoạt',
                      hintText:
                          'VD: ship, phí ship, giao hàng, vận chuyển (cách nhau bằng dấu phẩy)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Từ khóa dùng để AI biết khi nào cần dùng tài liệu này. Nhập * nếu muốn tài liệu này luôn luôn được dùng làm ngữ cảnh mặc định.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: contentController,
                    minLines: 7,
                    maxLines: 12,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung kiến thức *',
                      hintText:
                          'Nhập nội dung kiến thức chi tiết gạch đầu dòng để AI học và trả lời khách hàng...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'File / hình ảnh đính kèm (${uploadedFile == null ? 0 : 1})',
                        style: AppTextStyles.label,
                      ),
                      AppButton(
                        text: isUploading ? 'Đang upload' : 'Chọn thêm file',
                        icon: Icons.upload_file_outlined,
                        variant: AppButtonVariant.outline,
                        isLoading: isUploading,
                        onPressed: isUploading ? null : pickAndUploadFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: AppSpacing.borderRadiusM,
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: uploadedFile == null
                        ? Text(
                            uploadError ??
                                'Chưa có file hoặc hình ảnh đính kèm nào cho tài liệu này.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(
                              color: uploadError == null
                                  ? AppColors.textMuted
                                  : AppColors.errorText,
                            ),
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.insert_drive_file_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.s),
                              Expanded(
                                child: Text(
                                  '${uploadedFile?['filename'] ?? pickedFile?.name} • ${_formatFileSize(uploadedFile?['size'])}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Bỏ file',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  setDialogState(() {
                                    pickedFile = null;
                                    uploadedFile = null;
                                    uploadError = null;
                                  });
                                },
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    titleController.dispose();
    keywordsController.dispose();
    contentController.dispose();
  }

  String _guessContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatFileSize(Object? size) {
    final bytes = int.tryParse(size?.toString() ?? '') ?? 0;
    if (bytes <= 0) return 'không rõ dung lượng';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ignore: unused_element
  Future<void> _showLegacyAddKnowledgeDialog(
    BuildContext context,
    ChatbotNotifier notifier,
  ) async {
    final docController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thêm tài liệu/kiến thức mới'),
          content: SizedBox(
            width: 400,
            child: TextField(
              controller: docController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Nhập nội dung kiến thức hoặc tên tài liệu',
                hintText:
                    'VD: Chính sách bảo hành: 1 đổi 1 trong vòng 30 ngày...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = docController.text.trim();
                if (text.isNotEmpty) {
                  await notifier.addKnowledgeDocument(text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Đã thêm kiến thức: $text')),
                    );
                  }
                }
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Thêm'),
            ),
          ],
        );
      },
    );
    docController.dispose();
  }

  Future<void> _showKeywordHelpDialog(BuildContext context) {
    return _showKeywordGuideDialog(context);
  }

  Future<void> _showKeywordGuideDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Hướng dẫn kịch bản từ khóa',
        subtitle:
            'Ưu tiên kịch bản cố định cho các câu hỏi lặp lại trước khi dùng AI.',
        icon: Icons.vpn_key_outlined,
        actions: [
          AppDialogAction(
            text: 'Đã hiểu',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogSection(
              title: 'Khi nào dùng kịch bản từ khóa',
              icon: Icons.rule_folder_outlined,
              items: [
                'Dùng cho các câu hỏi lặp lại như giá, bảo hành, địa chỉ, giờ làm việc hoặc quy trình mua hàng.',
                'Mỗi kịch bản nên có từ khóa ngắn, tự nhiên và dễ xuất hiện trong tin nhắn khách.',
                'Bot luôn kiểm tra kịch bản từ khóa trước; nếu không khớp và AI đang bật thì backend mới gọi GCLI để tạo câu trả lời.',
              ],
            ),
            SizedBox(height: AppSpacing.m),
            AppDialogSection(
              title: 'Cách viết an toàn',
              icon: Icons.verified_user_outlined,
              items: [
                'Nội dung phản hồi nên ngắn, rõ hành động tiếp theo và có thể kèm lời mời gặp tư vấn viên.',
                'Các tình huống nhạy cảm như khiếu nại, hoàn tiền, pháp lý hoặc yêu cầu gặp người thật nên chuyển nhân viên.',
                'Không đưa token, mật khẩu, cookie hoặc dữ liệu cá nhân nhạy cảm vào câu trả lời cố định.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showLegacyKeywordHelpDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hướng dẫn kịch bản từ khóa'),
        content: const SizedBox(
          width: 520,
          child: Text(
            'Dùng kịch bản từ khóa cho các câu hỏi lặp lại như giá, bảo hành, địa chỉ hoặc giờ làm việc. '
            'Mỗi kịch bản nên có từ khóa ngắn, dễ xuất hiện trong tin nhắn khách. '
            'Nếu khách nhắn trùng từ khóa, bot trả lời bằng nội dung cố định trước; nếu không khớp và AI đang bật, backend mới gọi GCLI để AI trả lời. '
            'Các tình huống nhạy cảm như khiếu nại, hoàn tiền hoặc yêu cầu gặp người thật nên được ghi rõ trong prompt để bot chuyển nhân viên.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _showKnowledgeHelpDialog(BuildContext context) {
    return _showKnowledgeGuideDialog(context);
  }

  Future<void> _showKnowledgeGuideDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Hướng dẫn tài liệu kiến thức',
        subtitle:
            'Kho kiến thức giúp AI trả lời đúng nội dung doanh nghiệp, nhưng agent vẫn là nơi gửi file/ảnh/tin Zalo thật.',
        icon: Icons.folder_open_outlined,
        width: 640,
        actions: [
          AppDialogAction(
            text: 'Đã hiểu',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogSection(
              title: 'Nên lưu gì vào kho kiến thức',
              icon: Icons.library_books_outlined,
              items: [
                'Lưu chính sách, bảng giá, FAQ, quy trình, điều kiện bảo hành và cách chuyển nhân viên.',
                'Với file hoặc ảnh, hãy lưu URL/tên tài liệu kèm hướng dẫn rõ: khi khách hỏi catalogue thì gửi link nào, ảnh nào hoặc file nào.',
                'Không lưu mật khẩu, token, cookie, IMEI, dữ liệu đăng nhập Zalo hoặc dữ liệu khách hàng nhạy cảm.',
              ],
            ),
            SizedBox(height: AppSpacing.m),
            AppDialogSection(
              title: 'Luồng đúng khi AI cần gửi file/ảnh',
              icon: Icons.route_outlined,
              items: [
                'Backend chỉ dùng key GCLI để gọi model và tạo nội dung hoặc quyết định gợi ý cần gửi tài liệu nào.',
                'Việc gửi tin nhắn, file, ảnh hoặc link cho người dùng Zalo phải được agent thực hiện trên máy đã đăng nhập tài khoản Zalo.',
                'Nếu cần gửi file/ảnh thật, agent cần nhận payload có loại hành động, threadId/người nhận, nội dung, URL hoặc đường dẫn file hợp lệ.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showLegacyKnowledgeHelpDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hướng dẫn tài liệu kiến thức'),
        content: const SizedBox(
          width: 560,
          child: Text(
            'Kho kiến thức lưu các đoạn tri thức ngắn vào backend theo từng tài khoản CRM. '
            'Hãy nhập nội dung mà AI cần dùng trực tiếp: chính sách, bảng giá, quy trình, FAQ, đường dẫn file hoặc ảnh cần gửi khách. '
            'Với file/ảnh, hãy upload lên kho lưu trữ của hệ thống hoặc B2/resource trước, sau đó dán URL kèm hướng dẫn rõ như: "khi khách hỏi catalogue, gửi link này". '
            'AI đọc phần này như ngữ cảnh nội bộ khi không có kịch bản từ khóa khớp. Không đưa mật khẩu, token, cookie hoặc dữ liệu khách hàng nhạy cảm vào kho kiến thức.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotProvider);
    final notifier = ref.read(chatbotProvider.notifier);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // Sync prompt value once
    if (_promptController.text.isEmpty && state.systemPrompt.isNotEmpty) {
      _promptController.text = state.systemPrompt;
      _soulController.text = state.soulPrompt;
      _rulesController.text = state.responseRules;
      _tempValue = state.temperature;
      _selectedModel = normalizeChatbotAiModel(state.aiModel);
    }

    final header = Row(
      children: [
        const Icon(
          Icons.smart_toy_outlined,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chatbot Tự Động', style: AppTextStyles.pageTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Thiết lập kịch bản trả lời tự động bằng từ khóa hoặc sử dụng AI để chăm sóc khách hàng 24/7',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        if (state.activeTab == 0 || state.activeTab == 2)
          IconButton(
            tooltip: state.activeTab == 0
                ? 'Hướng dẫn kịch bản từ khóa'
                : 'Hướng dẫn tài liệu kiến thức',
            icon: const Icon(Icons.help_outline_rounded),
            color: AppColors.textSecondary,
            onPressed: () => state.activeTab == 0
                ? _showKeywordHelpDialog(context)
                : _showKnowledgeHelpDialog(context),
          ),
        const SizedBox(width: AppSpacing.s),
        if (state.activeTab == 0)
          AppButton(
            text: 'Tạo kịch bản mới',
            icon: Icons.add_rounded,
            onPressed: () => _showCreateRuleDialog(context),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? AppSpacing.m : AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: AppSpacing.m),
            AppTabs(
              tabs: const [
                AppTabItem(
                  label: 'Kịch bản từ khóa',
                  icon: Icons.vpn_key_outlined,
                ),
                AppTabItem(
                  label: 'Trí tuệ nhân tạo (AI)',
                  icon: Icons.psychology_outlined,
                ),
                AppTabItem(
                  label: 'Tài liệu kiến thức',
                  icon: Icons.folder_open_outlined,
                ),
                AppTabItem(
                  label: 'Nhật ký phản hồi',
                  icon: Icons.history_edu_outlined,
                ),
              ],
              selectedIndex: state.activeTab,
              onTabSelected: notifier.setActiveTab,
            ),
            const SizedBox(height: AppSpacing.m),
            _buildTabContent(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(ChatbotState state, ChatbotNotifier notifier) {
    switch (state.activeTab) {
      case 0:
        return _buildKeywordTab(state, notifier);
      case 1:
        return _buildAiTab(state, notifier);
      case 2:
        return _buildKnowledgeTab(state, notifier);
      case 3:
        return _buildLogsTab(state, notifier);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildKeywordTab(ChatbotState state, ChatbotNotifier notifier) {
    if (state.rules.isEmpty) {
      return SizedBox(
        height: 520,
        child: AppEmptyState(
          icon: Icons.smart_toy_outlined,
          title: 'Chưa có kịch bản chatbot',
          description:
              'Tạo kịch bản trả lời tự động dựa trên từ khóa. Khi khách hàng gửi tin nhắn chứa từ khóa, chatbot sẽ tự động trả lời.',
          height: 520,
          actions: [
            AppButton(
              text: 'Tạo kịch bản đầu tiên',
              icon: Icons.add_rounded,
              onPressed: () => _showCreateRuleDialog(context),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980 ? 2 : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            mainAxisExtent: 180,
          ),
          itemCount: state.rules.length,
          itemBuilder: (context, index) {
            final rule = state.rules[index];
            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppBadge(
                            label: 'Từ khóa',
                            variant: AppBadgeVariant.info,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Text(
                            '"${rule.keyword}"',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Switch(
                            value: rule.isActive,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) =>
                                notifier.toggleRuleStatus(rule.id),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            onPressed: () {
                              notifier.deleteRule(rule.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã xóa kịch bản.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s),
                  Expanded(
                    child: Text(
                      rule.response,
                      style: AppTextStyles.body.copyWith(fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  const Divider(height: 1, color: AppColors.borderSoft),
                  const SizedBox(height: AppSpacing.s),
                  Text(
                    'Trạng thái: ${rule.isActive ? "Đang hoạt động" : "Tạm ngưng"}',
                    style: AppTextStyles.caption.copyWith(
                      color: rule.isActive
                          ? AppColors.successText
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAiSettingsDialog(
    BuildContext context,
    ChatbotState state,
    ChatbotNotifier notifier,
  ) async {
    final modelController = ValueNotifier<String>(
      normalizeChatbotAiModel(state.aiModel),
    );
    final promptController = TextEditingController(text: state.systemPrompt);
    final soulController = TextEditingController(text: state.soulPrompt);
    final rulesController = TextEditingController(text: state.responseRules);
    var temperature = state.temperature;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: 'Cài đặt AI Chatbot',
              subtitle:
                  'Backend giữ key GCLI và gọi model; agent Zalo trên máy người dùng vẫn là nơi gửi tin, file và ảnh thật cho khách.',
              icon: Icons.settings_outlined,
              width: 720,
              actions: [
                AppDialogAction(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppDialogAction(
                  text: 'Lưu cài đặt',
                  icon: Icons.save_outlined,
                  onPressed: () {
                    final selectedModel = modelController.value;
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogContext);
                    notifier
                        .updateAiConfig(
                          model: selectedModel,
                          prompt: promptController.text.trim(),
                          soulPrompt: soulController.text.trim(),
                          responseRules: rulesController.text.trim(),
                          temperature: temperature,
                        )
                        .then((_) {
                          if (mounted) {
                            setState(() {
                              _selectedModel = selectedModel;
                              _promptController.text = promptController.text;
                              _soulController.text = soulController.text;
                              _rulesController.text = rulesController.text;
                              _tempValue = temperature;
                            });
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Đã lưu cấu hình AI Chatbot.'),
                              ),
                            );
                          }
                          if (dialogContext.mounted) {
                            navigator.pop();
                          }
                        });
                  },
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mô hình ngôn ngữ AI sử dụng',
                    style: AppTextStyles.label,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ValueListenableBuilder<String>(
                    valueListenable: modelController,
                    builder: (context, selectedModel, _) {
                      return AppSelectField<String>(
                        value: selectedModel,
                        items: const [
                          DropdownMenuItem(
                            value: 'gemini-3-flash-preview',
                            child: Text(
                              'gemini-3-flash-preview (1 quota/lượt)',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'gemini-2.5-pro',
                            child: Text('gemini-2.5-pro (1 quota/lượt)'),
                          ),
                          DropdownMenuItem(
                            value: 'gemini-3.1-pro-preview',
                            child: Text(
                              'gemini-3.1-pro-preview (2 quota/lượt)',
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) modelController.value = value;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text('Prompt mặc định', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: promptController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Chỉ định cách chatbot phản hồi khách hàng...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text('Soul / đối tượng nhập vai', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: soulController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'VD: Bạn là nhân viên tư vấn Zalo chuyên nghiệp, gần gũi...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Text('Rule ví dụ bắt buộc', style: AppTextStyles.label),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: rulesController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          'VD: Không bịa thông tin, không lặp lời chào, thiếu dữ liệu thì chuyển nhân viên...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Độ sáng tạo (Temperature): ${temperature.toStringAsFixed(1)}',
                        style: AppTextStyles.label,
                      ),
                      Text(
                        temperature < 0.4
                            ? 'Chính xác/Nhất quán'
                            : temperature > 0.8
                            ? 'Sáng tạo/Linh hoạt'
                            : 'Cân bằng',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: temperature,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setDialogState(() {
                        temperature = value;
                      });
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    modelController.dispose();
    promptController.dispose();
    soulController.dispose();
    rulesController.dispose();
  }

  Widget _buildAudienceTargeting(ChatbotState state, ChatbotNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cấu hình Đối tượng Nhận Phản hồi (Audience Targeting)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Thiết lập giới hạn nhóm khách hàng cá nhân hoặc danh sách nhóm Zalo được phép phản hồi tự động.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.m),
          Text(
            'Trò chuyện cá nhân (1-1)',
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
          _buildChoiceTile(
            selected: state.personalAudience == 'all',
            title: 'Tất cả khách hàng',
            onTap: () => notifier.updateAudienceConfig(personalAudience: 'all'),
          ),
          _buildChoiceTile(
            selected: state.personalAudience == 'crmOnly',
            title: 'Chỉ nhóm nhân CRM khách hàng được chỉ định',
            onTap: () =>
                notifier.updateAudienceConfig(personalAudience: 'crmOnly'),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            'Trò chuyện Nhóm (Group)',
            style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
          ),
          _buildChoiceTile(
            selected: state.groupAudience == 'none',
            title: 'Không tự động trả lời trong nhóm',
            onTap: () => notifier.updateAudienceConfig(groupAudience: 'none'),
          ),
          _buildChoiceTile(
            selected: state.groupAudience == 'tagOnly',
            title: 'Trả lời ở tất cả các nhóm khi được tag',
            onTap: () =>
                notifier.updateAudienceConfig(groupAudience: 'tagOnly'),
          ),
          _buildChoiceTile(
            selected: state.groupAudience == 'selected',
            title: 'Chỉ trả lời ở các nhóm được chọn',
            subtitle: 'Danh sách nhóm sẽ được agent Zalo đồng bộ.',
            onTap: () =>
                notifier.updateAudienceConfig(groupAudience: 'selected'),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceTile({
    required bool selected,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: AppSpacing.borderRadiusS,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiTab(ChatbotState state, ChatbotNotifier notifier) {
    final authState = ref.watch(crmAuthProvider);
    final totalRemaining =
        authState.includedAiRemaining + authState.extraAiRemaining;
    final isExpired = authState.subscriptionStatus == 'expired';
    final hasNoQuota = totalRemaining <= 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.psychology_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cấu hình AI Chatbot tự động',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Phản hồi khách hàng thông minh bằng các mô hình AI ngôn ngữ lớn (LLM) theo ngữ cảnh cuộc trò chuyện.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Tooltip(
                message: 'Mở cài đặt AI',
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  color: AppColors.textSecondary,
                  onPressed: () =>
                      _showAiSettingsDialog(context, state, notifier),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Switch(
                    value: state.aiEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: notifier.setAiEnabled,
                  ),
                  Text(
                    state.aiEnabled ? 'ĐÃ BẬT' : 'ĐÃ TẮT',
                    style: AppTextStyles.caption.copyWith(
                      color: state.aiEnabled
                          ? AppColors.successText
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.m),
          Container(
            padding: const EdgeInsets.all(AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.borderRadiusM,
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.alternate_email_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chỉ phản hồi khi được tag tên (@) trong nhóm',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'AI Chatbot sẽ chỉ phản hồi trong cuộc trò chuyện nhóm Zalo khi tin nhắn chứa tag @tên Zalo của bạn.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.groupAudience == 'tagOnly',
                  activeThumbColor: AppColors.primary,
                  onChanged: (enabled) => notifier.updateAudienceConfig(
                    groupAudience: enabled ? 'tagOnly' : 'none',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          _buildAudienceTargeting(state, notifier),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: [
              AppBadge(
                label:
                    '${state.aiModel} (${state.aiModel == 'gemini-3.1-pro-preview' ? '2' : '1'} quota/lượt)',
                variant: AppBadgeVariant.info,
              ),
              AppBadge(
                label: 'Temperature ${state.temperature.toStringAsFixed(1)}',
                variant: AppBadgeVariant.neutral,
              ),
              AppBadge(
                label: state.personalAudience == 'crmOnly'
                    ? 'Chỉ khách CRM chỉ định'
                    : 'Tất cả khách cá nhân',
                variant: AppBadgeVariant.neutral,
              ),
            ],
          ),
          if (state.aiModel == 'gemini-3.1-pro-preview') ...[
            const SizedBox(height: AppSpacing.m),
            const AppAlert(
              message:
                  'Model gemini-3.1-pro-preview dùng quota gấp đôi. Backend sẽ trừ 2 lượt cho mỗi lần AI trả lời thành công và hoàn lại nếu upstream GCLI lỗi.',
              variant: AppAlertVariant.warning,
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            'THỬ NGHIỆM AI PLAYGROUND',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử nghiệm trực tiếp chỉ dẫn prompt và xem kết quả phản hồi của AI Chatbot.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          if (isExpired) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Gói dịch vụ CRM của bạn đã hết hạn. Vui lòng gia hạn tài khoản để mở khóa sử dụng AI Chatbot.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.errorText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else if (hasNoQuota) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚠️ Hạn mức AI Quota của bạn đã hết. Vui lòng di chuyển tới mục Đăng ký để mua thêm gói AI Top-up.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warningText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Text('Hạn mức AI khả dụng: ', style: AppTextStyles.caption),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: hasNoQuota
                      ? AppColors.errorSoft
                      : AppColors.successSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalRemaining lượt',
                  style: AppTextStyles.caption.copyWith(
                    color: hasNoQuota
                        ? AppColors.errorText
                        : AppColors.successText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testMessageController,
                  enabled: !isExpired && !hasNoQuota && !_isPlaying,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    hintText:
                        'Nhập câu hỏi test chatbot (ví dụ: tư vấn giá sản phẩm)...',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: (isExpired || hasNoQuota || _isPlaying)
                    ? null
                    : _sendTestMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isPlaying
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
          if (_playgroundResponse != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI CHATBOT PHẢN HỒI:',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _playgroundResponse!,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKnowledgeTab(ChatbotState state, ChatbotNotifier notifier) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'TÀI LIỆU KIẾN THỨC NỀN TẢNG',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tải lên các tài liệu để làm cơ sở tri thức giúp AI Chatbot trả lời thông tin chính xác về doanh nghiệp của bạn.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              AppButton(
                text: 'Thêm kiến thức',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.outline,
                onPressed: () => _showAddKnowledgeDialog(context, notifier),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          const Divider(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: AppSpacing.s),
          state.knowledgeDocuments.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(
                    child: Text(
                      'Chưa có tài liệu kiến thức nào.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.knowledgeDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = state.knowledgeDocuments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s),
                      elevation: 0,
                      color: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.description,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        title: Text(
                          doc,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Đã cập nhật: ${DateFormat('dd/MM/yyyy').format(DateTime.now())} • Cỡ file: 1.2 MB',
                          style: AppTextStyles.caption,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () {
                            notifier.removeKnowledgeDocument(doc);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã xóa tài liệu: $doc')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildLogsTab(ChatbotState state, ChatbotNotifier notifier) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NHẬT KÝ PHẢN HỒI CỦA BOT',
                  style: AppTextStyles.sectionTitle,
                ),
                if (state.logs.isNotEmpty)
                  AppButton(
                    text: 'Xóa nhật ký',
                    icon: Icons.delete_outline,
                    variant: AppButtonVariant.outline,
                    onPressed: () {
                      notifier.clearLogs();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã xóa toàn bộ nhật ký phản hồi.'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSoft),
          SizedBox(
            height: 350,
            child: AppTable(
              isEmpty: state.logs.isEmpty,
              emptyTitle: 'Chưa có lượt kích hoạt nào',
              emptyDescription:
                  'Lịch sử phản hồi tự động của chatbot sẽ được lưu trữ ở đây.',
              columns: const [
                AppTableColumn(label: 'Khách hàng', size: ColumnSize.M),
                AppTableColumn(label: 'Từ khóa kích hoạt', size: ColumnSize.S),
                AppTableColumn(label: 'Nội dung phản hồi', size: ColumnSize.L),
                AppTableColumn(label: 'Thời gian', size: ColumnSize.S),
                AppTableColumn(label: 'Trạng thái', size: ColumnSize.S),
              ],
              rows: state.logs.map((log) {
                return DataRow(
                  cells: [
                    DataCell(
                      Text(log.customerName, style: AppTextStyles.bodyMedium),
                    ),
                    DataCell(
                      AppBadge(
                        label: log.keyword,
                        variant: log.status == 'Thành công'
                            ? AppBadgeVariant.info
                            : AppBadgeVariant.neutral,
                      ),
                    ),
                    DataCell(
                      Text(
                        log.response,
                        style: AppTextStyles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat('dd/MM HH:mm').format(log.timestamp),
                        style: AppTextStyles.caption,
                      ),
                    ),
                    DataCell(
                      AppBadge(
                        label: log.status,
                        variant: log.status == 'Thành công'
                            ? AppBadgeVariant.success
                            : AppBadgeVariant.error,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordRuleDraft {
  final TextEditingController keyword = TextEditingController();
  final TextEditingController response = TextEditingController();

  void dispose() {
    keyword.dispose();
    response.dispose();
  }
}
