// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> saveToken(String token) async {
  html.window.localStorage['alpha_studio_token'] = token;
}

Future<String?> getToken() async {
  return html.window.localStorage['alpha_studio_token'];
}

Future<void> deleteToken() async {
  html.window.localStorage.remove('alpha_studio_token');
}
