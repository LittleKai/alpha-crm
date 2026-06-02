import 'package:flutter/material.dart';

class NavItem {
  final String title;
  final IconData icon;
  final String routePath;

  const NavItem({
    required this.title,
    required this.icon,
    required this.routePath,
  });
}

class NavGroup {
  final String groupName;
  final List<NavItem> items;

  const NavGroup({required this.groupName, required this.items});
}

final List<NavGroup> navigationGroups = [
  const NavGroup(
    groupName: 'TỔNG QUAN',
    items: [
      NavItem(
        title: 'Tổng quan chiến dịch',
        icon: Icons.dashboard_outlined,
        routePath: '/dashboard',
      ),
    ],
  ),
  const NavGroup(
    groupName: 'CRM',
    items: [
      NavItem(
        title: 'CRM Khách Hàng',
        icon: Icons.people_outline,
        routePath: '/customers',
      ),
      NavItem(
        title: 'Tin mẫu nhanh',
        icon: Icons.quickreply_outlined,
        routePath: '/content/templates',
      ),
      NavItem(
        title: 'Cong viec follow-up',
        icon: Icons.task_alt_outlined,
        routePath: '/tasks',
      ),
    ],
  ),
  const NavGroup(
    groupName: 'CHỨC NĂNG NHẮN TIN',
    items: [
      NavItem(
        title: 'Gửi tin hàng loạt',
        icon: Icons.send_outlined,
        routePath: '/messaging/bulk',
      ),
      NavItem(
        title: 'Nhắn tin Live Chat',
        icon: Icons.chat_bubble_outline,
        routePath: '/messaging/live-chat',
      ),
      NavItem(
        title: 'Chatbot tự động',
        icon: Icons.smart_toy_outlined,
        routePath: '/messaging/chatbot',
      ),
      NavItem(
        title: 'Lịch sử gửi tin',
        icon: Icons.history_outlined,
        routePath: '/messaging/history',
      ),
    ],
  ),
  const NavGroup(
    groupName: 'CHỨC NĂNG KẾT BẠN',
    items: [
      NavItem(
        title: 'Kết bạn theo SĐT',
        icon: Icons.person_add_alt_outlined,
        routePath: '/friends/by-phone',
      ),
      NavItem(
        title: 'Kết bạn từ Nhóm',
        icon: Icons.group_add_outlined,
        routePath: '/friends/by-group',
      ),
      NavItem(
        title: 'Tự động Duyệt',
        icon: Icons.done_all_outlined,
        routePath: '/friends/auto-approve',
      ),
      NavItem(
        title: 'Lịch sử kết bạn',
        icon: Icons.rule_folder_outlined,
        routePath: '/friends/history',
      ),
    ],
  ),
  const NavGroup(
    groupName: 'QUẢN LÝ NHÓM',
    items: [
      NavItem(
        title: 'Quét thành viên',
        icon: Icons.person_search_outlined,
        routePath: '/groups/scan-members',
      ),
      NavItem(
        title: 'Tham gia nhóm',
        icon: Icons.login_outlined,
        routePath: '/groups/join',
      ),
      NavItem(
        title: 'Mời vào nhóm',
        icon: Icons.person_add_outlined,
        routePath: '/groups/invite',
      ),
      NavItem(
        title: 'Tạo nhóm',
        icon: Icons.create_new_folder_outlined,
        routePath: '/groups/create',
      ),
      NavItem(
        title: 'Rời nhóm',
        icon: Icons.logout_outlined,
        routePath: '/groups/leave',
      ),
      NavItem(
        title: 'Quan ly nhom CRM',
        icon: Icons.groups_2_outlined,
        routePath: '/groups/manage',
      ),
    ],
  ),
  const NavGroup(
    groupName: 'TÀI KHOẢN & THIẾT BỊ',
    items: [
      NavItem(
        title: 'Đăng ký & Gói AI',
        icon: Icons.card_membership_outlined,
        routePath: '/subscription',
      ),
      NavItem(
        title: 'Ghép đôi thiết bị',
        icon: Icons.sensors_outlined,
        routePath: '/devices',
      ),
    ],
  ),
  const NavGroup(
    groupName: 'CÀI ĐẶT',
    items: [
      NavItem(
        title: 'Cài đặt hệ thống',
        icon: Icons.settings_outlined,
        routePath: '/settings',
      ),
    ],
  ),
];
