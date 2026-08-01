import 'live_chat_download_service_io.dart' as platform;

class LiveChatDownloadService {
  const LiveChatDownloadService();

  Future<String> download({
    required String url,
    required String fileName,
    String? directory,
  }) {
    return platform.downloadLiveChatMedia(
      url: url,
      fileName: fileName,
      directory: directory,
    );
  }
}
