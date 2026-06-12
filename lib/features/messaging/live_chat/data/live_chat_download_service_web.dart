// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String> downloadLiveChatMedia({
  required String url,
  required String fileName,
  String? directory,
}) async {
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  return fileName;
}
