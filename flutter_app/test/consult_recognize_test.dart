// consult_recognize_test.dart
// v57：材料识别器（MaterialRecognizer）纯逻辑测试。
// 覆盖：医院名清洗、诊断清洗与排序、材料类型推测、主诉提取、空文本边界。
import 'package:faith_compare_app/consult_recognizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaterialRecognizer：医院识别', () {
    test('截图场景：三博脑科医院完整名称', () {
      const t = '病理报告\n送检医院：首都医科大学三博脑科医院\n'
          '病理诊断：孤立性纤维性肿瘤';
      final r = MaterialRecognizer.recognize(t);
      expect(r.hospital, '首都医科大学三博脑科医院');
      expect(r.hospitals, contains('首都医科大学三博脑科医院'));
    });

    test('句首动词被剥掉（送至/赴）', () {
      const t = '病人送至北京协和医院就诊，门诊诊断：高血压';
      final r = MaterialRecognizer.recognize(t);
      expect(r.hospital, '北京协和医院');
    });

    test('多个医院按出现顺序收集', () {
      const t = '河南省人民医院 初步诊断：肺炎；后转诊至郑州大学第一附属医院';
      final r = MaterialRecognizer.recognize(t);
      expect(r.hospitals.length, greaterThanOrEqualTo(2));
      expect(r.hospitals.first, '河南省人民医院');
    });

    test('无医院文本不产出医院', () {
      final r = MaterialRecognizer.recognize('今日感觉良好，无特殊不适。');
      expect(r.hospital, '');
    });
  });

  group('MaterialRecognizer：诊断识别', () {
    test('截图场景：诊断名称干净提取', () {
      const t = '病理诊断：孤立性纤维性肿瘤\n免疫组化：STAT6(+)';
      final r = MaterialRecognizer.recognize(t);
      expect(r.diagnosis, '孤立性纤维性肿瘤');
    });

    test('推测性动词被剥掉（考虑/提示）', () {
      final r = MaterialRecognizer.recognize('临床诊断：考虑2型糖尿病');
      expect(r.diagnosis, '2型糖尿病');
    });

    test('「待查」后缀被去掉', () {
      final r = MaterialRecognizer.recognize('初步诊断：头痛待查');
      expect(r.diagnosis, '头痛');
    });

    test('非诊断噪声被剔除（请结合临床/未见异常）', () {
      final r = MaterialRecognizer.recognize('检查结论：请结合临床随访。');
      expect(r.diagnosis, '');
    });

    test('疾病名候选优先于普通描述', () {
      const t = '印象：双肺纹理增多\n临床诊断：肺炎';
      final r = MaterialRecognizer.recognize(t);
      expect(r.diagnosis, '肺炎');
    });
  });

  group('MaterialRecognizer：材料类型与主诉', () {
    test('病理关键词 → 病理报告', () {
      final r = MaterialRecognizer.recognize('免疫组化结果显示 CD34 阳性');
      expect(r.materialType, '病理报告');
    });

    test('CT/影像关键词 → 影像报告', () {
      final r = MaterialRecognizer.recognize('头颅 CT 平扫未见出血');
      expect(r.materialType, '影像报告（CT/彩超等）');
    });

    test('检验关键词 → 检验单', () {
      final r = MaterialRecognizer.recognize('血常规：白细胞 6.2×10^9/L');
      expect(r.materialType, '检验单（血/尿等）');
    });

    test('出院记录 → 住院小结', () {
      final r = MaterialRecognizer.recognize('入院记录：…出院情况：好转');
      expect(r.materialType, '住院小结/出院记录');
    });

    test('主诉提取', () {
      final r = MaterialRecognizer.recognize('主诉：间断头痛 3 天，伴恶心。');
      expect(r.chiefComplaint, '间断头痛 3 天，伴恶心');
    });

    test('filledCount 统计可填项', () {
      final r = MaterialRecognizer.recognize('病理诊断：肺炎\n主诉：咳嗽 5 天');
      expect(r.hasAny, true);
      expect(r.filledCount, greaterThanOrEqualTo(2));
    });
  });

  group('MaterialRecognizer：边界', () {
    test('空文本安全返回', () {
      final r = MaterialRecognizer.recognize('   ');
      expect(r.hasAny, false);
      expect(r.filledCount, 0);
    });

    test('纯英文/乱码不崩', () {
      final r = MaterialRecognizer.recognize('asdfghjkl 123456');
      expect(r.diagnosis, '');
    });
  });
}
