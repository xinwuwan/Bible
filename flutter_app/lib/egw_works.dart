// egw_works.dart
// 怀爱伦著作（怀著）中英对照目录：供「对照模块」首页「怀著」Tab 与阅读器复用。
//
// 数据来源：egwwritings.org 官方 API（英文原著 book id 与中文译本 book id 成对）。
// 仅已抓取并完成中英段落对齐的著作标记为 ready=true；其余为「数据准备中」，
// 后续把对齐 JSON 放入 assets/web/ 并在下方补 asset 路径即可上线，无需改阅读器逻辑。

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

/// 怀著目录（按需扩充；ready=true 的著作需配套 assets/web 资产）。
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
    zhBookId: 14535,
    blurb: '基督生平叙事',
  ),
  EgwWork(
    code: 'GC',
    nameEn: 'The Great Controversy',
    nameZh: '善恶之争',
    enBookId: 121,
    zhBookId: 14526,
    blurb: '救赎史论述',
  ),
  EgwWork(
    code: 'MH',
    nameEn: 'The Ministry of Healing',
    nameZh: '服务真诠',
    enBookId: 143,
    zhBookId: 14547,
    blurb: '基督化医病与服务',
  ),
  EgwWork(
    code: 'PP',
    nameEn: 'Patriarchs and Prophets',
    nameZh: '先祖与先知',
    enBookId: 161,
    zhBookId: 14558,
    blurb: '从创世到大卫',
  ),
  EgwWork(
    code: 'PK',
    nameEn: 'Prophets and Kings',
    nameZh: '先知与君王',
    enBookId: 164,
    zhBookId: 14561,
    blurb: '王国与先知时代',
  ),
  EgwWork(
    code: 'AA',
    nameEn: 'The Acts of the Apostles',
    nameZh: '使徒行述',
    enBookId: 119,
    zhBookId: 14524,
    blurb: '早期教会史',
  ),
  EgwWork(
    code: 'Ed',
    nameEn: 'Education',
    nameZh: '教育论',
    enBookId: 110,
    zhBookId: 14540,
    blurb: '真教育原理',
  ),
  EgwWork(
    code: 'COL',
    nameEn: "Christ's Object Lessons",
    nameZh: '比喻宝训',
    enBookId: 414,
    zhBookId: 14544,
    blurb: '天国的比喻',
  ),
  EgwWork(
    code: 'MYP',
    nameEn: 'Messages to Young People',
    nameZh: '给青年人的信息',
    enBookId: 149,
    zhBookId: 14552,
    blurb: '青年信仰劝勉',
  ),
];
