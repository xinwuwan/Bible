// egw_works.dart
// 怀爱伦著作（怀著）中英对照目录：供「对照模块」首页「怀著」Tab 与阅读器复用。
//
// 数据来源：egwwritings.org 官方 API（英文原著 book id 与中文译本 book id 成对）。
// 仅已抓取并完成中英段落对齐的著作标记为 ready=true。
//
// 注意：egwwritings 将每个中文译本作为独立书籍存储（自有页码、无任何 EN<->ZH
// 互链、不支持 lang 切换），无法按段落/页码精确对齐；以「章号」为共享键对齐
// （忠实译本保留 Chapter N ↔ 第N章 的章节编号），由 _egw_align_multi.py 生成。

class EgwWork {
  final String code; // egwwritings 书号（如 SC）
  final String nameEn;
  final String nameZh;
  final int enBookId; // 英文原著 book id
  final int zhBookId; // 中文译本 book id
  final bool ready; // 是否已收录中英对照数据
  final String? asset; // 已对齐的 assets/web/*.json 路径（ready 时必填）
  final String? blurb; // 一句话简介（用于卡片副标题）

  const EgwWork({
    required this.code,
    required this.nameEn,
    required this.nameZh,
    required this.enBookId,
    required this.zhBookId,
    this.ready = false,
    this.asset,
    this.blurb,
  });
}

/// 怀著目录（ready=true 的著作需配套 assets/web 资产）。
const List<EgwWork> kEgwWorks = [
  EgwWork(
    code: 'SC',
    nameEn: 'Steps to Christ',
    nameZh: '喜乐的泉源',
    enBookId: 108,
    zhBookId: 14538,
    ready: true,
    asset: 'assets/web/egw_sc_align.json',
    blurb: '灵修经典 · 13 章',
  ),
  EgwWork(
    code: 'DA',
    nameEn: 'The Desire of Ages',
    nameZh: '历代愿望',
    enBookId: 130,
    zhBookId: 14492,
    ready: true,
    asset: 'assets/web/egw_da_align.json',
    blurb: '基督生平叙事',
  ),
  EgwWork(
    code: 'GC',
    nameEn: 'The Great Controversy',
    nameZh: '善恶之争',
    enBookId: 132,
    zhBookId: 14504,
    ready: true,
    asset: 'assets/web/egw_gc_align.json',
    blurb: '救赎史论述',
  ),
  EgwWork(
    code: 'MH',
    nameEn: 'The Ministry of Healing',
    nameZh: '服务真诠',
    enBookId: 135,
    zhBookId: 14468,
    ready: true,
    asset: 'assets/web/egw_mh_align.json',
    blurb: '基督化医病与服务',
  ),
  EgwWork(
    code: 'PP',
    nameEn: 'Patriarchs and Prophets',
    nameZh: '先祖与先知',
    enBookId: 84,
    zhBookId: 14604,
    ready: true,
    asset: 'assets/web/egw_pp_align.json',
    blurb: '从创世到大卫',
  ),
  EgwWork(
    code: 'PK',
    nameEn: 'Prophets and Kings',
    nameZh: '先知与君王',
    enBookId: 88,
    zhBookId: 14605,
    ready: true,
    asset: 'assets/web/egw_pk_align.json',
    blurb: '王国与先知时代',
  ),
  EgwWork(
    code: 'AA',
    nameEn: 'The Acts of the Apostles',
    nameZh: '使徒行述',
    enBookId: 127,
    zhBookId: 14510,
    ready: true,
    asset: 'assets/web/egw_aa_align.json',
    blurb: '早期教会史',
  ),
  EgwWork(
    code: 'Ed',
    nameEn: 'Education',
    nameZh: '教育论',
    enBookId: 29,
    zhBookId: 14488,
    ready: true,
    asset: 'assets/web/egw_ed_align.json',
    blurb: '真教育原理',
  ),
  EgwWork(
    code: 'COL',
    nameEn: "Christ's Object Lessons",
    nameZh: '基督比喻实训',
    enBookId: 15,
    zhBookId: 14481,
    ready: true,
    asset: 'assets/web/egw_col_align.json',
    blurb: '天国的比喻',
  ),
  EgwWork(
    code: 'MYP',
    nameEn: 'Messages to Young People',
    nameZh: '告青年书',
    enBookId: 76,
    zhBookId: 14475,
    // 暂未上线：英文原文(76)已可经官方 API 取全（TOC 遍历法），但其中文版(14475)为
    // 「主题重编/选编」而非平行译本——章节边界与段落顺序均不对应，自动化对齐会产出错配
    // 对照，违反内容准确铁律。待换平行译本源或人工逐段对照后再上线。
    blurb: '青年信仰劝勉',
  ),
];
