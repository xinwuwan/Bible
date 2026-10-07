// main.dart
// 应用入口 + 统一导航外壳（BottomNavigationBar 整合模块 A 对照 / B 牧师问答 / C 健康）
//
// 启动流程:
//   1. 加载 web / 桌面 / 手机通用的 JSON 离线资源（assets/web/app_data.json）
//   2. 构建注记 / 问答数据源（远端 API / 本地资产或 Mock，二选一）
//   3. 进入统一外壳：底部三个 Tab —— 对照 / 问答 / 健康
//
// 发布开关（用 dart-define 注入，默认均为安全值）:
//   --dart-define=API_BASE=https://...       后端地址
//   --dart-define=USE_REMOTE_NOTES=true      启用远端注记（默认 false，用本地资产）
//   --dart-define=USE_REMOTE_QA=true         启用远端问答 RAG（默认 false，用 Mock）
//   --dart-define=SHOW_DRAFT_NOTES=true      【仅联调】展示 draft 注记，正式构建切勿开启
//   --dart-define=SHOW_UNREVIEWED_HEALTH=true 【仅联调】展示未过医学审核的健康条目

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_models.dart';
import 'app_theme.dart';
import 'comparison_page.dart';
import 'health_page.dart';
import 'health_repository.dart';
import 'note_repository.dart';
import 'offline_db_helper.dart';
import 'onboarding_page.dart';
import 'qa_models.dart';
import 'qa_page.dart';
import 'qa_repository.dart';
import 'offline_qa_repository.dart';
import 'search_page.dart';

const String kApiBaseUrl =
    String.fromEnvironment('API_BASE', defaultValue: 'https://api.example.com');
const bool kUseRemoteNotes =
    bool.fromEnvironment('USE_REMOTE_NOTES', defaultValue: false);
const bool kDraftMode =
    bool.fromEnvironment('SHOW_DRAFT_NOTES', defaultValue: false);
// 问答默认走 Mock（无后端时的界面演示）。正式构建必须置 true 走远端 RAG。
const bool kUseRemoteQa =
    bool.fromEnvironment('USE_REMOTE_QA', defaultValue: false);
// 健康模块：默认只展示已过医学审核的条目（合规闸门）。正式构建必须为 false。
const bool kHealthPreview =
    bool.fromEnvironment('SHOW_UNREVIEWED_HEALTH', defaultValue: false);

/// 把引用 ref（如 'JHN 3:16'）解析为可跳转的章节定位；无法定位返回 null。
Map<String, dynamic>? locateRef(String ref) {
  if (!OfflineDbHelper.isAvailable) return null;
  final parts = ref.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return null;
  final code = parts[0].toUpperCase();
  final chapter = int.tryParse(parts[1].split(':').first);
  if (chapter == null) return null;
  for (final b in OfflineDbHelper.getBooks()) {
    if ((b['book_code'] as String).toUpperCase() == code) {
      return {
        'bookId': b['book_id'] as int,
        'chapter': chapter,
        'name': b['name_zh'] as String,
        'count': b['chapter_count'] as int,
      };
    }
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 加载 web / 桌面 / 手机通用的 JSON 离线资源（网页端也能正常初始化）。
  try {
    await OfflineDbHelper.load();
    await OfflineDbHelper.loadLogsCache();
    // 预载离线问答索引（链接里模块 B 即可本地真实回答，无需后端）。
    try {
      await OfflineQaRepository.load();
    } catch (e) {
      debugPrint('offline qa load failed: $e');
    }
  } catch (e) {
    // 离线资源加载失败不阻断应用：模块 A/C 显示友好提示，模块 B 仍可用。
    debugPrint('offline data load failed: $e');
  }
  runApp(const FaithApp());
}

class FaithApp extends StatelessWidget {
  const FaithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '真理对照',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppRoot(),
    );
  }
}

/// 首次启动引导闸门：检测 onboarding 标记，未看过则先展示引导页，之后直达主外壳。
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  static const String _kOnboardingSeen = 'onboarding_seen_v1';

  final Future<bool> _seen = SharedPreferences.getInstance()
      .then((p) => p.getBool(_kOnboardingSeen) ?? false);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _seen,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == true) return const HomePage();
        return OnboardingPage(
          onFinish: () async {
            final p = await SharedPreferences.getInstance();
            await p.setBool(_kOnboardingSeen, true);
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        );
      },
    );
  }
}

/// 统一导航外壳：底部三个 Tab（对照 / 问答 / 健康），每个 Tab 各自维护一个 Navigator，
/// 使得 Tab 内的页面跳转（打开章节、引用跳回、打开健康主题）不会顶掉底部导航栏。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final NoteRepository _notes;
  late final QaRepository _qaRepo;
  int _tab = 0;
  final List<GlobalKey<NavigatorState>> _navKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _notes = kUseRemoteNotes
        ? RemoteNoteRepository(baseUrl: kApiBaseUrl)
        : const AssetNoteRepository();
    // 无后端时（默认）使用离线问答：链接里模块 B 即可本地真实回答，无需任何服务。
    _qaRepo = kUseRemoteQa
        ? RemoteQaRepository(baseUrl: kApiBaseUrl)
        : (OfflineQaRepository.instance ?? MockQaRepository());
  }

  @override
  void dispose() {
    // 用局部变量承接，避免多余的类型转换（私有 final 字段可类型提升）
    final notes = _notes;
    if (notes is RemoteNoteRepository) notes.client.close();
    final qa = _qaRepo;
    if (qa is RemoteQaRepository) qa.client.close();
    super.dispose();
  }

  /// 在「当前 Tab 的 Navigator」里打开对照页（问答/健康的引用跳转复用此方法）
  void _openBook(BuildContext context, BookMeta b, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComparisonPage(
          bookId: b.bookId,
          bookName: b.nameZh,
          chapterCount: b.chapterCount,
          initialChapter: chapter,
          notes: _notes,
          draftMode: kDraftMode,
        ),
      ),
    );
  }

  /// 问答引用跳转：BIBLE 跳对照页，其余提示待接入
  void _onOpenCitation(BuildContext context, QaCitation c) {
    if (c.sourceType != QaSourceType.bible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${c.sourceType.label}原文阅读器待接入：${c.ref}')),
      );
      return;
    }
    final loc = locateRef(c.ref);
    if (loc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('离线库暂无该处原文：${c.ref}')),
      );
      return;
    }
    _openBook(
      context,
      BookMeta(
        bookId: loc['bookId'] as int,
        bookCode: '',
        nameZh: loc['name'] as String,
        testament: '',
        chapterCount: loc['count'] as int,
      ),
      loc['chapter'] as int,
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return Navigator(
          key: _navKeys[0],
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => HomeScreen(
              notes: _notes,
              draftMode: kDraftMode,
              onOpenBook: _openBook,
            ),
          ),
        );
      case 1:
        return Navigator(
          key: _navKeys[1],
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (ctx) => QaTab(
              repo: _qaRepo,
              onOpenCitation: (c) => _onOpenCitation(ctx, c),
            ),
          ),
        );
      case 2:
        return Navigator(
          key: _navKeys[2],
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const HealthTab(),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: List.generate(3, _buildTab),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '对照',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: '问答',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: '健康',
          ),
        ],
      ),
    );
  }
}

/// 模块 A 首页（对照 Tab 的根页面）：书卷目录 + 搜索入口
class HomeScreen extends StatefulWidget {
  final NoteRepository notes;
  final bool draftMode;
  final void Function(BuildContext, BookMeta, int) onOpenBook;

  const HomeScreen({
    super.key,
    required this.notes,
    required this.draftMode,
    required this.onOpenBook,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BookMeta> _books = [];
  String? _initError;
  bool _unsupported = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() {
    if (!OfflineDbHelper.isAvailable) {
      setState(() {
        _unsupported = true;
        _initError = '离线圣经内容加载失败，请稍后重试或使用桌面 / 手机版。';
      });
      return;
    }
    try {
      final rows = OfflineDbHelper.getBooks();
      setState(() => _books = rows.map(BookMeta.fromDbRow).toList());
    } catch (e) {
      setState(() => _initError = '离线库未就绪：${e.toString()}');
    }
  }

  Future<void> _openSearch() async {
    final loc = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
    if (loc == null || !mounted) return;
    widget.onOpenBook(
      context,
      BookMeta(
        bookId: loc['bookId'] as int,
        bookCode: '',
        nameZh: loc['name'] as String,
        testament: '',
        chapterCount: loc['count'] as int,
      ),
      loc['chapter'] as int,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('真理对照')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _initError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _unsupported ? Colors.black54 : cs.error,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    final ot = _books.where((b) => b.testament == 'OT').toList();
    final nt = _books.where((b) => b.testament == 'NT').toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('真理对照'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: _unsupported ? '网页端暂不支持' : '搜索经文',
            icon: const Icon(Icons.search),
            onPressed: _unsupported ? null : _openSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索入口（点按进入经文搜索页）
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _unsupported ? null : _openSearch,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: AppTheme.inkSoft),
                    const SizedBox(width: 10),
                    Text(
                      '搜索经文、章节…',
                      style: TextStyle(fontSize: 14, color: AppTheme.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _books.isEmpty
                ? Center(
                    child: Text(
                      '离线库暂无书卷数据',
                      style: TextStyle(color: AppTheme.inkSoft, fontSize: 14),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _SectionTitle('旧约 · Old Testament', count: ot.length),
                      _BookGrid(books: ot, onTap: (b) => widget.onOpenBook(context, b, 1)),
                      _SectionTitle('新约 · New Testament', count: nt.length),
                      _BookGrid(books: nt, onTap: (b) => widget.onOpenBook(context, b, 1)),
                      const SizedBox(height: 8),
                      // 权威层级说明（合规：始终让用户知道什么是权威、什么是参照）
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.line),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.verified_user_outlined,
                                  size: 16, color: AppTheme.gold),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '权威依据：KJV 英文原文（唯一底本）。中文译文采用公共领域的和合本（1919），供对照阅读。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.inkSoft,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 模块 B（问答 Tab）：包装 QaPage，提供引用跳回对照页的回调
class QaTab extends StatelessWidget {
  final QaRepository repo;
  final ValueChanged<QaCitation> onOpenCitation;

  const QaTab({super.key, required this.repo, required this.onOpenCitation});

  @override
  Widget build(BuildContext context) => QaPage(repo: repo, onOpenCitation: onOpenCitation);
}

/// 模块 C（健康 Tab）：包装 HealthPage（离线优先，读预置库中的 health_* 表）
class HealthTab extends StatelessWidget {
  const HealthTab({super.key});

  @override
  Widget build(BuildContext context) {
    // 离线内容未就绪时显示友好提示，避免崩溃（正常初始化后不会触发）。
    if (!OfflineDbHelper.isAvailable) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '健康模块内容加载失败，请稍后重试或使用桌面 / 手机版。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14, height: 1.5),
            ),
          ),
        ),
      );
    }
    return HealthPage(
      repo: const OfflineHealthRepository(),
      userId: 'local',
      previewMode: kHealthPreview,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final int count;

  const _SectionTitle(this.text, {this.count = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
              letterSpacing: 0.3,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$count 卷',
              style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookGrid extends StatelessWidget {
  final List<BookMeta> books;
  final ValueChanged<BookMeta> onTap;

  const _BookGrid({required this.books, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 168,
          mainAxisExtent: 64,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) => _BookCard(book: books[i], onTap: onTap),
      ),
    );
  }
}

/// 书卷卡片：中文名（衬线）+ 英文名 + 章数，白底细描边，安静书卷气
class _BookCard extends StatelessWidget {
  final BookMeta book;
  final ValueChanged<BookMeta> onTap;

  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(book),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.nameZh,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        book.chapterCount > 0
                            ? '${book.chapterCount} 章'
                            : '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.inkSoft,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppTheme.line,
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
}
