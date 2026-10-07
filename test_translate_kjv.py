#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""translate_kjv.py 的离线单元测试（mock 掉网络，验证解析/续译/防复制逻辑）。"""
import json
import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import translate_kjv as T


class FakeResp:
    def __init__(self, payload):
        self._b = json.dumps(payload).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def read(self):
        return self._b


def _fake_data():
    return {
        "verse": [
            {"book_id": 1, "chapter": 1, "verse": 1, "ref": "GEN 1:1",
             "kjv_text": "In the beginning God created the heaven and the earth.",
             "cuv_ref_text": "起初，神创造天地。"},
            {"book_id": 1, "chapter": 1, "verse": 2, "ref": "GEN 1:2",
             "kjv_text": "And the earth was without form.",
             "cuv_ref_text": "地是空虚混沌。"},
            {"book_id": 2, "chapter": 3, "verse": 16, "ref": "JHN 3:16",
             "kjv_text": "For God so loved the world.",
             "cuv_ref_text": "神爱世人。"},
        ]
    }


class TestTranslate(unittest.TestCase):
    def setUp(self):
        # 重定向产物路径到临时文件
        self.tmp = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_t_test")
        os.makedirs(self.tmp, exist_ok=True)
        T.DATA_FILE = os.path.join(self.tmp, "app_data.json")
        T.OUR_ZH_FILE = os.path.join(self.tmp, "our_zh.json")
        T.FAIL_FILE = os.path.join(self.tmp, "fail.json")
        with open(T.DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(_fake_data(), f, ensure_ascii=False)

    def tearDown(self):
        for fn in (T.DATA_FILE, T.OUR_ZH_FILE, T.FAIL_FILE):
            if os.path.exists(fn):
                os.remove(fn)
        if os.path.exists(self.tmp):
            os.rmdir(self.tmp)

    def _mock_llm(self, mapping):
        def fake_urlopen(req, timeout=90):
            body = json.loads(req.data.decode("utf-8"))
            user = body["messages"][1]["content"]
            verses = []
            for line in user.splitlines():
                if "\t" in line:
                    ref = line.split("\t")[0]
                    verses.append({"ref": ref, "zh": mapping.get(ref, "译")})
            content = json.dumps({"verses": verses})
            return FakeResp({"choices": [{"message": {"content": content}}]})

        return fake_urlopen

    def test_call_llm_parses_refs(self):
        s = T.Settings()
        s.API_KEY = "x"
        with mock.patch("urllib.request.urlopen", self._mock_llm({"GEN 1:1": "起初神创造天地。"})):
            out = T.call_llm(_fake_data()["verse"][:1], s)
        self.assertEqual(out, {"GEN 1:1": "起初神创造天地。"})

    def test_resume_skips_translated(self):
        # 预置整章(创1:1,1:2)已译，确认该章被跳过，只剩 JHN 3:16 一章待译
        with open(T.OUR_ZH_FILE, "w", encoding="utf-8") as f:
            json.dump({"GEN 1:1": "已有译文", "GEN 1:2": "已有译文"}, f, ensure_ascii=False)
        s = T.Settings()
        s.API_KEY = "x"
        calls = {"n": 0}

        def fake_urlopen(req, timeout=90):
            calls["n"] += 1
            return FakeResp({"verses": []})

        with mock.patch("urllib.request.urlopen", fake_urlopen):
            # 直接调用 main 的翻译循环等价逻辑：group -> 过滤已译 -> call
            data = T.load_data()
            chapters = T.group_by_chapter(data)
            our_zh = T.load_our_zh()
            pending = [(b, c, vs) for b, c, vs in chapters
                       if not all(v["ref"] in our_zh for v in vs)]
            # GEN 1:1 已译 -> 该章应被跳过；只剩 JHN 3:16 一章待译
            self.assertEqual(len(pending), 1)
            self.assertEqual(pending[0][2][0]["ref"], "JHN 3:16")

    def test_apply_drops_cuv_copy(self):
        # our_zh 故意与和合本逐字相同 -> apply 应丢弃；不同 -> 保留
        with open(T.OUR_ZH_FILE, "w", encoding="utf-8") as f:
            json.dump({
                "GEN 1:1": "起初，神创造天地。",          # == cuv -> 丢弃
                "JHN 3:16": "神如此爱世人。",             # != cuv -> 保留
            }, f, ensure_ascii=False)
        filled, dropped = T.apply_to_data(T.load_our_zh())
        self.assertEqual(filled, 1)
        self.assertEqual(dropped, 1)
        data = T.load_data()
        by_ref = {v["ref"]: v for v in data["verse"]}
        self.assertNotIn("our_zh", by_ref["GEN 1:1"] or {})
        self.assertEqual(by_ref["JHN 3:16"].get("our_zh"), "神如此爱世人。")


if __name__ == "__main__":
    unittest.main(verbosity=2)
