// health_page.dart
// 模块 C 健康首页：NEWSTART 八支柱总览 + 今日打卡进度

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'health_models.dart';
import 'health_repository.dart';
import 'health_topic_card.dart';
import 'health_topic_page.dart';
import 'health_qa_page.dart';
import 'consult_hub_page.dart';

class HealthPage extends StatefulWidget {
  final HealthRepository repo;
  final String userId;

  /// 内部预览开关（dart-define SHOW_UNREVIEWED_HEALTH=true）。
  /// 正式构建必须为 false —— 未过医学审核的条目不得展示。
  final bool previewMode;

  const HealthPage({
    super.key,
    required this.repo,
    required this.userId,
    this.previewMode = false,
  });

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  List<HealthTopic> _topics = const [];
  List<HealthMetric> _metrics = const [];
  List<HealthLogEntry> _logs = const [];
  List<HealthDailyTip> _dailyTips = const [];
  Set<int> _favTips = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavs().then((_) => _load());
  }

  Future<void> _loadFavs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('health_fav_tips') ?? [];
      if (mounted) setState(() => _favTips = list.map(int.tryParse).whereType<int>().toSet());
    } catch (_) {
      // 偏好读取失败不影响主流程
    }
  }

  Future<void> _toggleFav(int id) async {
    final set = {..._favTips};
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    setState(() => _favTips = set);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          'health_fav_tips', set.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final topics = await widget.repo.loadTopics();
      final metrics = await widget.repo.loadMetrics();
      final logs = await widget.repo.loadLogs(widget.userId);
      final tips = await widget.repo.loadDailyTips();
      if (!mounted) return;
      setState(() {
        _topics = topics;
        _metrics = metrics;
        _logs = logs;
        _dailyTips = tips;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '健康内容加载失败：$e';
        _loading = false;
      });
    }
  }

  /// 当年的第几天（1 起），用于按日期轮换每日一贴
  int get _dayOfYear {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }

  /// 今天的「健康一贴」（无数据时为 null）
  HealthDailyTip? get _todayTip {
    if (_dailyTips.isEmpty) return null;
    return _dailyTips[(_dayOfYear - 1) % _dailyTips.length];
  }

  /// NEWSTART 支柱配色
  Color _pillarColor(String pillar) {
    switch (pillar.toUpperCase()) {
      case 'NUT':
        return const Color(0xFF2E7D32);
      case 'EXE':
        return const Color(0xFF1565C0);
      case 'WAT':
        return const Color(0xFF0097A7);
      case 'SUN':
        return const Color(0xFFF9A825);
      case 'TEM':
        return const Color(0xFF6A1B9A);
      case 'AIR':
        return const Color(0xFF00796B);
      case 'RES':
        return const Color(0xFF3949AB);
      case 'TRU':
        return const Color(0xFF8D6E63);
      default:
        return const Color(0xFF607D8B);
    }
  }

  List<HealthLogEntry> get _todayLogs {
    final now = DateTime.now();
    return _logs.where((e) => e.isSameDay(now)).toList();
  }

  int _loggedCount(String topicCode) => _todayLogs
      .where((e) => e.topicCode == topicCode)
      .map((e) => e.metricId)
      .toSet()
      .length;

  int _metricCount(String topicCode) =>
      _metrics.where((m) => m.topicCode == topicCode).length;

  int get _totalDone {
    var n = 0;
    for (final t in _topics) {
      n += _loggedCount(t.code);
    }
    return n;
  }

  void _openTopic(HealthTopic t) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HealthTopicPage(
        repo: widget.repo,
        topic: t,
        metrics: _metrics.where((m) => m.topicCode == t.code).toList(),
        logs: _logs,
        userId: widget.userId,
        previewMode: widget.previewMode,
      ),
    ));
    // 从详情页返回后刷新打卡进度
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康 · NEWSTART'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final cross = c.maxWidth >= 900
                          ? 4
                          : (c.maxWidth >= 560 ? 3 : 2);
                      // Wrap 网格的卡片宽度：与旧 SliverGrid 的 12px 左右边距
                      // + 10px 间距保持一致，但卡片高度改为随内容自适应
                      const gridSpacing = 10.0;
                      final cardWidth = (c.maxWidth -
                              24 -
                              gridSpacing * (cross - 1)) /
                          cross;
                      return CustomScrollView(
                        slivers: [
                          // 顶部 Hero：今日打卡进度环 + 鼓励语（原「今日完成」横幅并入此处）
                          SliverToBoxAdapter(
                            child: _TodayProgressHeader(
                              done: _totalDone,
                              total: _metrics.length,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _DailyTipCard(
                              tip: _todayTip,
                              isFav: _todayTip != null &&
                                  _favTips.contains(_todayTip!.id),
                              pillarColor: _todayTip != null
                                  ? _pillarColor(_todayTip!.pillar)
                                  : _pillarColor('NUT'),
                              onFav: _todayTip == null
                                  ? null
                                  : () => _toggleFav(_todayTip!.id),
                            ),
                          ),
                          // 唯一的健康顾问入口（每日一贴卡内的重复按钮已移除）
                          SliverToBoxAdapter(
                            child: _HealthQaEntry(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const HealthQaPage()),
                              ),
                            ),
                          ),
                          // 专业咨询整合模块入口（v55：原「专业咨询·医药布道」
                          // 与「AI 医生助手·多轮问诊」两个平铺入口合并为一个模块，
                          // 进入后再分两个子功能）
                          SliverToBoxAdapter(
                            child: _ConsultEntry(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ConsultHubPage()),
                              ),
                            ),
                          ),
                          if (_topics.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(child: Text('暂无健康内容')),
                            )
                          else
                            // Wrap 替代固定 childAspectRatio=1.15 的网格：
                            // 卡片高度随文字字号自适应，大字号下九宫格不再
                            // 出现内容溢出重叠（NEWSTART 仅 8 个支柱，
                            // 一次性布局无性能问题）
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              sliver: SliverToBoxAdapter(
                                child: Wrap(
                                  spacing: gridSpacing,
                                  runSpacing: gridSpacing,
                                  children: [
                                    for (final t in _topics)
                                      SizedBox(
                                        width: cardWidth,
                                        child: HealthTopicCard(
                                          topic: t,
                                          loggedCount:
                                              _loggedCount(t.code),
                                          metricCount:
                                              _metricCount(t.code),
                                          onTap: () => _openTopic(t),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          // 页尾免责声明：一行小字，不再占大横幅
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                              child: Text(
                                HealthGuard.defaultDisclaimer,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

class _DailyTipCard extends StatelessWidget {
  final HealthDailyTip? tip;
  final bool isFav;
  final Color pillarColor;
  final VoidCallback? onFav;

  const _DailyTipCard({
    this.tip,
    this.isFav = false,
    this.pillarColor = const Color(0xFF2E7D32),
    this.onFav,
  });

  static String _pillarName(String p) {
    switch (p.toUpperCase()) {
      case 'NUT':
        return '营养';
      case 'EXE':
        return '运动';
      case 'WAT':
        return '水';
      case 'SUN':
        return '阳光';
      case 'TEM':
        return '节制';
      case 'AIR':
        return '空气';
      case 'RES':
        return '休息';
      case 'TRU':
        return '信靠';
      default:
        return '健康';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tip;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pillarColor.withOpacity(0.14), pillarColor.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pillarColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: pillarColor, size: 18),
                const SizedBox(width: 6),
                // Flexible：标题随字号放大可省略号收尾，不挤掉右侧收藏按钮
                const Flexible(
                  child: Text('今日健康一贴',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
                if (t != null)
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: pillarColor,
                    ),
                    onPressed: onFav,
                    tooltip: isFav ? '取消收藏' : '收藏',
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (t == null)
              const Text('今日健康一贴暂无内容，稍后再来看看～',
                  style: TextStyle(fontSize: 13, color: Colors.black54))
            else ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: pillarColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _pillarName(t.pillar),
                  style: TextStyle(
                      fontSize: 10.5,
                      color: pillarColor,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(t.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, height: 1.4)),
              const SizedBox(height: 4),
              Text(t.body,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Colors.black87)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text('来源：${t.source}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.black54)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthQaEntry extends StatelessWidget {
  final VoidCallback? onTap;

  const _HealthQaEntry({this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
        ),
        child: ListTile(
          leading:
              const Icon(Icons.health_and_safety, color: Color(0xFF2E7D32)),
          title: const Text('有问题？问问健康顾问',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('关于饮食、运动、睡眠、节制等，本地即时回答（不替代医生）',
              style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );
}

class _ConsultEntry extends StatelessWidget {
  final VoidCallback? onTap;

  const _ConsultEntry({this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6A1B9A).withOpacity(0.3)),
        ),
        child: ListTile(
          leading:
              const Icon(Icons.medical_services, color: Color(0xFF6A1B9A)),
          title: const Text('专业咨询',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text('材料核验 · 医药布道 + AI 多轮问诊，一个模块全流程（不替代医生）',
              style: TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );
}

class _TodayProgressHeader extends StatelessWidget {
  final int done;
  final int total;

  const _TodayProgressHeader({required this.done, required this.total});

  /// 随完成度变化的鼓励语（人性化反馈）
  String get _encourage {
    if (total == 0) return '今天也要好好照顾自己';
    if (done >= total) return '今日全部完成，身心舒畅！';
    if (done == 0) return '从一个小习惯开始吧';
    return '开了个好头，继续保持～';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 54,
                  height: 54,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: cs.primary.withOpacity(0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                ),
                // FittedBox(scaleDown)：数字随字号放大超出 54px 环时自动
                // 缩小，永远完整落在环内（不截断、不溢出）
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$done',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: cs.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日打卡  $done / $total',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
                const SizedBox(height: 2),
                Text(_encourage,
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color)),
                const SizedBox(height: 2),
                Text('轻点下方卡片，记录今日的健康习惯',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
