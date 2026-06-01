/// Sanitizes Zalo avatar/image URLs that may use protocol-relative double slashes.
/// Prepend 'https:' if the URL starts with '//' to prevent UNC path resolution
/// errors (e.g. 'Unsupported scheme file in URI' on Windows).
String sanitizeImageUrl(String url) {
  if (url.startsWith('//')) {
    return 'https:$url';
  }
  return url;
}
