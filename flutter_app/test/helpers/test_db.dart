// test/helpers/test_db.dart
// 测试用：提供与 build_offline_db.py 同构的离线数据 JSON 字符串，
// 供 widget test 通过 OfflineDbHelper.load(jsonString) 注入，
// 不依赖真实 assets/web/app_data.json（资产在测试中不好加载）。
//
// 数据层已改为 web / 桌面 / 手机通用的 JSON 资源（见 offline_db_helper.dart、
// web_data_core.dart），因此测试也改为注入 JSON，而非复制 SQLite 文件。

/// 测试用离线数据（含 book / verse / doctrine，及空的健康表）。
/// 字段名与列名完全对齐，键名即 SQLite 表名。
const String kTestDataJson = '''
{
  "book": [
    {"book_id":1,"book_code":"GEN","name_en":"Genesis","name_zh":"创世记","testament":"OT","chapter_count":50},
    {"book_id":2,"book_code":"JHN","name_en":"John","name_zh":"约翰福音","testament":"NT","chapter_count":21}
  ],
  "doctrine": [
    {"belief_id":1,"code":"D01","title_en":"Holy Scriptures","title_zh":"圣经","en_text":"The Holy Scriptures are the inspired Word of God.","zh_text":"圣经是神所默示的话语。"}
  ],
  "verse": [
    {"verse_id":1,"book_id":1,"chapter":1,"verse":1,"ref":"GEN 1:1","kjv_text":"In the beginning God created the heaven and the earth.","our_zh":"起初，神创造天地。","cuv_ref_text":"起初神创造天地。"},
    {"verse_id":2,"book_id":2,"chapter":3,"verse":16,"ref":"JHN 3:16","kjv_text":"For God so loved the world, that he gave his only begotten Son.","our_zh":"神爱世人，甚至将他的独生子赐给他们。","cuv_ref_text":"神爱世人，甚至将他的独生子赐给他们。"}
  ],
  "health_topic": [],
  "health_topic_source": [],
  "health_metric": [],
  "health_guidance": []
}
''';

/// 返回测试用离线数据 JSON 字符串（供 OfflineDbHelper.load 注入）。
String buildTestDataJson() => kTestDataJson;
