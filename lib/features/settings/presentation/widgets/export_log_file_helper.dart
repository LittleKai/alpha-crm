import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_button.dart';

/// Ghi [content] ra một file .txt trong `Downloads/AlphaCRM` và hiển thị dialog
/// hỏi người dùng có muốn mở thư mục chứa file không. Dùng chung cho cả tab
/// "Lỗi đã ghi nhận" và tab "Nhật ký trực tiếp" để đồng nhất luồng export.
Future<void> exportLogTextToFile({
  required BuildContext context,
  required String content,
  required String fileNamePrefix,
  required String dialogTitle,
}) async {
  try {
    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      throw Exception('Không tìm thấy thư mục Downloads trên hệ thống.');
    }

    final crmDir = Directory('${downloadsDir.path}${Platform.pathSeparator}AlphaCRM');
    if (!await crmDir.exists()) {
      await crmDir.create(recursive: true);
    }

    final timeStr = DateTime.now().toLocal().toString().replaceAll(RegExp(r'[:. ]'), '_');
    final fileName = '${fileNamePrefix}_$timeStr.txt';
    final filePath = '${crmDir.path}${Platform.pathSeparator}$fileName';

    final file = File(filePath);
    await file.writeAsString(content);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: dialogTitle,
        icon: Icons.folder_open_outlined,
        actions: [
          AppDialogAction(
            text: 'Đóng',
            variant: AppButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppDialogAction(
            text: 'Mở thư mục',
            variant: AppButtonVariant.primary,
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              try {
                final folderUri = Uri.parse('file:///${crmDir.path.replaceAll(r'\', '/')}');
                if (await canLaunchUrl(folderUri)) {
                  await launchUrl(folderUri);
                } else {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể mở thư mục tự động.')),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi mở thư mục: $e')),
                );
              }
            },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'File đã được lưu thành công tại:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.s),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s),
              color: AppColors.surfaceMuted,
              child: SelectableText(
                filePath,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            const Text('Bạn có muốn mở thư mục chứa tệp tin này không?'),
          ],
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi trích xuất: $e'), backgroundColor: Colors.red),
    );
  }
}
