enum CrmChannel {
  zaloPersonal('zalo_personal', 'Zalo cá nhân'),
  zaloOa('zalo_oa', 'Zalo OA'),
  facebookPage('facebook_page', 'Trang Facebook'),
  tiktok('tiktok', 'TikTok'),
  email('email', 'Email');

  final String apiValue;
  final String label;

  const CrmChannel(this.apiValue, this.label);

  static CrmChannel fromApiValue(String value) {
    return CrmChannel.values.firstWhere(
      (channel) => channel.apiValue == value,
      orElse: () => CrmChannel.zaloPersonal,
    );
  }
}
