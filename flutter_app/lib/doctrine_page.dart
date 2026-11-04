// doctrine_page.dart
// 核心教义对照（Item 3）：以 KJV 英文原文为权威，聚合相关经文与怀爱伦著作（EGW）
// 的辅助说明，系统呈现复临信仰的标志性教义。
//
// 合规与信任：
//   - 经文一律以 KJV 英文原文为权威依据，自附中文说明仅为辅助理解；
//   - 怀爱伦著作（EGW）的条目为「代表性归纳」，并非逐字引文；引文语境请以原著为准。
//   - 本页为自包含模块，不依赖任何未部署的依赖，可直接并入构建。

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 单条教义经文（KJV 原文 + 书卷定位）
class DoctrineVerse {
  final String ref;
  final String text;

  const DoctrineVerse({required this.ref, required this.text});
}

/// 核心教义条目
class DoctrineItem {
  final String code;
  final String titleZh;
  final String titleEn;
  final String summary;
  final List<DoctrineVerse> verses;
  final String egwNote;

  const DoctrineItem({
    required this.code,
    required this.titleZh,
    required this.titleEn,
    required this.summary,
    required this.verses,
    required this.egwNote,
  });
}

/// 复临信仰标志性教义（SDA Distinctives）。经文以 KJV 为权威，EGW 条目为辅助归纳。
const List<DoctrineItem> kDoctrines = [
  DoctrineItem(
    code: 'sabbath',
    titleZh: '安息日',
    titleEn: 'The Sabbath',
    summary: '第七日为创造主所设立的圣日，记念创造与救赎。',
    verses: [
      DoctrineVerse(
        ref: 'EXO 20:8,11',
        text:
            'Remember the sabbath day, to keep it holy... For in six days the LORD made heaven and earth... and rested the seventh day: wherefore the LORD blessed the sabbath day, and hallowed it.',
      ),
      DoctrineVerse(
        ref: 'MRK 2:27',
        text: 'And he said unto them, The sabbath was made for man, and not man for the sabbath:',
      ),
    ],
    egwNote:
        '怀爱伦在《先祖与先知》《历代愿望》中强调，安息日是上帝赐福的记号，基督乃「主日之主」，并在安息日休憩为人设立榜样。',
  ),
  DoctrineItem(
    code: 'state_of_dead',
    titleZh: '死人状态',
    titleEn: 'State of the Dead',
    summary: '人死后意识沉睡，直候复活；灵魂并非不灭。',
    verses: [
      DoctrineVerse(
        ref: 'ECC 9:5',
        text:
            'For the living know that they shall die: but the dead know not any thing, neither have they any more a reward; for the memory of them is forgotten.',
      ),
      DoctrineVerse(
        ref: 'JHN 11:11,14',
        text:
            'Our friend Lazarus sleepeth; but I go, that I may awake him out of sleep... Then said Jesus unto them plainly, Lazarus is dead.',
      ),
    ],
    egwNote:
        '怀爱伦明确指出「死人毫无所知」，死亡如沉睡，复活是睡者被唤醒；灵魂不灭说与圣经相悖。',
  ),
  DoctrineItem(
    code: 'second_coming',
    titleZh: '基督复临',
    titleEn: 'Second Coming',
    summary: '基督将 visibly（肉眼可见）再来，接赎民归家。',
    verses: [
      DoctrineVerse(
        ref: 'JHN 14:2-3',
        text:
            'In my Father\'s house are many mansions... I go to prepare a place for you. And if I go and prepare a place for you, I will come again, and receive you unto myself.',
      ),
      DoctrineVerse(
        ref: 'ACT 1:11',
        text:
            'this same Jesus, which is taken up from you into heaven, shall so come in like manner as ye have seen him go into heaven.',
      ),
    ],
    egwNote:
        '怀爱伦在《善恶之争》中描述复临的荣耀景象与复临前的征兆，呼召信徒警醒预备。',
  ),
  DoctrineItem(
    code: 'investigative_judgment',
    titleZh: '查案审判',
    titleEn: 'Investigative Judgment',
    summary: '但以理二千三百日预言指向天上的审判与洁净圣所。',
    verses: [
      DoctrineVerse(
        ref: 'DAN 8:14',
        text:
            'Unto two thousand and three hundred days; then shall the sanctuary be cleansed.',
      ),
      DoctrineVerse(
        ref: 'DAN 7:9-10',
        text:
            'I beheld till the thrones were cast down... the judgment was set, and the books were opened.',
      ),
    ],
    egwNote:
        '怀爱伦在《善恶之争》详述 1844 年开启的查案审判的时机、性质与对余民的意义。',
  ),
  DoctrineItem(
    code: 'baptism',
    titleZh: '洗礼',
    titleEn: 'Baptism',
    summary: '藉洗礼与基督同死、同复活，归入祂名下。',
    verses: [
      DoctrineVerse(
        ref: 'ROM 6:4',
        text:
            'Therefore we are buried with him by baptism into death: that like as Christ was raised up from the dead... even so we also should walk in newness of life.',
      ),
      DoctrineVerse(
        ref: 'MAT 28:19',
        text:
            'Go ye therefore, and teach all nations, baptizing them in the name of the Father, and of the Son, and of the Holy Ghost:',
      ),
    ],
    egwNote: '怀爱伦论洗礼为信心的公开见证，表明与基督同死同复活的决志。',
  ),
  DoctrineItem(
    code: 'tithe',
    titleZh: '十一奉献',
    titleEn: 'Tithe',
    summary: '以十一归主，信赖祂的供应与信实。',
    verses: [
      DoctrineVerse(
        ref: 'MAL 3:10',
        text:
            'Bring ye all the tithes into the storehouse... and prove me now herewith, saith the LORD of hosts, if I will not open you the windows of heaven, and pour you out a blessing.',
      ),
      DoctrineVerse(
        ref: '2CO 9:7',
        text: 'Every man according as he purposeth in his heart, so let him give; not grudgingly, or of necessity: for God loveth a cheerful giver.',
      ),
    ],
    egwNote:
        '怀爱伦强调忠心十一为信徒的本分与蒙福之源，亦用于推进福音圣工。',
  ),
  DoctrineItem(
    code: 'spirit_of_prophesy',
    titleZh: '预言之灵',
    titleEn: 'Spirit of Prophecy',
    summary: '末后上帝赐下预言恩赐，引导并印证余民。',
    verses: [
      DoctrineVerse(
        ref: 'REV 19:10',
        text: '...for the testimony of Jesus is the spirit of prophecy.',
      ),
      DoctrineVerse(
        ref: 'JOE 2:28',
        text: 'And it shall come to pass afterward, that I will pour out my spirit upon all flesh...',
      ),
    ],
    egwNote:
        '怀爱伦视其蒙召与著作（EGW）为「预言之灵」恩赐的印证，作为圣经之外的辅助引导，权威层级低于圣经。',
  ),
  DoctrineItem(
    code: 'christian_temperance',
    titleZh: '健康改良',
    titleEn: 'Christian Temperance',
    summary: '身体是圣灵的殿，当以节制与清洁待之。',
    verses: [
      DoctrineVerse(
        ref: '1CO 6:19-20',
        text:
            'Know ye not that your body is the temple of the Holy Ghost... ye are not your own? For ye are bought with a price: therefore glorify God in your body.',
      ),
      DoctrineVerse(
        ref: '1CO 10:31',
        text:
            'Whether therefore ye eat, or drink, or whatsoever ye do, do all to the glory of God.',
      ),
    ],
    egwNote:
        '怀爱伦在《服务真诠》中系统阐发基督徒节制与饮食改良，身体是上帝托管之殿。',
  ),
];

/// 教义详情页：经文依据（KJV 权威）+ 怀著视角（辅助归纳）。
class DoctrinePage extends StatelessWidget {
  final DoctrineItem doctrine;

  const DoctrinePage({super.key, required this.doctrine});

  @override
  Widget build(BuildContext context) {
    final d = doctrine;
    final scale = AppTheme.readingScale(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${d.titleZh} · 教义对照'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 权威与信任声明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.gold),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '经文以 KJV 英文原文为权威依据；怀爱伦著作（EGW）的说明为辅助归纳，并非逐字引文，引文语境请以原著为准。',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.inkSoft, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              d.summary,
              style: TextStyle(
                fontSize: 15 * scale,
                height: 1.6,
                color: AppTheme.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            // 经文依据（KJV）
            _SectionHeader('经文依据 · KJV（权威）', AppTheme.scriptureBlue),
            const SizedBox(height: 8),
            for (final v in d.verses) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.scriptureBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        v.ref,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.scriptureBlue,
                        ),
                      ),
                    ),
                    Text(
                      v.text,
                      style: AppTheme.scriptureEn(size: 14 * scale, height: 1.7),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            // 怀著视角（辅助）
            _SectionHeader('怀著视角 · EGW（辅助）', AppTheme.zhTeal),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.zhTeal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.line),
              ),
              child: Text(
                d.egwNote,
                style: AppTheme.scripture(size: 14 * scale, height: 1.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _SectionHeader(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
        ),
      ],
    );
  }
}

// (trigger rebuild: retrigger CI after transient data-injection failure)
