#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
embed_util.py — 共享 embedding / 切片工具（M1 数据层）
=====================================================================
供 ingest_kjv.py / ingest_egw.py 复用，保证向量维度与写入方式完全一致。
- 维度必须与 001_init_schema.sql 中 content_chunk.embedding(VECTOR(512)) 一致
- 写入统一用 pgvector 文本字面量 + ::vector cast（见各 ingest 脚本）
"""
import os
from typing import List

EMBED_MODEL = os.getenv("EMBEDDING_MODEL", "BAAI/bge-small-zh-v1.5")
EMBED_DIM = 512  # 须与 001_init_schema.sql content_chunk.embedding(VECTOR(512)) 一致

_SENT_SPLIT = ".!?;:"
_MODEL = None


def chunk_text(text: str, max_len: int = 480) -> List[str]:
    """按句子边界切分长文本，避免跨句割裂；短文本整段返回。"""
    text = (text or "").strip()
    if not text:
        return []
    if len(text) <= max_len:
        return [text]
    parts, buf = [], ""
    for ch in text:
        buf += ch
        if ch in _SENT_SPLIT and len(buf) >= 120:
            parts.append(buf.strip())
            buf = ""
    if buf.strip():
        parts.append(buf.strip())
    out: List[str] = []
    for p in parts:
        if len(p) <= max_len:
            out.append(p)
        else:
            for i in range(0, len(p), max_len):
                out.append(p[i:i + max_len])
    return out or [text]


def load_model():
    global _MODEL
    if _MODEL is None:
        from sentence_transformers import SentenceTransformer
        _MODEL = SentenceTransformer(EMBED_MODEL)
    return _MODEL


def embed_texts(texts: List[str]) -> List[List[float]]:
    if not texts:
        return []
    model = load_model()
    vecs = model.encode(texts, normalize_embeddings=True, show_progress_bar=True)
    return [list(map(float, v)) for v in vecs]


def pgvector_literal(vec: List[float]) -> str:
    """转为 pgvector 接受的 '[x,y,...]' 文本字面量（保留 6 位精度）。"""
    return "[" + ",".join(str(round(x, 6)) for x in vec) + "]"
