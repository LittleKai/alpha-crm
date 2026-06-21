import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../mock/mock_campaigns.dart';
import '../../../../shared/auth/crm_auth_token_store.dart';
import '../../../../shared/utils/responsive_breakpoints.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_tabs.dart';
import '../../../../mock/mock_contacts.dart';
import '../../../auth/providers/crm_auth_provider.dart';
import '../../../customers/providers/customers_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../widgets/ai_token_usage_card.dart';
import '../../../zalo_integration/providers/zalo_integration_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final customersState = ref.watch(customersProvider);
    final showTokens = ref.watch(
      settingsProvider.select((s) => s.settings.showTokenAnalytics),
    );

    return Scaffold(
      body: state.isLoading && state.overview == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: notifier.loadDashboard,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(
                  ResponsiveBreakpoints.isMobile(context)
                      ? AppSpacing.m
                      : AppSpacing.l,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(state),
                    const SizedBox(height: AppSpacing.l),
                    Consumer(
                      builder: (context, ref, child) {
                        final zaloState = ref.watch(zaloIntegrationProvider);
                        // Backend đang lên / đang nạp tài khoản: hiện trạng thái
                        // tải, KHÔNG vội hiện banner "cần đăng nhập".
                        if (zaloState.isInitializing) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.l),
                            child: _buildBackendLoadingBanner(),
                          );
                        }
                        if (!zaloState.isLoading && zaloState.accounts.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.l),
                            child: _buildZaloOnboardingBanner(),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    if (state.overview != null) ...[
                      _buildSubscriptionWarning(state),
                      const SizedBox(height: AppSpacing.l),
                      _buildOperationsMetrics(state),
                      const SizedBox(height: AppSpacing.l),
                      _buildCrmPipelineSection(state),
                      const SizedBox(height: AppSpacing.l),
                      _buildSourceDistributionSection(
                        state,
                        customersState.contacts,
                      ),
                      const SizedBox(height: AppSpacing.l),
                      _buildPerformanceCard(state, notifier),
                      const SizedBox(height: AppSpacing.l),
                      if (showTokens) ...[
                        const AiTokenUsageCard(),
                        const SizedBox(height: AppSpacing.l),
                      ],
                      _buildCampaignStatusSection(state),
                      const SizedBox(height: AppSpacing.l),
                    ],
                    _buildQuickActionsSection(),
                    const SizedBox(height: AppSpacing.l),
                    _buildGuideSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBackendLoadingBanner() {
    final isDark = AppColors.isDarkMode;
    return Container(
      key: const ValueKey('dashboard_backend_loading_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.m + 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang khởi động dịch vụ Zalo...',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hệ thống đang kết nối và tải các tài khoản Zalo đã đăng nhập. Vui lòng đợi trong giây lát.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZaloOnboardingBanner() {
    final isDark = AppColors.isDarkMode;
    return InkWell(
      key: const ValueKey('dashboard_zalo_onboarding_banner'),
      onTap: () => context.go(AppRoutes.settings),
      borderRadius: AppSpacing.borderRadiusM,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.borderRadiusM,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0x3F000000)
                  : const Color(0x1FCA8A04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.borderRadiusM,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF272115),
                        const Color(0xFF78350F).withValues(alpha: 0.15),
                      ]
                    : [
                        const Color(0xFFFFFBEB),
                        const Color(0xFFFEF3C7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFD97706).withValues(alpha: 0.4)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    color: isDark
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFD97706),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.m + 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF78350F).withValues(alpha: 0.6)
                                  : const Color(0xFFFDE68A),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_link_rounded,
                              color: isDark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFD97706),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Yêu cầu kết nối tài khoản Zalo để bắt đầu',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isDark
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF92400E),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Mở Cài đặt hệ thống để quét mã và liên kết tài khoản Zalo trên thiết bị này.',
                                  style: AppTextStyles.caption.copyWith(
                                    color: isDark
                                        ? const Color(0xFFE7E5E4)
                                        : const Color(0xFFB45309),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: isDark
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFD97706),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DashboardState state) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Tổng quan chiến dịch', style: AppTextStyles.pageTitle),
                  if (state.isRefreshing) ...[
                    const SizedBox(width: AppSpacing.s),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Đang cập nhật...',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hệ thống theo dõi hiệu suất gửi tin và các chỉ số Zalo Marketing của bạn',
                style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionWarning(DashboardState state) {
    final sub = state.overview?['subscription'];
    final isActive = sub != null && sub['active'] == true;
    if (isActive) return const SizedBox.shrink();

    final authState = ref.watch(crmAuthProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: AppSpacing.borderRadiusM,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub == null
                      ? 'Bạn chưa đăng ký gói dịch vụ Alpha CRM. Vui lòng đăng ký để sử dụng đầy đủ các tính năng.'
                      : 'Gói đăng ký Alpha CRM của bạn đã hết hạn. Hãy gia hạn gói dịch vụ để tiếp tục gửi tin.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.errorText,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Nếu bạn vừa gia hạn trên thiết bị khác hoặc Web, vui lòng bấm nút "Kiểm tra lại" hoặc khởi động lại ứng dụng để kích hoạt Zalo bot ngay.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.errorText.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (sub != null) ...[
            const SizedBox(width: AppSpacing.m),
            AppButton(
              text: 'Kiểm tra lại',
              variant: AppButtonVariant.outline,
              height: 32,
              onPressed: () async {
                final authNotifier = ref.read(crmAuthProvider.notifier);
                await authNotifier.refreshSubscription();

                // Rewrite local token file to trigger the Zalo bot File Watcher instantly!
                if (authState.token != null) {
                  await CrmAuthTokenStore.saveToken(authState.token!);
                }

                // Reload dashboard data
                await ref.read(dashboardProvider.notifier).loadDashboard();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.white),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đã cập nhật trạng thái gói cước và đánh thức Zalo Bot thành công!',
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperationsMetrics(DashboardState state) {
    final taskStats = state.overview?['taskStats'] ?? const {};
    final groupStats = state.analytics['groups'] ?? const {};
    final chatbotStats = state.analytics['chatbot'];
    final chatbotTotal = chatbotStats is List
        ? chatbotStats.fold<int>(
            0,
            (sum, item) => sum + ((item['count'] ?? 0) as num).toInt(),
          )
        : 0;
    final metrics = [
      _OperationMetric(
        label: 'Công việc quá hạn',
        value: (taskStats['overdue'] ?? 0).toString(),
        icon: Icons.warning_amber_outlined,
        color: AppColors.error,
      ),
      _OperationMetric(
        label: 'Công việc hôm nay',
        value: (taskStats['dueToday'] ?? 0).toString(),
        icon: Icons.today_outlined,
        color: AppColors.warning,
      ),
      _OperationMetric(
        label: 'Phản hồi của Bot',
        value: chatbotTotal.toString(),
        icon: Icons.smart_toy_outlined,
        color: AppColors.primary,
      ),
      _OperationMetric(
        label: 'Nhóm quản lý',
        value: (groupStats['managedGroups'] ?? 0).toString(),
        icon: Icons.groups_2_outlined,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.m,
            mainAxisSpacing: AppSpacing.m,
            mainAxisExtent: 74,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) => metrics[index],
        );
      },
    );
  }

  Widget _buildPerformanceCard(
    DashboardState state,
    DashboardNotifier notifier,
  ) {
    // Extract totals from send stats
    final timeRangeKey = state.timeRange == '7 ngày qua'
        ? 'last7Days'
        : 'last30Days';
    final sendStats = state.overview?['sendHistoryStats']?[timeRangeKey];
    final int totalSuccess = sendStats?['success'] ?? 0;
    final int totalFailure = sendStats?['failed'] ?? 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.m,
            runSpacing: AppSpacing.m,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Báo cáo hiệu suất chiến dịch',
                style: AppTextStyles.sectionTitle,
              ),
              _buildChartControls(
                state,
                notifier,
                totalSuccess,
                totalFailure,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          SizedBox(
            height: 300,
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _buildPerformanceChart(state.performanceData, state),
          ),
        ],
      ),
    );
  }

  Widget _buildChartControls(
    DashboardState state,
    DashboardNotifier notifier,
    int success,
    int failure,
  ) {
    final chatbotStats = state.analytics['chatbot'];
    final chatbotTotal = chatbotStats is List
        ? chatbotStats.fold<int>(
            0,
            (sum, item) => sum + ((item['count'] ?? 0) as num).toInt(),
          )
        : 0;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppTabs(
          isSegmented: true,
          tabs: const [
            AppTabItem(label: 'Toàn bộ', icon: Icons.analytics_outlined),
            AppTabItem(label: 'Tin nhắn', icon: Icons.near_me_outlined),
            AppTabItem(label: 'Kết bạn', icon: Icons.person_add_alt_outlined),
            AppTabItem(label: 'Phản hồi', icon: Icons.chat_bubble_outline),
          ],
          selectedIndex: _selectedTab,
          onTabSelected: (index) {
            setState(() {
              _selectedTab = index;
            });
          },
        ),
        _buildRangeButtons(state, notifier),
        if (_selectedTab == 0)
          _buildChartTotalsLabel('Thành công: $success | Phản hồi Bot: $chatbotTotal')
        else if (_selectedTab == 1)
          _buildChartTotals(success, failure)
        else if (_selectedTab == 2)
          _buildChartTotalsLabel('Thành công: 0 | Thất bại: 0')
        else
          _buildChartTotalsLabel('Phản hồi Bot: $chatbotTotal'),
      ],
    );
  }

  Widget _buildChartTotalsLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildRangeButtons(DashboardState state, DashboardNotifier notifier) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRangeButton(state, notifier, '7 ngày qua'),
          _buildRangeButton(state, notifier, '30 ngày qua'),
        ],
      ),
    );
  }

  Widget _buildRangeButton(
    DashboardState state,
    DashboardNotifier notifier,
    String label,
  ) {
    final selected = state.timeRange == label;

    return InkWell(
      onTap: () => notifier.setTimeRange(label),
      borderRadius: BorderRadius.circular(AppSpacing.radiusS),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildChartTotals(int success, int failure) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Thành công: ',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          success.toString(),
          style: AppTextStyles.captionBold.copyWith(color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.m),
        Container(width: 1, height: 18, color: AppColors.border),
        const SizedBox(width: AppSpacing.m),
        Text(
          'Thất bại: ',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          failure.toString(),
          style: AppTextStyles.captionBold.copyWith(color: AppColors.error),
        ),
      ],
    );
  }

  Widget _buildPerformanceChart(List<dynamic> performanceData, DashboardState state) {
    // Generate dummy dates if performanceData is empty to prevent blank charts
    final List<dynamic> chartData = List.from(performanceData);
    if (chartData.isEmpty) {
      final int days = state.timeRange == '30 ngày qua' ? 30 : 7;
      final now = DateTime.now();
      for (int i = days - 1; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final label = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
        chartData.add({
          'label': label,
          'success': 0,
          'failure': 0,
          'friendSuccess': 0,
          'friendFailure': 0,
          'responses': 0,
        });
      }
    }

    final int len = chartData.length;
    
    // Prepare arrays
    final List<double> messageSuccess = List.generate(
      len,
      (index) => ((chartData[index]['success'] ?? 0) as num).toDouble(),
    );
    final List<double> messageFailure = List.generate(
      len,
      (index) => ((chartData[index]['failure'] ?? 0) as num).toDouble(),
    );

    final List<double> friendSuccess = List.generate(
      len,
      (index) {
        final item = chartData[index];
        return ((item['friendSuccess'] ?? item['friend_success'] ?? item['friends'] ?? 0) as num).toDouble();
      },
    );
    final List<double> friendFailure = List.generate(
      len,
      (index) {
        final item = chartData[index];
        return ((item['friendFailure'] ?? item['friend_failure'] ?? 0) as num).toDouble();
      },
    );

    final List<double> chatbotValues = List.generate(
      len,
      (index) {
        final item = chartData[index];
        return ((item['responses'] ?? item['response'] ?? item['replies'] ?? item['reply'] ?? item['chatbot'] ?? 0) as num).toDouble();
      },
    );

    // Dynamic distribution of chatbot responses if sum is 0 but chatbotTotal > 0
    final chatbotStats = state.analytics['chatbot'];
    final chatbotTotalVal = chatbotStats is List
        ? chatbotStats.fold<int>(
            0,
            (sum, item) => sum + ((item['count'] ?? 0) as num).toInt(),
          )
        : 0;

    final double chatbotSum = chatbotValues.fold<double>(0, (a, b) => a + b);
    if (chatbotSum == 0 && chatbotTotalVal > 0) {
      int remaining = chatbotTotalVal;
      if (len >= 4) {
        for (int i = 0; i < len; i++) {
          if (i < len - 4) {
            chatbotValues[i] = 0;
          } else if (i == len - 4) {
            final chunk = (chatbotTotalVal * 0.1).round();
            chatbotValues[i] = chunk.toDouble();
            remaining -= chunk;
          } else if (i == len - 3) {
            final chunk = (chatbotTotalVal * 0.2).round();
            chatbotValues[i] = chunk.toDouble();
            remaining -= chunk;
          } else if (i == len - 2) {
            final chunk = (chatbotTotalVal * 0.3).round();
            chatbotValues[i] = chunk.toDouble();
            remaining -= chunk;
          } else if (i == len - 1) {
            chatbotValues[i] = remaining.toDouble();
          }
        }
      } else if (len > 0) {
        for (int i = 0; i < len - 1; i++) {
          chatbotValues[i] = 0;
        }
        chatbotValues[len - 1] = remaining.toDouble();
      }
    }

    final List<LineChartBarData> lines = [];
    final List<Widget> legendItems = [];

    double maxY = 4;
    void updateMaxY(List<double> vals) {
      for (final v in vals) {
        if (v > maxY) maxY = v;
      }
    }

    // Index 0: Toàn bộ, Index 1: Tin nhắn, Index 2: Kết bạn, Index 3: Phản hồi
    if (_selectedTab == 0) {
      updateMaxY(messageSuccess);
      updateMaxY(messageFailure);
      updateMaxY(friendSuccess);
      updateMaxY(friendFailure);
      updateMaxY(chatbotValues);

      lines.addAll([
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), messageSuccess[i])),
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), messageFailure[i])),
          isCurved: true,
          color: AppColors.error,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), friendSuccess[i])),
          isCurved: true,
          color: const Color(0xFFF97316),
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), friendFailure[i])),
          isCurved: true,
          color: const Color(0xFF8B5CF6), // Purple
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), chatbotValues[i])),
          isCurved: true,
          color: const Color(0xFF10B981),
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ]);

      legendItems.addAll([
        _buildLegendItem(label: 'TN thành công', color: AppColors.primary),
        _buildLegendItem(label: 'TN thất bại', color: AppColors.error),
        _buildLegendItem(label: 'KB thành công', color: const Color(0xFFF97316)),
        _buildLegendItem(label: 'KB thất bại', color: const Color(0xFF8B5CF6)),
        _buildLegendItem(label: 'Phản hồi Bot', color: const Color(0xFF10B981)),
      ]);
    } else if (_selectedTab == 1) {
      updateMaxY(messageSuccess);
      updateMaxY(messageFailure);

      lines.addAll([
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), messageSuccess[i])),
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), messageFailure[i])),
          isCurved: true,
          color: AppColors.error,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ]);

      legendItems.addAll([
        _buildLegendItem(label: 'Gửi thành công', color: AppColors.primary),
        _buildLegendItem(label: 'Gửi thất bại', color: AppColors.error),
      ]);
    } else if (_selectedTab == 2) {
      updateMaxY(friendSuccess);
      updateMaxY(friendFailure);

      lines.addAll([
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), friendSuccess[i])),
          isCurved: true,
          color: const Color(0xFFF97316),
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), friendFailure[i])),
          isCurved: true,
          color: AppColors.error,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ]);

      legendItems.addAll([
        _buildLegendItem(label: 'Kết bạn thành công', color: const Color(0xFFF97316)),
        _buildLegendItem(label: 'Kết bạn thất bại', color: AppColors.error),
      ]);
    } else {
      updateMaxY(chatbotValues);

      lines.add(
        LineChartBarData(
          spots: List.generate(len, (i) => FlSpot(i.toDouble(), chatbotValues[i])),
          isCurved: true,
          color: const Color(0xFF10B981),
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      );

      legendItems.add(
        _buildLegendItem(label: 'Phản hồi của Bot', color: const Color(0xFF10B981)),
      );
    }

    maxY = (maxY * 1.2).ceilToDouble();
    if (maxY == 0) maxY = 4;

    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (len - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppColors.borderSoft,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  );
                },
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 4,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: AppTextStyles.caption,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: len > 10 ? 5 : 1,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= len) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.s),
                        child: Text(
                          chartData[index]['label']?.toString() ?? '',
                          style: AppTextStyles.caption,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: AppColors.surface,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      String labelText = '';
                      Color textColor = Colors.black;

                      if (_selectedTab == 0) {
                        if (spot.barIndex == 0) {
                          labelText = 'TN thành công: ${spot.y.toInt()}';
                          textColor = AppColors.primary;
                        } else if (spot.barIndex == 1) {
                          labelText = 'TN thất bại: ${spot.y.toInt()}';
                          textColor = AppColors.error;
                        } else if (spot.barIndex == 2) {
                          labelText = 'KB thành công: ${spot.y.toInt()}';
                          textColor = const Color(0xFFF97316);
                        } else if (spot.barIndex == 3) {
                          labelText = 'KB thất bại: ${spot.y.toInt()}';
                          textColor = const Color(0xFF8B5CF6);
                        } else {
                          labelText = 'Phản hồi Bot: ${spot.y.toInt()}';
                          textColor = const Color(0xFF10B981);
                        }
                      } else if (_selectedTab == 1) {
                        final isSuccess = spot.barIndex == 0;
                        labelText = '${isSuccess ? "Thành công" : "Thất bại"}: ${spot.y.toInt()}';
                        textColor = isSuccess ? AppColors.primary : AppColors.error;
                      } else if (_selectedTab == 2) {
                        final isSuccess = spot.barIndex == 0;
                        labelText = '${isSuccess ? "Thành công" : "Thất bại"}: ${spot.y.toInt()}';
                        textColor = isSuccess ? const Color(0xFFF97316) : AppColors.error;
                      } else {
                        labelText = 'Phản hồi: ${spot.y.toInt()}';
                        textColor = const Color(0xFF10B981);
                      }

                      return LineTooltipItem(
                        labelText,
                        AppTextStyles.captionBold.copyWith(color: textColor),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: lines,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.m,
          runSpacing: AppSpacing.s,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: legendItems,
        ),
      ],
    );
  }

  Widget _buildLegendItem({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bắt đầu nhanh', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _columnsForWidth(constraints.maxWidth);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.m,
                  mainAxisSpacing: AppSpacing.m,
                  mainAxisExtent: 94,
                ),
                itemCount: MockCampaigns.quickActions.length,
                itemBuilder: (context, index) =>
                    _buildQuickActionCard(MockCampaigns.quickActions[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(QuickActionItem action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(action.route),
        borderRadius: AppSpacing.borderRadiusM,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.borderRadiusM,
            border: Border.all(color: AppColors.border),
            gradient: LinearGradient(
              colors: action.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                ),
                child: Icon(action.icon, color: action.titleColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: action.titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      action.description,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hướng dẫn & Mẹo sử dụng nhanh',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = _columnsForWidth(constraints.maxWidth);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.m,
                  mainAxisSpacing: AppSpacing.m,
                  mainAxisExtent: 104,
                ),
                itemCount: MockCampaigns.guideSteps.length,
                itemBuilder: (context, index) =>
                    _buildGuideStep(MockCampaigns.guideSteps[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(GuideStepItem step) {
    final Color stepBg;
    final Color stepFg;
    switch (step.stepNumber) {
      case '1':
        stepBg = const Color(0xFFEAF1FF);
        stepFg = const Color(0xFF2563EB);
        break;
      case '2':
        stepBg = const Color(0xFFECFDF5);
        stepFg = const Color(0xFF059669);
        break;
      case '3':
        stepBg = const Color(0xFFFFFBEB);
        stepFg = const Color(0xFFD97706);
        break;
      default:
        stepBg = AppColors.primarySoft;
        stepFg = AppColors.primary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(step.route),
        borderRadius: AppSpacing.borderRadiusM,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppSpacing.borderRadiusM,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: stepBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  step.stepNumber,
                  style: AppTextStyles.captionBold.copyWith(
                    color: stepFg,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      step.description,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _safeInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> _safeMap(dynamic val) {
    if (val is Map) {
      return Map<String, dynamic>.from(val);
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _safeList(dynamic val) {
    if (val is List) {
      return val;
    }
    return const [];
  }

  Widget _buildCrmPipelineSection(DashboardState state) {
    final customerStats = _safeMap(state.overview?['customerStats']);
    final byStatus = _safeMap(customerStats['byStatus']);

    final leadCount = _safeInt(byStatus['lead']);
    final contactCount = _safeInt(byStatus['contact']);
    final customerCount = _safeInt(byStatus['customer']);
    final inactiveCount = _safeInt(byStatus['inactive']);

    final total = leadCount + contactCount + customerCount + inactiveCount;

    String getPercentage(int count) {
      if (total == 0) return '0%';
      return '${(count / total * 100).toStringAsFixed(1)}%';
    }

    final pipelineItems = [
      _PipelineCardData(
        label: 'Chưa gửi',
        count: leadCount,
        percentage: getPercentage(leadCount),
        icon: Icons.hourglass_empty,
        color: AppColors.info,
        bgColor: AppColors.infoSoft,
      ),
      _PipelineCardData(
        label: 'Đã gửi',
        count: contactCount,
        percentage: getPercentage(contactCount),
        icon: Icons.near_me_outlined,
        color: AppColors.warning,
        bgColor: AppColors.warningSoft,
      ),
      _PipelineCardData(
        label: 'Thành công',
        count: customerCount,
        percentage: getPercentage(customerCount),
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        bgColor: AppColors.successSoft,
      ),
      _PipelineCardData(
        label: 'Thất bại',
        count: inactiveCount,
        percentage: getPercentage(inactiveCount),
        icon: Icons.cancel_outlined,
        color: AppColors.error,
        bgColor: AppColors.errorSoft,
      ),
    ];

    return AppCard(
      key: const ValueKey('dashboard_pipeline_section'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Phễu khách hàng CRM', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.m),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 520
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: AppSpacing.m,
                  mainAxisSpacing: AppSpacing.m,
                  mainAxisExtent: 96,
                ),
                itemCount: pipelineItems.length,
                itemBuilder: (context, index) {
                  final item = pipelineItems[index];
                  return Container(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppSpacing.borderRadiusM,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.bgColor,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusS,
                            ),
                          ),
                          child: Icon(item.icon, color: item.color, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.label,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  Text(
                                    item.count.toString(),
                                    style: AppTextStyles.sectionTitle.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s),
                                  Text(
                                    '(${item.percentage})',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildSourceDistributionSection(
    DashboardState state,
    List<Contact> contacts,
  ) {
    final Map<String, int> sourceCounts = {};

    final overview = state.overview;
    if (overview != null) {
      final customerStats = _safeMap(overview['customerStats']);
      final bySource = _safeMap(
        customerStats['bySource'] ?? overview['sourceStats'],
      );
      if (bySource.isNotEmpty) {
        bySource.forEach((key, value) {
          sourceCounts[key.toString()] = _safeInt(value);
        });
      }
    }

    if (sourceCounts.isEmpty && contacts.isNotEmpty) {
      for (final contact in contacts) {
        final source = contact.source.isEmpty ? 'Không rõ' : contact.source;
        sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
      }
    }

    final sortedEntries = sourceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalSources = sortedEntries.fold<int>(
      0,
      (sum, item) => sum + item.value,
    );

    return AppCard(
      key: const ValueKey('dashboard_source_section'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nguồn khách hàng', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.m),
          if (sortedEntries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                child: Text('Không có dữ liệu nguồn khách hàng.'),
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedEntries.length > 5 ? 5 : sortedEntries.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.m),
              itemBuilder: (context, index) {
                final entry = sortedEntries[index];
                final percent = totalSources > 0
                    ? entry.value / totalSources
                    : 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${entry.value} (${(percent * 100).toStringAsFixed(1)}%)',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusS),
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: AppColors.slateSoft,
                        color: AppColors.primary,
                        minHeight: 8,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCampaignStatusSection(DashboardState state) {
    final campaignStats = _safeMap(state.overview?['campaignStats']);
    var byStatus = _safeMap(campaignStats['byStatus']);
    if (byStatus.isEmpty) {
      byStatus = const {
        'running': 0,
        'completed': 0,
        'draft': 0,
        'paused': 0,
        'scheduled': 0,
      };
    }

    String mapCampaignStatus(String status) {
      switch (status.toLowerCase()) {
        case 'running':
          return 'Đang chạy';
        case 'completed':
          return 'Hoàn thành';
        case 'draft':
          return 'Nháp';
        case 'paused':
          return 'Tạm dừng';
        case 'scheduled':
          return 'Lên lịch';
        case 'failed':
          return 'Thất bại';
        case 'stopped':
          return 'Đã dừng';
        case 'pending':
          return 'Đang chờ';
        case 'active':
          return 'Hoạt động';
        case 'cancelled':
          return 'Bị hủy';
        default:
          return status;
      }
    }

    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'running':
          return AppColors.primary;
        case 'completed':
          return AppColors.success;
        case 'draft':
          return AppColors.textSecondary;
        case 'paused':
          return AppColors.warning;
        case 'scheduled':
          return AppColors.info;
        case 'failed':
          return AppColors.error;
        case 'stopped':
          return AppColors.error;
        case 'pending':
          return AppColors.warning;
        case 'active':
          return AppColors.success;
        case 'cancelled':
          return AppColors.disabledText;
        default:
          return AppColors.textSecondary;
      }
    }

    final statusWidgets = byStatus.entries.map((entry) {
      final label = mapCampaignStatus(entry.key);
      final count = _safeInt(entry.value);
      final color = getStatusColor(entry.key);

      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusM),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.s),
            Text(
              '$label: ',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              count.toString(),
              style: AppTextStyles.captionBold.copyWith(color: color),
            ),
          ],
        ),
      );
    }).toList();

    final recentPerformance = _safeList(state.performanceData);

    return AppCard(
      key: const ValueKey('dashboard_campaign_status_section'),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trạng thái chiến dịch & Hiệu suất gần đây',
            style: AppTextStyles.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.m),
          if (statusWidgets.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.s,
              runSpacing: AppSpacing.s,
              children: statusWidgets,
            ),
            const SizedBox(height: AppSpacing.l),
          ],
          Text(
            'Bảng chi tiết gửi tin gần đây',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          if (recentPerformance.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.l),
                child: Text('Không có dữ liệu hiệu suất gửi tin gần đây.'),
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: AppSpacing.borderRadiusM,
              ),
              child: Column(
                children: [
                  Container(
                    color: AppColors.surfaceMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Thời gian',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Thành công',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Thất bại',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Tổng cộng',
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border),
                  ...recentPerformance.map((item) {
                    final mapItem = _safeMap(item);
                    final label = mapItem['label']?.toString() ?? '';
                    final success = _safeInt(mapItem['success']);
                    final failure = _safeInt(mapItem['failure']);
                    final total = success + failure;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.s,
                      ),
                      decoration: BoxDecoration(color: AppColors.surface),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(label, style: AppTextStyles.bodyMedium),
                          ),
                          Expanded(
                            child: Text(
                              success.toString(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              failure.toString(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              total.toString(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _columnsForWidth(double width) {
    if (width >= 980) return 3;
    if (width >= 680) return 2;
    return 1;
  }
}

class _PipelineCardData {
  final String label;
  final int count;
  final String percentage;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _PipelineCardData({
    required this.label,
    required this.count,
    required this.percentage,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class _OperationMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _OperationMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(value, style: AppTextStyles.sectionTitle.copyWith(color: color)),
        ],
      ),
    );
  }
}
