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
import '../../../../settings/providers/settings_provider.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_select_field.dart';
import '../../../../../shared/widgets/app_table.dart';
import '../../../../../shared/widgets/app_tabs.dart';
import '../../providers/chatbot_provider.dart';
import '../widgets/account_target_dialog.dart';
import '../../../../zalo_integration/providers/zalo_integration_provider.dart';
import '../../../../../shared/widgets/account_avatar_stack.dart';
import '../../../../auth/providers/crm_auth_provider.dart';
import '../../../../groups/manage/providers/managed_groups_provider.dart';
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

  // Ids of knowledge files present on this machine (null until first loaded).
  // Used to flag entries whose local file is missing (e.g. attached elsewhere).
  Set<String>? _knowledgeIdsPresent;

  @override
  void initState() {
    super.initState();
    _refreshKnowledgePresence();
  }

  Future<void> _refreshKnowledgePresence() async {
    final ids = await ref
        .read(chatbotProvider.notifier)
        .knowledgeFileIdsPresent();
    if (!mounted) return;
    setState(() => _knowledgeIdsPresent = ids);
  }

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

    final aiApiKeys = ref.read(chatbotProvider).aiApiKeys;

    final response = await CrmCloudApi.post('/crm/chatbot/test', {
      'message': msg,
      'aiModel': _selectedModel,
      'systemPrompt': _promptController.text,
      'soulPrompt': _soulController.text,
      'responseRules': _rulesController.text,
      'temperature': _tempValue,
      'aiApiKeys': aiApiKeys,
    });

    setState(() {
      _isPlaying = false;
    });

    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _playgroundResponse = response['data']['text']?.toString();
      });

      if (response['data']['usage'] != null) {
        final usage = response['data']['usage'];
        final promptTokens =
            usage['promptTokens'] ?? usage['prompt_tokens'] ?? 0;
        final completionTokens =
            usage['completionTokens'] ?? usage['completion_tokens'] ?? 0;
        print(
          '🧮 [AI TOKENS] Input: $promptTokens | Output: $completionTokens | Total: ${promptTokens + completionTokens}',
        );
      }

      ref.read(crmAuthProvider.notifier).refreshSubscription();
    } else {
      setState(() {
        _playgroundResponse =
            'Lỗi: ${response['message'] ?? "Không nhận được phản hồi từ AI."}';
      });
    }
  }

  Future<void> _showRuleDialog(
    BuildContext context, {
    ChatbotRule? rule,
  }) async {
    final nameController = TextEditingController(text: rule?.name);
    final descriptionController = TextEditingController(
      text: rule?.description,
    );
    final drafts = rule != null
        ? [
            _KeywordRuleDraft()
              ..keyword.text = rule.keyword
              ..response.text = rule.response,
          ]
        : [_KeywordRuleDraft()];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: rule != null
                  ? 'Chỉnh sửa kịch bản chatbot'
                  : 'Tạo kịch bản chatbot mới',
              icon: Icons.smart_toy_outlined,
              width: 640,
              actions: [
                AppDialogAction(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppDialogAction(
                  text: rule != null ? 'Lưu thay đổi' : 'Tạo kịch bản',
                  icon: rule != null ? Icons.save_rounded : Icons.add_rounded,
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
                    if (rule != null) {
                      await notifier.updateRule(
                        rule.id,
                        keyword: validDrafts.first.keyword.text,
                        response: validDrafts.first.response.text,
                        name: nameController.text,
                        description: descriptionController.text,
                      );
                    } else {
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
                            Icon(
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
                              if (drafts.length > 1 && rule == null)
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
                            Divider(height: 1, color: AppColors.borderSoft),
                            const SizedBox(height: AppSpacing.m),
                          ],
                        ],
                        if (rule == null) ...[
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

  Future<void> _showKnowledgeDialog(
    BuildContext context,
    ChatbotNotifier notifier, {
    int? editIndex,
    String? existingDoc,
  }) async {
    final ParsedKnowledgeDoc? parsed = existingDoc != null
        ? parseKnowledgeDoc(existingDoc)
        : null;
    final titleController = TextEditingController(text: parsed?.title);
    final keywordsController = TextEditingController(text: parsed?.keywords);
    final contentController = TextEditingController(text: parsed?.content);

    final List<_UploadedFileState> filesList = [];
    if (parsed != null) {
      for (final f in parsed.files) {
        filesList.add(
          _UploadedFileState(
            filename: f.name,
            id: f.id,
            description: f.description,
          ),
        );
      }
    }

    var isUploading = false;
    String? uploadError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Nút "Chọn thêm file" có thể mở nhiều lần để bổ sung; mỗi lần cho
            // chọn nhiều file, không còn giới hạn 5 file. File sau khi đính kèm
            // được tự phân vào 4 nhóm (ảnh / video / âm thanh / tệp) theo đuôi.
            Future<void> pickAndUploadFiles() async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
                withData: true,
                type: FileType.any,
              );
              if (result == null || result.files.isEmpty) return;

              setDialogState(() {
                isUploading = true;
                uploadError = null;
              });

              for (final file in result.files) {
                if (file.bytes == null) {
                  setDialogState(() {
                    uploadError = 'Không đọc được file: ${file.name}';
                  });
                  continue;
                }

                final response = await notifier.uploadKnowledgeFile(
                  filename: file.name,
                  bytes: file.bytes!,
                );

                if (response['success'] == true && response['data'] is Map) {
                  final data = Map<String, dynamic>.from(
                    response['data'] as Map,
                  );
                  final id = data['id']?.toString() ?? '';
                  setDialogState(() {
                    filesList.add(
                      _UploadedFileState(filename: file.name, id: id),
                    );
                  });
                } else {
                  setDialogState(() {
                    uploadError =
                        (response['message'] ??
                                'Upload file ${file.name} thất bại.')
                            .toString();
                  });
                }
              }

              setDialogState(() {
                isUploading = false;
              });
            }

            bool isValid() {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isEmpty || content.isEmpty) return false;
              for (final f in filesList) {
                if (f.descriptionController.text.trim().isEmpty) {
                  return false;
                }
              }
              return true;
            }

            Widget buildFileCard(_UploadedFileState f) {
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.s),
                elevation: 0,
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _attachmentTypeIcon(_attachmentTypeOf(f.filename)),
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              f.filename,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.error,
                              size: 18,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                filesList.remove(f);
                                f.dispose();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: f.descriptionController,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Mô tả sơ lược (bắt buộc) *',
                          hintText:
                              'VD: Catalogue sản phẩm, Bảng báo giá tháng 6...',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return AppDialog(
              title: editIndex != null
                  ? 'Chỉnh sửa tài liệu kiến thức'
                  : 'Thêm tài liệu kiến thức mới',
              icon: Icons.description_outlined,
              width: 640,
              actions: [
                AppDialogAction(
                  text: 'Hủy',
                  variant: AppButtonVariant.outline,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppDialogAction(
                  text: editIndex != null ? 'Lưu thay đổi' : 'Thêm tài liệu',
                  icon: editIndex != null
                      ? Icons.save_rounded
                      : Icons.add_rounded,
                  onPressed: !isValid() || isUploading
                      ? null
                      : () {
                          final title = titleController.text.trim();
                          final keywords = keywordsController.text.trim();
                          final content = contentController.text.trim();

                          final fileLines = filesList
                              .map((f) {
                                return '- [File] Tên: ${f.filename} | ID: ${f.id} | Mô tả: ${f.descriptionController.text.trim()}';
                              })
                              .join('\n');

                          final baseText = [
                            'Tiêu đề tài liệu: $title',
                            if (keywords.isNotEmpty)
                              'Từ khóa kích hoạt: $keywords',
                            'Nội dung kiến thức bắt buộc:\n$content',
                            if (filesList.isNotEmpty)
                              'Files đính kèm:\n$fileLines\nQuy tắc gửi: AI chỉ chọn file/ảnh phù hợp khi khách hỏi khớp từ khóa hoặc nội dung kiến thức; agent Zalo trên máy người dùng sẽ thực hiện gửi file/ảnh thật.',
                          ].join('\n\n');
                          // Preserve per-account targeting set via the card action.
                          final text = setKnowledgeDocAccounts(
                            baseText,
                            parsed?.accountIds ?? const [],
                          );

                          final Future<void> action = editIndex != null
                              ? notifier.updateKnowledgeDocument(
                                  editIndex,
                                  text,
                                )
                              : notifier.addKnowledgeDocument(text);

                          action.then((_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    editIndex != null
                                        ? 'Đã cập nhật kiến thức: $title'
                                        : 'Đã thêm kiến thức: $title',
                                  ),
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
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề tài liệu *',
                      hintText: 'VD: Chính sách giao hàng',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextField(
                    controller: keywordsController,
                    onChanged: (_) => setDialogState(() {}),
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
                    onChanged: (_) => setDialogState(() {}),
                    minLines: 6,
                    maxLines: 10,
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
                        'Tài liệu đính kèm (${filesList.length})',
                        style: AppTextStyles.label,
                      ),
                      AppButton(
                        text: isUploading ? 'Đang upload' : 'Chọn thêm file',
                        icon: Icons.upload_file_outlined,
                        variant: AppButtonVariant.outline,
                        isLoading: isUploading,
                        onPressed: isUploading ? null : pickAndUploadFiles,
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
                    child: filesList.isEmpty
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
                        : Builder(
                            builder: (context) {
                              // Tự phân các file đã đính kèm vào 4 nhóm theo đuôi.
                              final groups =
                                  <
                                    KnowledgeAttachmentType,
                                    List<_UploadedFileState>
                                  >{};
                              for (final f in filesList) {
                                groups
                                    .putIfAbsent(
                                      _attachmentTypeOf(f.filename),
                                      () => [],
                                    )
                                    .add(f);
                              }
                              const order = [
                                KnowledgeAttachmentType.image,
                                KnowledgeAttachmentType.video,
                                KnowledgeAttachmentType.audio,
                                KnowledgeAttachmentType.file,
                              ];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (uploadError != null) ...[
                                    Text(
                                      uploadError!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.errorText,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.s),
                                  ],
                                  for (final type in order)
                                    if ((groups[type] ?? const [])
                                        .isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: AppSpacing.xs,
                                          bottom: AppSpacing.xs,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _attachmentTypeIcon(type),
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            Text(
                                              '${_attachmentTypeLabel(type)} (${groups[type]!.length})',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ...groups[type]!.map(buildFileCard),
                                    ],
                                ],
                              );
                            },
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
    for (final f in filesList) {
      f.dispose();
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
                'Bot luôn kiểm tra kịch bản từ khóa trước; chỉ khi không khớp và AI đang bật, hệ thống mới dùng AI để tạo câu trả lời.',
                'Kịch bản từ khóa là so khớp cố định nên KHÔNG tốn lượt AI; chỉ câu trả lời do AI tạo (ở tab Trí tuệ nhân tạo) mới tính lượt.',
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
        Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 32),
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
            onPressed: () => _showRuleDialog(context),
          ),
      ],
    );

    return Scaffold(
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

  /// Resolves account ids to avatar entries (avatar + clean name) for the
  /// stacked avatars on a rule/knowledge card. Unknown ids fall back to a
  /// placeholder so the count still reflects the selection.
  List<AvatarEntry> _resolveRuleAccounts(List<String> ids) {
    final accounts = ref.read(zaloIntegrationProvider).accounts;
    return ids.map((id) {
      final match = accounts.where((a) => a.id == id);
      if (match.isNotEmpty) {
        final a = match.first;
        return (avatarUrl: a.avatarUrl, name: accountDisplayName(a.label));
      }
      return (avatarUrl: '', name: '');
    }).toList();
  }

  Future<void> _showRuleAccountDialog(ChatbotRule rule) async {
    final accounts = ref.read(zaloIntegrationProvider).accounts;
    final result = await showAccountTargetDialog(
      context: context,
      accounts: accounts,
      selectedIds: rule.accountIds,
      title: 'Áp dụng kịch bản cho tài khoản',
    );
    if (result == null) return;
    await ref
        .read(chatbotProvider.notifier)
        .updateRuleAccounts(rule.id, result);
  }

  Future<void> _showKnowledgeAccountDialog(int index, String doc) async {
    final accounts = ref.read(zaloIntegrationProvider).accounts;
    final parsed = parseKnowledgeDoc(doc);
    final result = await showAccountTargetDialog(
      context: context,
      accounts: accounts,
      selectedIds: parsed.accountIds,
      title: 'Áp dụng tài liệu cho tài khoản',
    );
    if (result == null) return;
    await ref
        .read(chatbotProvider.notifier)
        .updateKnowledgeDocument(index, setKnowledgeDocAccounts(doc, result));
  }

  Widget _buildKeywordTab(ChatbotState state, ChatbotNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _keywordMasterHeader(state, notifier),
        const SizedBox(height: AppSpacing.m),
        AnimatedOpacity(
          opacity: state.keywordRulesEnabled ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 150),
          child: _buildKeywordRulesContent(state, notifier),
        ),
      ],
    );
  }

  Widget _keywordMasterHeader(ChatbotState state, ChatbotNotifier notifier) {
    final on = state.keywordRulesEnabled;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sử dụng kịch bản từ khóa',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      on
                          ? 'Bot trả lời bằng kịch bản cố định khi khớp từ khóa.'
                          : 'Đang tắt — bỏ qua toàn bộ kịch bản từ khóa.',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => notifier.setKeywordRulesEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusS),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    'Kịch bản từ khóa là so khớp cố định nên KHÔNG tốn lượt AI. '
                    'Chỉ câu trả lời do AI tạo (tab Trí tuệ nhân tạo) mới tính lượt.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordRulesContent(
    ChatbotState state,
    ChatbotNotifier notifier,
  ) {
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
              onPressed: () => _showRuleDialog(context),
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
                            tooltip: 'Áp dụng cho tài khoản',
                            icon: Icon(
                              Icons.groups_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => _showRuleAccountDialog(rule),
                          ),
                          IconButton(
                            tooltip: 'Chỉnh sửa kịch bản',
                            icon: Icon(
                              Icons.edit_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () =>
                                _showRuleDialog(context, rule: rule),
                          ),
                          IconButton(
                            tooltip: 'Xóa kịch bản',
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
                  Divider(height: 1, color: AppColors.borderSoft),
                  const SizedBox(height: AppSpacing.s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trạng thái: ${rule.isActive ? "Đang hoạt động" : "Tạm ngưng"}',
                        style: AppTextStyles.caption.copyWith(
                          color: rule.isActive
                              ? AppColors.successText
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      rule.accountIds.isEmpty
                          ? Row(
                              children: [
                                Icon(
                                  Icons.public_outlined,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Mọi TK',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            )
                          : AccountAvatarStack(
                              size: 24,
                              accounts: _resolveRuleAccounts(rule.accountIds),
                            ),
                    ],
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
    var selectedProvider = state.aiProvider;
    var providerConfig =
        findProviderConfig(selectedProvider) ?? chatbotAiProviderConfigs.first;
    final modelTextController = TextEditingController(text: state.aiModel);
    final promptController = TextEditingController(text: state.systemPrompt);
    final soulController = TextEditingController(text: state.soulPrompt);
    final rulesController = TextEditingController(text: state.responseRules);
    var temperature = state.temperature;
    var debounceSeconds = state.debounceSeconds;
    var aiHistoryLimit = state.aiHistoryLimit;
    final dialogApiKeys = <String, List<String>>{
      for (final e in state.aiApiKeys.entries)
        e.key: List<String>.from(e.value),
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final needsKey = providerConfig.requiresApiKey;
            final providerKeys = dialogApiKeys[selectedProvider] ?? [];
            final hasKeys = providerKeys.any((k) => k.trim().isNotEmpty);

            return AppDialog(
              title: 'Cài đặt AI Chatbot',
              subtitle:
                  'Chọn nhà cung cấp AI, model và tùy chỉnh prompt cho chatbot tự động.',
              icon: Icons.psychology_outlined,
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
                    final selectedModel = modelTextController.text.trim();
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(dialogContext);
                    final cleanedKeys = <String, List<String>>{
                      for (final e in dialogApiKeys.entries)
                        if (e.value.any((k) => k.trim().isNotEmpty))
                          e.key: e.value
                              .where((k) => k.trim().isNotEmpty)
                              .toList(),
                    };
                    notifier.updateAiApiKeys(cleanedKeys);
                    notifier
                        .updateAiConfig(
                          provider: selectedProvider,
                          model: selectedModel,
                          prompt: promptController.text.trim(),
                          soulPrompt: soulController.text.trim(),
                          responseRules: rulesController.text.trim(),
                          temperature: temperature,
                          debounceSeconds: debounceSeconds,
                          aiHistoryLimit: aiHistoryLimit,
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
                  // ── Provider + Model row ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nhà cung cấp AI', style: AppTextStyles.label),
                            const SizedBox(height: AppSpacing.xs),
                            AppSelectField<String>(
                              value: selectedProvider,
                              items: chatbotAiProviderConfigs.map((p) {
                                return DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.label,
                                    style: AppTextStyles.body,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                final newConfig = findProviderConfig(value);
                                if (newConfig == null) return;
                                setDialogState(() {
                                  selectedProvider = value;
                                  providerConfig = newConfig;
                                  modelTextController.text =
                                      newConfig.defaultModel;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Model', style: AppTextStyles.label),
                                if (selectedProvider != 'alpha_studio') ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Tooltip(
                                    message:
                                        'Chọn từ danh sách hoặc nhập model code tùy ý',
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (selectedProvider == 'alpha_studio')
                              AppSelectField<String>(
                                value:
                                    [
                                      'gemini-3-flash',
                                      'gemini-2.5-pro',
                                    ].contains(modelTextController.text)
                                    ? modelTextController.text
                                    : 'gemini-3-flash',
                                itemHeight: 56,
                                items: [
                                  DropdownMenuItem(
                                    value: 'gemini-3-flash',
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Gemini 3 Flash',
                                          style: AppTextStyles.body.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tốc độ phản hồi siêu tốc',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'gemini-2.5-pro',
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Gemini 2.5 Pro',
                                          style: AppTextStyles.body.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Khả năng suy luận logic phức tạp',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                selectedItemBuilder: (context) {
                                  return [
                                    Text(
                                      'Gemini 3 Flash',
                                      style: AppTextStyles.body,
                                    ),
                                    Text(
                                      'Gemini 2.5 Pro',
                                      style: AppTextStyles.body,
                                    ),
                                  ];
                                },
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      modelTextController.text = val;
                                    });
                                  }
                                },
                              )
                            else
                              SizedBox(
                                height: 42,
                                child: TextField(
                                  controller: modelTextController,
                                  style: AppTextStyles.body,
                                  decoration: InputDecoration(
                                    hintText: providerConfig.defaultModel,
                                    hintStyle: AppTextStyles.caption.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                    contentPadding: const EdgeInsets.only(
                                      left: 12,
                                      right: 0,
                                      top: 0,
                                      bottom: 0,
                                    ),
                                    filled: true,
                                    fillColor:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.borderSoft,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppColors.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                    suffixIcon: PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                      tooltip: 'Chọn preset model',
                                      offset: const Offset(0, 46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      elevation: 4,
                                      onSelected: (model) {
                                        setDialogState(() {
                                          modelTextController.text = model;
                                        });
                                      },
                                      itemBuilder: (_) {
                                        final menuItems =
                                            <PopupMenuEntry<String>>[];
                                        for (
                                          int i = 0;
                                          i <
                                              providerConfig
                                                  .presetModels
                                                  .length;
                                          i++
                                        ) {
                                          final m =
                                              providerConfig.presetModels[i];
                                          menuItems.add(
                                            PopupMenuItem(
                                              value: m,
                                              height: 42,
                                              child: Text(
                                                m,
                                                style: AppTextStyles.body,
                                              ),
                                            ),
                                          );
                                          if (i <
                                              providerConfig
                                                      .presetModels
                                                      .length -
                                                  1) {
                                            menuItems.add(
                                              const PopupMenuDivider(height: 1),
                                            );
                                          }
                                        }
                                        return menuItems;
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── Info / Warning for provider ──
                  if (selectedProvider == 'alpha_studio') ...[
                    const SizedBox(height: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppSpacing.borderRadiusS,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              'Sử dụng quota GCLI từ gói đăng ký Alpha Studio. Không cần API key.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (needsKey && !hasKeys) ...[
                    const SizedBox(height: AppSpacing.s),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: AppSpacing.borderRadiusS,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: AppColors.warningText,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              'Cần ít nhất 1 API key cho ${providerConfig.label}. Thêm key ở phần bên dưới.',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.warningText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  // ── Collapsible: Prompt Configuration ──
                  _buildCollapsibleSection(
                    title: 'Cấu hình Prompt',
                    icon: Icons.edit_note_outlined,
                    initiallyExpanded: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Prompt mặc định', style: AppTextStyles.label),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: promptController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Chỉ định cách chatbot phản hồi khách hàng...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Text(
                          'Soul / đối tượng nhập vai',
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextField(
                          controller: soulController,
                          maxLines: 3,
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
                          minLines: 4,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText:
                                'VD: Không bịa thông tin, không lặp lời chào...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  // ── Collapsible: Settings (Temperature + Debounce) ──
                  _buildCollapsibleSection(
                    title: 'Cài đặt nâng cao',
                    icon: Icons.tune_outlined,
                    initiallyExpanded: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Độ sáng tạo (Temperature): ${temperature.toStringAsFixed(1)}',
                              style: AppTextStyles.label,
                            ),
                            Text(
                              temperature < 0.4
                                  ? 'Chính xác'
                                  : temperature > 0.8
                                  ? 'Sáng tạo'
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
                            setDialogState(() => temperature = value);
                          },
                        ),
                        const SizedBox(height: AppSpacing.s),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Chờ khách nhập thêm: $debounceSeconds giây',
                              style: AppTextStyles.label,
                            ),
                            Text(
                              debounceSeconds >= 60
                                  ? '${(debounceSeconds / 60).toStringAsFixed(1)} phút'
                                  : '$debounceSeconds giây',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: debounceSeconds.toDouble(),
                          min: 10,
                          max: 120,
                          divisions: 22,
                          activeColor: AppColors.primary,
                          label: '$debounceSeconds giây',
                          onChanged: (value) {
                            setDialogState(
                              () => debounceSeconds = value.round(),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Số tin nhắn gần nhất AI đọc',
                              style: AppTextStyles.label,
                            ),
                            Text(
                              aiHistoryLimit == 0
                                  ? 'Tắt (không đọc lịch sử)'
                                  : '$aiHistoryLimit lượt',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Mỗi lượt = một loạt tin liên tiếp của cùng một người. '
                          'AI dùng số lượt này làm ngữ cảnh khi trả lời.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        Slider(
                          value: aiHistoryLimit.toDouble(),
                          min: 0,
                          max: 20,
                          divisions: 20,
                          activeColor: AppColors.primary,
                          label: aiHistoryLimit == 0
                              ? 'Tắt'
                              : '$aiHistoryLimit lượt',
                          onChanged: (value) {
                            setDialogState(
                              () => aiHistoryLimit = value.round(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s),
                  // ── Collapsible: API Keys ──
                  _buildCollapsibleSection(
                    title: 'API Keys',
                    icon: Icons.vpn_key_outlined,
                    subtitle:
                        'Nhập key riêng cho các nhà cung cấp — hệ thống xoay vòng ngẫu nhiên',
                    initiallyExpanded: needsKey && !hasKeys,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: chatbotAiProviderConfigs
                          .where((p) => p.requiresApiKey)
                          .map((provider) {
                            final keys = dialogApiKeys[provider.id] ?? [];
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.m,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        provider.label,
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                      const SizedBox(width: AppSpacing.s),
                                      if (keys.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.successSoft,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '${keys.length} key',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: AppColors.successText,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      const Spacer(),
                                      SizedBox(
                                        height: 28,
                                        child: TextButton.icon(
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('Thêm key'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            textStyle: AppTextStyles.caption,
                                          ),
                                          onPressed: () {
                                            setDialogState(() {
                                              dialogApiKeys[provider.id] = [
                                                ...keys,
                                                '',
                                              ];
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  ...keys.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final keyValue = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpacing.xs,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '#${idx + 1}',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                  color: AppColors.textMuted,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(width: AppSpacing.s),
                                          Expanded(
                                            child: TextField(
                                              controller: TextEditingController(
                                                text: keyValue,
                                              ),
                                              style: AppTextStyles.body
                                                  .copyWith(fontSize: 13),
                                              obscureText: true,
                                              decoration: InputDecoration(
                                                hintText: provider.keyHint,
                                                hintStyle: AppTextStyles.caption
                                                    .copyWith(
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                border:
                                                    const OutlineInputBorder(),
                                              ),
                                              onChanged: (v) {
                                                dialogApiKeys[provider
                                                    .id]![idx] = v
                                                    .trim();
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              iconSize: 16,
                                              icon: const Icon(
                                                Icons.close,
                                                color: AppColors.error,
                                              ),
                                              tooltip: 'Xóa key',
                                              onPressed: () {
                                                setDialogState(() {
                                                  dialogApiKeys[provider.id]!
                                                      .removeAt(idx);
                                                  if (dialogApiKeys[provider
                                                          .id]!
                                                      .isEmpty) {
                                                    dialogApiKeys.remove(
                                                      provider.id,
                                                    );
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    modelTextController.dispose();
    promptController.dispose();
    soulController.dispose();
    rulesController.dispose();
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    String? subtitle,
    bool initiallyExpanded = false,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.m,
          0,
          AppSpacing.m,
          AppSpacing.m,
        ),
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, size: 18, color: AppColors.primary),
        title: Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        children: [child],
      ),
    );
  }

  Widget _buildAudienceTargeting(ChatbotState state, ChatbotNotifier notifier) {
    final managedGroups = ref
        .watch(managedGroupsProvider)
        .groups
        .where((group) => group.isManaged)
        .toList();
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
          _buildBridgeStatus(state, notifier),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Icon(
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
          Divider(height: 1, color: AppColors.borderSoft),
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
          if (state.groupAudience == 'selected') ...[
            const SizedBox(height: AppSpacing.s),
            if (managedGroups.isEmpty)
              Text(
                'Chưa có nhóm Zalo nào được đánh dấu quản lý.',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              )
            else
              ...managedGroups.map((group) {
                final key = '${group.accountId}:${group.groupId}';
                final selected = state.selectedGroupKeys.contains(key);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected,
                  title: Text(group.name),
                  subtitle: Text(group.accountId),
                  onChanged: (checked) {
                    final keys = {...state.selectedGroupKeys};
                    if (checked == true) {
                      keys.add(key);
                    } else {
                      keys.remove(key);
                    }
                    notifier.updateAudienceConfig(
                      selectedGroupKeys: keys.toList()..sort(),
                    );
                  },
                );
              }),
          ],
        ],
      ),
    );
  }

  Widget _buildBridgeStatus(ChatbotState state, ChatbotNotifier notifier) {
    final status = state.bridgeStatus;
    final healthy =
        status?.running == true &&
        (state.bridgeSyncWarning == null || state.bridgeSyncWarning!.isEmpty);
    final label = healthy
        ? 'Chatbot local đang hoạt động'
        : status?.running == true
        ? 'Cấu hình chatbot chưa đồng bộ'
        : 'Local bridge đang ngoại tuyến';
    final color = healthy ? AppColors.success : AppColors.warning;
    return Row(
      children: [
        Icon(
          healthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: AppSpacing.s),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ),
        TextButton(
          onPressed: state.isSyncingBridge ? null : notifier.syncBridgeNow,
          child: Text(state.isSyncingBridge ? 'Đang đồng bộ...' : 'Thử lại'),
        ),
      ],
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
              Icon(
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
          Divider(height: 1, color: AppColors.borderSoft),
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
                Icon(
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
                    '${state.aiModel} (${state.aiModel == 'gemini-3.1-pro-preview' || state.aiModel == 'gemini-3.5-flash' ? '2' : '1'} quota/lượt)',
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
          if (state.aiModel == 'gemini-3.1-pro-preview' || state.aiModel == 'gemini-3.5-flash') ...[
            const SizedBox(height: AppSpacing.m),
            AppAlert(
              message:
                  'Model ${state.aiModel} dùng quota gấp đôi. Backend sẽ trừ 2 lượt cho mỗi lần AI trả lời thành công và hoàn lại nếu upstream GCLI lỗi.',
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
                onPressed: () async {
                  await _showKnowledgeDialog(context, notifier);
                  await _refreshKnowledgePresence();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Divider(height: 1, color: AppColors.borderSoft),
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
                    final parsed = parseKnowledgeDoc(doc);
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s),
                      elevation: 0,
                      color: AppColors.surfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.description,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          title: Text(
                            parsed.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (parsed.keywords.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const AppBadge(
                                      label: 'Từ khóa',
                                      variant: AppBadgeVariant.neutral,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        parsed.keywords,
                                        style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                parsed.content,
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      spacing: AppSpacing.xs,
                                      runSpacing: AppSpacing.xs,
                                      children: [
                                        ...parsed.files.map((file) {
                                          final present = _knowledgeIdsPresent;
                                          final isMissing =
                                              present != null &&
                                              (file.id.isEmpty ||
                                                  !present.contains(file.id));
                                          final chipColor = isMissing
                                              ? AppColors.error
                                              : AppColors.primary;
                                          return Tooltip(
                                            message: isMissing
                                                ? 'File chưa có trên máy này — hãy đính lại để bot gửi được.'
                                                : (file.description.isNotEmpty
                                                      ? 'Mô tả: ${file.description}'
                                                      : 'Tài liệu đính kèm'),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isMissing
                                                    ? AppColors.error
                                                          .withValues(
                                                            alpha: 0.10,
                                                          )
                                                    : AppColors.primarySoft,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isMissing
                                                      ? AppColors.error
                                                      : AppColors.borderSoft,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isMissing
                                                        ? Icons
                                                              .warning_amber_rounded
                                                        : Icons.attach_file,
                                                    size: 10,
                                                    color: chipColor,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    isMissing
                                                        ? '${file.name} • thiếu file'
                                                        : file.name,
                                                    style: AppTextStyles.caption
                                                        .copyWith(
                                                          color: chipColor,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s),
                                  parsed.accountIds.isEmpty
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.public_outlined,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Mọi tài khoản',
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    color: AppColors.textMuted,
                                                  ),
                                            ),
                                          ],
                                        )
                                      : AccountAvatarStack(
                                          size: 22,
                                          accounts: _resolveRuleAccounts(
                                            parsed.accountIds,
                                          ),
                                        ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Áp dụng cho tài khoản',
                                icon: Icon(
                                  Icons.groups_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () =>
                                    _showKnowledgeAccountDialog(index, doc),
                              ),
                              IconButton(
                                tooltip: 'Chỉnh sửa tài liệu',
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () async {
                                  await _showKnowledgeDialog(
                                    context,
                                    notifier,
                                    editIndex: index,
                                    existingDoc: doc,
                                  );
                                  await _refreshKnowledgePresence();
                                },
                              ),
                              IconButton(
                                tooltip: 'Xóa tài liệu',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () {
                                  notifier.removeKnowledgeDocument(doc);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Đã xóa tài liệu: ${parsed.title}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  String _chatbotModeLabel(String mode) {
    switch (mode) {
      case 'keyword':
        return 'Từ khóa';
      case 'ai':
        return 'AI';
      case 'handoff':
        return 'Chuyển NV';
      case 'none':
      case '':
        return '—';
      default:
        return mode;
    }
  }

  String _chatbotStatusLabel(String status) {
    switch (status) {
      case 'succeeded':
        return 'Thành công';
      case 'skipped':
        return 'Bị bỏ qua';
      case 'failed':
        return 'Thất bại';
      default:
        return status;
    }
  }

  AppBadgeVariant _chatbotStatusVariant(String status) {
    switch (status) {
      case 'succeeded':
        return AppBadgeVariant.success;
      case 'failed':
        return AppBadgeVariant.error;
      default:
        return AppBadgeVariant.neutral;
    }
  }

  int _logsCurrentPage = 0;
  final int _logsItemsPerPage = 30;
  String _logsFilterCategory = 'Tất cả';

  Widget _buildLogsTab(ChatbotState state, ChatbotNotifier notifier) {
    final showTokens = ref.watch(settingsProvider).settings.showTokenAnalytics;

    // Filter logs
    final filteredLogs = state.logs.where((log) {
      if (_logsFilterCategory == 'Tất cả') return true;
      if (_logsFilterCategory == 'AI') return log.keyword == 'ai';
      if (_logsFilterCategory == 'Từ khóa') return log.keyword == 'keyword';
      if (_logsFilterCategory == 'Chuyển NV') return log.keyword == 'handoff';
      if (_logsFilterCategory == 'Khác')
        return !['ai', 'keyword', 'handoff'].contains(log.keyword);
      return true;
    }).toList();

    // Pagination
    final int totalPages = (filteredLogs.length / _logsItemsPerPage).ceil();
    if (_logsCurrentPage >= totalPages && totalPages > 0) {
      _logsCurrentPage = totalPages - 1;
    }
    final paginatedLogs = filteredLogs
        .skip(_logsCurrentPage * _logsItemsPerPage)
        .take(_logsItemsPerPage)
        .toList();

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
                Row(
                  children: [
                    Text(
                      'NHẬT KÝ PHẢN HỒI CỦA BOT',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(width: AppSpacing.l),
                    SizedBox(
                      width: 160,
                      child: AppSelectField<String>(
                        value: _logsFilterCategory,
                        items: ['Tất cả', 'AI', 'Từ khóa', 'Chuyển NV', 'Khác']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _logsFilterCategory = val;
                              _logsCurrentPage = 0;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderSoft),
          SizedBox(
            // Fill the viewport instead of a small fixed box (the screen body
            // is a scroll view, so Expanded cannot be used here).
            height: (MediaQuery.of(context).size.height - 320).clamp(
              350.0,
              double.infinity,
            ),
            child: AppTable(
              isEmpty: filteredLogs.isEmpty,
              emptyTitle: 'Không có dữ liệu',
              emptyDescription:
                  'Không tìm thấy nhật ký nào phù hợp với bộ lọc.',
              columns: [
                const AppTableColumn(label: 'Khách hàng', size: ColumnSize.M),
                const AppTableColumn(
                  label: 'Từ khóa kích hoạt',
                  size: ColumnSize.S,
                  textAlign: TextAlign.center,
                ),
                const AppTableColumn(
                  label: 'Nội dung phản hồi',
                  size: ColumnSize.L,
                ),
                const AppTableColumn(label: 'Thời gian', size: ColumnSize.S),
                const AppTableColumn(
                  label: 'Trạng thái',
                  size: ColumnSize.S,
                  textAlign: TextAlign.center,
                ),
                if (showTokens)
                  const AppTableColumn(
                    label: 'Token (Vào/Ra)',
                    size: ColumnSize.S,
                  ),
              ],
              rows: paginatedLogs.map((log) {
                final succeeded = log.status == 'succeeded';

                AppBadgeVariant badgeVariant = AppBadgeVariant.neutral;
                if (succeeded) {
                  if (log.keyword == 'ai') {
                    badgeVariant = AppBadgeVariant.info;
                  } else if (log.keyword == 'keyword') {
                    badgeVariant = AppBadgeVariant.success;
                  } else if (log.keyword == 'handoff') {
                    badgeVariant = AppBadgeVariant.warning;
                  } else {
                    badgeVariant = AppBadgeVariant.neutral;
                  }
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Text(log.customerName, style: AppTextStyles.bodyMedium),
                    ),
                    DataCell(
                      Center(
                        child: AppBadge(
                          label: _chatbotModeLabel(log.keyword),
                          variant: badgeVariant,
                        ),
                      ),
                    ),
                    DataCell(
                      Tooltip(
                        message: log.response,
                        child: Text(
                          log.response,
                          style: AppTextStyles.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat('dd/MM HH:mm').format(log.timestamp),
                        style: AppTextStyles.caption,
                      ),
                    ),
                    DataCell(
                      Center(
                        child: AppBadge(
                          label: _chatbotStatusLabel(log.status),
                          variant: _chatbotStatusVariant(log.status),
                        ),
                      ),
                    ),
                    if (showTokens)
                      DataCell(
                        Text(
                          '${log.tokenIn} / ${log.tokenOut}',
                          style: AppTextStyles.caption,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _logsCurrentPage > 0
                        ? () => setState(() => _logsCurrentPage--)
                        : null,
                  ),
                  Text(
                    'Trang ${_logsCurrentPage + 1} / $totalPages',
                    style: AppTextStyles.bodyMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _logsCurrentPage < totalPages - 1
                        ? () => setState(() => _logsCurrentPage++)
                        : null,
                  ),
                ],
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

class ParsedKnowledgeDoc {
  final String title;
  final String keywords;
  final String content;
  final List<ParsedKnowledgeFile> files;

  /// Zalo account ids this document applies to. Empty = all accounts.
  final List<String> accountIds;

  ParsedKnowledgeDoc({
    required this.title,
    required this.keywords,
    required this.content,
    required this.files,
    this.accountIds = const [],
  });
}

final RegExp _knowledgeAccountsLine = RegExp(r'(?:^|\n)\[Accounts\][^\n]*');

/// Replace/append the `[Accounts]` tag on a knowledge snippet. Empty ids = all
/// accounts (no tag). The tag lives on its own line at the end of the snippet
/// and is stripped from the AI prompt by the bridge before sending.
String setKnowledgeDocAccounts(String doc, List<String> accountIds) {
  final cleaned = doc.replaceAll(_knowledgeAccountsLine, '').trimRight();
  final ids = accountIds.where((id) => id.trim().isNotEmpty).toList();
  if (ids.isEmpty) return cleaned;
  return '$cleaned\n[Accounts] ${ids.join(', ')}';
}

class ParsedKnowledgeFile {
  final String name;
  final String description;
  // Local bridge knowledge-store id. Empty for legacy B2 entries (now missing).
  final String id;

  ParsedKnowledgeFile({
    required this.name,
    required this.description,
    required this.id,
  });
}

ParsedKnowledgeDoc parseKnowledgeDoc(String doc) {
  String title = '';
  String keywords = '';
  String content = '';
  List<ParsedKnowledgeFile> files = [];

  // Pull out the per-account targeting tag first so it never pollutes the
  // title/content/file parsing below.
  List<String> accountIds = [];
  final accountsMatch = _knowledgeAccountsLine.firstMatch(doc);
  if (accountsMatch != null) {
    final raw = accountsMatch.group(0) ?? '';
    final value = raw.replaceFirst(RegExp(r'\s*\[Accounts\]'), '').trim();
    accountIds = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    doc = doc.replaceAll(_knowledgeAccountsLine, '').trimRight();
  }

  final titleIndex = doc.indexOf('Tiêu đề tài liệu:');
  final keywordIndex = doc.indexOf('Từ khóa kích hoạt:');
  final contentIndex = doc.indexOf('Nội dung kiến thức bắt buộc:\n');

  final fileIndexMulti = doc.indexOf('Files đính kèm:\n');
  final fileIndexSingle = doc.indexOf('File/ảnh đính kèm:\n');
  final fileIndex = fileIndexMulti != -1 ? fileIndexMulti : fileIndexSingle;

  // Extract title
  if (titleIndex != -1) {
    int end = doc.length;
    if (keywordIndex != -1 && keywordIndex > titleIndex) {
      end = keywordIndex;
    } else if (contentIndex != -1 && contentIndex > titleIndex) {
      end = contentIndex;
    } else if (fileIndex != -1 && fileIndex > titleIndex) {
      end = fileIndex;
    }
    title = doc.substring(titleIndex + 'Tiêu đề tài liệu:'.length, end).trim();
  }

  // Extract keywords
  if (keywordIndex != -1) {
    int end = doc.length;
    if (contentIndex != -1 && contentIndex > keywordIndex) {
      end = contentIndex;
    } else if (fileIndex != -1 && fileIndex > keywordIndex) {
      end = fileIndex;
    }
    keywords = doc
        .substring(keywordIndex + 'Từ khóa kích hoạt:'.length, end)
        .trim();
  }

  // Extract content
  if (contentIndex != -1) {
    int end = doc.length;
    if (fileIndex != -1 && fileIndex > contentIndex) {
      end = fileIndex;
    }
    content = doc
        .substring(contentIndex + 'Nội dung kiến thức bắt buộc:\n'.length, end)
        .trim();
  }

  // Extract files
  if (fileIndex != -1) {
    final fileSection = doc.substring(fileIndex).trim();
    final lines = fileSection.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('-')) {
        if (fileIndexMulti != -1) {
          // Format: - [File] Tên: [FileName] | ID: [LocalId] | Mô tả: [Description]
          // Legacy docs used "URL:" (B2) — kept with an empty id so the UI flags
          // them as missing and prompts a re-attach.
          final cleanLine = trimmed.substring(1).trim(); // Remove '-'
          final parts = cleanLine.split('|');
          String name = '';
          String id = '';
          String desc = '';
          for (final part in parts) {
            final p = part.trim();
            if (p.startsWith('[File] Tên:')) {
              name = p.substring('[File] Tên:'.length).trim();
            } else if (p.startsWith('Tên:')) {
              name = p.substring('Tên:'.length).trim();
            } else if (p.startsWith('ID:')) {
              id = p.substring('ID:'.length).trim();
            } else if (p.startsWith('Mô tả:')) {
              desc = p.substring('Mô tả:'.length).trim();
            }
          }
          if (name.isNotEmpty) {
            files.add(
              ParsedKnowledgeFile(name: name, description: desc, id: id),
            );
          }
        }
      }
    }

    // Legacy single-file format (B2 URL, no local id) — surface it as a missing
    // entry (empty id) so the operator is prompted to re-attach.
    if (fileIndexSingle != -1 && files.isEmpty) {
      String name = '';
      final lines = fileSection.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('- Tên:')) {
          name = trimmed.substring('- Tên:'.length).trim();
        }
      }
      if (name.isNotEmpty) {
        files.add(
          ParsedKnowledgeFile(
            name: name,
            description: 'Tài liệu đính kèm',
            id: '',
          ),
        );
      }
    }
  }

  if (title.isEmpty) {
    title = doc.split('\n').first;
  }

  return ParsedKnowledgeDoc(
    title: title,
    keywords: keywords,
    content: content,
    files: files,
    accountIds: accountIds,
  );
}

/// Bốn nhóm media mà tài liệu kiến thức hỗ trợ đính kèm. Nhóm được suy ra từ
/// đuôi file để tự phân loại sau khi chọn (xem [_attachmentTypeOf]).
enum KnowledgeAttachmentType { image, video, audio, file }

KnowledgeAttachmentType _attachmentTypeOf(String filename) {
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  const image = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'svg',
  };
  const video = {
    'mp4',
    'mov',
    'avi',
    'webm',
    'mkv',
    'm4v',
    '3gp',
    'flv',
    'wmv',
  };
  const audio = {
    'mp3',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'flac',
    'amr',
    'wma',
  };
  if (image.contains(ext)) return KnowledgeAttachmentType.image;
  if (video.contains(ext)) return KnowledgeAttachmentType.video;
  if (audio.contains(ext)) return KnowledgeAttachmentType.audio;
  return KnowledgeAttachmentType.file;
}

String _attachmentTypeLabel(KnowledgeAttachmentType type) => switch (type) {
  KnowledgeAttachmentType.image => 'Hình ảnh',
  KnowledgeAttachmentType.video => 'Video',
  KnowledgeAttachmentType.audio => 'Âm thanh',
  KnowledgeAttachmentType.file => 'Tệp tài liệu',
};

IconData _attachmentTypeIcon(KnowledgeAttachmentType type) => switch (type) {
  KnowledgeAttachmentType.image => Icons.image_outlined,
  KnowledgeAttachmentType.video => Icons.videocam_outlined,
  KnowledgeAttachmentType.audio => Icons.audiotrack_outlined,
  KnowledgeAttachmentType.file => Icons.insert_drive_file_outlined,
};

class _UploadedFileState {
  final String filename;
  // Content-hash id of the file stored in the LOCAL bridge knowledge store.
  // Empty for legacy entries (previously on B2) — these render as "missing".
  final String id;
  final TextEditingController descriptionController;

  _UploadedFileState({
    required this.filename,
    required this.id,
    String description = '',
  }) : descriptionController = TextEditingController(text: description);

  void dispose() {
    descriptionController.dispose();
  }
}
