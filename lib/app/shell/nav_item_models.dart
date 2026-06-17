import 'package:flutter/material.dart';

class NavItem {
  final String title;
  final IconData icon;
  final String routePath;
  final Color? color;

  const NavItem({
    required this.title,
    required this.icon,
    required this.routePath,
    this.color,
  });
}

class NavGroup {
  final String groupName;
  final List<NavItem> items;
  final bool isCollapsible;
  final bool defaultExpanded;

  const NavGroup({
    required this.groupName,
    required this.items,
    this.isCollapsible = false,
    this.defaultExpanded = true,
  });
}

final List<NavGroup> navigationGroups = [
  const NavGroup(
    groupName: 'TỔNG QUAN',
    items: [
      NavItem(
        title: 'Tổng quan chiến dịch',
        icon: Icons.dashboard_outlined,
        routePath: '/dashboard',
        color: Colors.blueAccent,
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
        color: Colors.orangeAccent,
      ),
      NavItem(
        title: 'Công việc follow-up',
        icon: Icons.task_alt_outlined,
        routePath: '/tasks',
        color: Colors.green,
      ),
      NavItem(
        title: 'Tự động hóa',
        icon: Icons.account_tree_outlined,
        routePath: '/workflows',
        color: Colors.purpleAccent,
      ),
    ],
  ),
  const NavGroup(
    groupName: 'CHỨC NĂNG NHẮN TIN',
    items: [
      NavItem(
        title: 'Nhắn tin Live Chat',
        icon: Icons.chat_bubble_outline,
        routePath: '/messaging/live-chat',
        color: Colors.teal,
      ),
      NavItem(
        title: 'Gửi tin hàng loạt',
        icon: Icons.send_outlined,
        routePath: '/messaging/bulk',
        color: Colors.lightBlue,
      ),
      NavItem(
        title: 'Chatbot tự động',
        icon: Icons.smart_toy_outlined,
        routePath: '/messaging/chatbot',
        color: Colors.indigoAccent,
      ),
      NavItem(
        title: 'Lịch sử gửi tin',
        icon: Icons.history_outlined,
        routePath: '/messaging/history',
        color: Colors.blueGrey,
      ),
    ],
  ),
  const NavGroup(
    groupName: 'CHỨC NĂNG KẾT BẠN',
    isCollapsible: true,
    defaultExpanded: false,
    items: [
      NavItem(
        title: 'Kết bạn theo SĐT',
        icon: Icons.person_add_alt_outlined,
        routePath: '/friends/by-phone',
        color: Colors.deepOrangeAccent,
      ),
      NavItem(
        title: 'Kết bạn từ Nhóm',
        icon: Icons.group_add_outlined,
        routePath: '/friends/by-group',
        color: Colors.brown,
      ),
      NavItem(
        title: 'Tự động Duyệt',
        icon: Icons.done_all_outlined,
        routePath: '/friends/auto-approve',
        color: Colors.lightGreen,
      ),
      NavItem(
        title: 'Lịch sử kết bạn',
        icon: Icons.rule_folder_outlined,
        routePath: '/friends/history',
        color: Colors.grey,
      ),
    ],
  ),
  const NavGroup(
    groupName: 'QUẢN LÝ NHÓM',
    isCollapsible: true,
    defaultExpanded: false,
    items: [
      NavItem(
        title: 'Quét thành viên',
        icon: Icons.person_search_outlined,
        routePath: '/groups/scan-members',
        color: Colors.cyan,
      ),
      NavItem(
        title: 'Tham gia nhóm',
        icon: Icons.login_outlined,
        routePath: '/groups/join',
        color: Colors.amber,
      ),
      NavItem(
        title: 'Mời vào nhóm',
        icon: Icons.person_add_outlined,
        routePath: '/groups/invite',
        color: Colors.pinkAccent,
      ),
      NavItem(
        title: 'Tạo nhóm',
        icon: Icons.create_new_folder_outlined,
        routePath: '/groups/create',
        color: Colors.deepPurpleAccent,
      ),
      NavItem(
        title: 'Rời nhóm',
        icon: Icons.logout_outlined,
        routePath: '/groups/leave',
        color: Colors.redAccent,
      ),
      NavItem(
        title: 'Quản lý nhóm CRM',
        icon: Icons.groups_2_outlined,
        routePath: '/groups/manage',
        color: Colors.tealAccent,
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
        color: Colors.yellow,
      ),
      NavItem(
        title: 'Ghép đôi thiết bị',
        icon: Icons.sensors_outlined,
        routePath: '/devices',
        color: Colors.blueAccent,
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
        color: Colors.blueGrey,
      ),
    ],
  ),
];
