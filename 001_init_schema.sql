-- =====================================================================
-- 001_init_schema.sql
-- 全球华人跨平台信仰应用 · 数据层初始化（M1）
-- 依赖: PostgreSQL 15+  /  pgvector 0.5+
-- 执行: psql "$DATABASE_URL" -f 001_init_schema.sql
--
-- 设计约束（与 master-handbook / schema-and-rag 对齐）:
--   1. 英文权威表是唯一可信来源；所有 *_zh 表以外键回源，禁止反向当底本。
--   2. 和合本隔离在 bible_verse_cuv_ref，绝不作为来源 / 参与推理。
--   3. content_chunk.embedding 维度须与 embedding 模型一致（bge-small-zh-v1.5 = 512）。
--   4. 内容发布 / 审核走 content_version + review_queue，可回滚、留痕。
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS vector;     -- pgvector
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- 中英文关键词/trigram 检索辅助

-- =====================================================================
-- 一、圣经书卷元数据
-- =====================================================================
CREATE TABLE bible_book (
    book_id       SMALLINT PRIMARY KEY,
    book_code     TEXT UNIQUE NOT NULL,          -- 'GEN','JHN'
    name_en       TEXT NOT NULL,
    name_zh       TEXT NOT NULL,                 -- 书卷名(事实元数据，非经文翻译)
    testament     TEXT NOT NULL CHECK (testament IN ('OT','NT')),
    chapter_count SMALLINT NOT NULL
);

-- =====================================================================
-- 二、权威来源表（英文，唯一可信来源）
-- =====================================================================
CREATE TABLE bible_verse_kjv (
    verse_id  BIGSERIAL PRIMARY KEY,
    book_id   SMALLINT NOT NULL REFERENCES bible_book(book_id) ON DELETE RESTRICT,
    chapter   SMALLINT NOT NULL,
    verse     SMALLINT NOT NULL,
    ref       TEXT NOT NULL,                     -- 'JHN 3:16'
    kjv_text  TEXT NOT NULL,
    UNIQUE (book_id, chapter, verse)
);
CREATE INDEX idx_kjv_ref ON bible_verse_kjv(ref);

CREATE TABLE egw_work (
    work_id      TEXT PRIMARY KEY,               -- 'SC','GC','DA','MH'
    title_en     TEXT NOT NULL,
    title_zh     TEXT,
    year         SMALLINT,
    tier         SMALLINT NOT NULL CHECK (tier IN (1,2)),  -- 1=生前PD 2=身后汇编(需核实)
    pd_confirmed BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE egw_paragraph (
    paragraph_id   BIGSERIAL PRIMARY KEY,
    work_id        TEXT NOT NULL REFERENCES egw_work(work_id) ON DELETE CASCADE,
    chapter_no     SMALLINT,
    paragraph_no   INTEGER NOT NULL,
    en_text        TEXT NOT NULL,
    UNIQUE (work_id, chapter_no, paragraph_no)
);
CREATE INDEX idx_egw_work ON egw_paragraph(work_id);

CREATE TABLE doctrine_belief (
    belief_id SMALLINT PRIMARY KEY,              -- 1..28
    code      TEXT UNIQUE NOT NULL,              -- 'SCRIPTURE'
    title_en  TEXT NOT NULL,
    title_zh  TEXT,
    en_text   TEXT NOT NULL
);

-- =====================================================================
-- 三、中文产出表（外键回源；禁止反向当底本）
-- =====================================================================
CREATE TABLE bible_verse_zh (
    verse_zh_id   BIGSERIAL PRIMARY KEY,
    verse_id      BIGINT NOT NULL UNIQUE REFERENCES bible_verse_kjv(verse_id) ON DELETE RESTRICT,
    our_zh        TEXT NOT NULL,
    translator    TEXT,
    version_label TEXT NOT NULL DEFAULT 'v0.1-draft',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE egw_paragraph_zh (
    para_zh_id    BIGSERIAL PRIMARY KEY,
    paragraph_id  BIGINT NOT NULL UNIQUE REFERENCES egw_paragraph(paragraph_id) ON DELETE RESTRICT,
    zh_text       TEXT NOT NULL,
    version_label TEXT NOT NULL DEFAULT 'v0.1-draft',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE doctrine_belief_zh (
    belief_zh_id  BIGSERIAL PRIMARY KEY,
    belief_id     SMALLINT NOT NULL UNIQUE REFERENCES doctrine_belief(belief_id) ON DELETE RESTRICT,
    zh_text       TEXT NOT NULL,
    version_label TEXT NOT NULL DEFAULT 'v0.1-draft',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 四、和合本隔离（仅参照，绝不作为来源 / 推理）
-- =====================================================================
CREATE TABLE bible_verse_cuv_ref (
    cuv_id   BIGSERIAL PRIMARY KEY,
    verse_id BIGINT NOT NULL UNIQUE REFERENCES bible_verse_kjv(verse_id) ON DELETE RESTRICT,
    cuv_text TEXT NOT NULL
);

-- =====================================================================
-- 五、对照注释（comparison_note）
-- =====================================================================
CREATE TABLE comparison_note (
    note_id     BIGSERIAL PRIMARY KEY,
    ref         TEXT NOT NULL,                   -- 'JHN 3:16'
    verse_id    BIGINT REFERENCES bible_verse_kjv(verse_id) ON DELETE SET NULL,
    diff_type   TEXT NOT NULL CHECK (diff_type IN ('archaic_kjv','mistranslation','text_tradition','consistent')),
    observation TEXT NOT NULL,
    basis       TEXT NOT NULL,                   -- 必填：原文词形/语法/底本依据
    implication TEXT,
    conclusion  TEXT NOT NULL,
    author      TEXT NOT NULL DEFAULT 'pilot-draft(AI)',
    status      TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','rejected')),
    reviewed_by TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_comparison_ref ON comparison_note(ref);
CREATE INDEX idx_comparison_status ON comparison_note(status);

-- =====================================================================
-- 六、RAG 核心：统一切片 + 向量
-- =====================================================================
CREATE TABLE content_chunk (
    chunk_id    BIGSERIAL PRIMARY KEY,
    source_type TEXT NOT NULL CHECK (source_type IN ('BIBLE','EGW','DOCTRINE')),
    source_id   TEXT NOT NULL,                    -- 'KJV-JHN3:16' / 'EGW-SC-p12' / 'DOC-1'
    ref         TEXT,
    chunk_text  TEXT NOT NULL,
    embedding   VECTOR(512),                      -- 维度须与 embedding 模型一致
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_chunk_source ON content_chunk(source_type, source_id);
CREATE INDEX idx_chunk_trgm   ON content_chunk USING gin (chunk_text gin_trgm_ops);
-- 余弦相似度索引（ivfflat；lists 按数据量调整，建议 sqrt(行数)）
CREATE INDEX idx_chunk_vec ON content_chunk USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- =====================================================================
-- 七、问答溯源与反馈
-- =====================================================================
CREATE TABLE qa_answer (
    answer_id    TEXT PRIMARY KEY,                -- 'qa_xxxx'
    question     TEXT NOT NULL,
    answer_zh    TEXT NOT NULL,
    confidence   REAL,
    needs_human  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE qa_citation (
    citation_id BIGSERIAL PRIMARY KEY,
    answer_id   TEXT NOT NULL REFERENCES qa_answer(answer_id) ON DELETE CASCADE,
    source_type TEXT NOT NULL,
    source_id   TEXT NOT NULL,                    -- 必须能映射到 content_chunk.source_id
    ref         TEXT,
    snippet     TEXT
);
CREATE INDEX idx_qa_citation_answer ON qa_citation(answer_id);

CREATE TABLE qa_feedback (
    feedback_id BIGSERIAL PRIMARY KEY,
    answer_id   TEXT NOT NULL REFERENCES qa_answer(answer_id) ON DELETE CASCADE,
    rating      SMALLINT CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 八、内容版本化 / 审核（专家在环）
-- =====================================================================
CREATE TABLE content_version (
    version_id  BIGSERIAL PRIMARY KEY,
    entity_type TEXT NOT NULL,                    -- 'VERSE_ZH','COMPARISON_NOTE','HEALTH_GUIDANCE'
    entity_id   TEXT NOT NULL,
    payload     JSONB NOT NULL,
    action      TEXT NOT NULL CHECK (action IN ('create','update','approve','reject','rollback')),
    actor       TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_cv_entity ON content_version(entity_type, entity_id);

CREATE TABLE review_queue (
    review_id   BIGSERIAL PRIMARY KEY,
    kind        TEXT NOT NULL CHECK (kind IN ('comparison_note','qa_correction','health_guidance')),
    payload     JSONB NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
    assigned_to TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

-- =====================================================================
-- 九、健康模块 NEWSTART
-- =====================================================================
CREATE TABLE health_topic (
    topic_id SMALLINT PRIMARY KEY,
    code    TEXT UNIQUE NOT NULL,                 -- 'NUT','EXE','WAT','SUN','TEM','AIR','RES','TRU'
    name_zh TEXT NOT NULL,
    summary TEXT
);

CREATE TABLE health_topic_source (
    id         BIGSERIAL PRIMARY KEY,
    topic_id   SMALLINT NOT NULL REFERENCES health_topic(topic_id) ON DELETE CASCADE,
    source_type TEXT NOT NULL CHECK (source_type IN ('BIBLE','EGW','DOCTRINE')),
    source_id  TEXT NOT NULL
);

CREATE TABLE health_guidance (
    guidance_id      BIGSERIAL PRIMARY KEY,
    topic_id         SMALLINT NOT NULL REFERENCES health_topic(topic_id) ON DELETE CASCADE,
    title            TEXT NOT NULL,
    body_zh          TEXT NOT NULL,
    evidence_level   TEXT CHECK (evidence_level IN ('A','B','C')),
    medical_reviewed BOOLEAN NOT NULL DEFAULT FALSE,   -- 闸门：false 不可发布
    disclaimer       TEXT NOT NULL DEFAULT '本内容不替代专业医疗诊断，如有健康问题请咨询医生。',
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_health_guidance_topic ON health_guidance(topic_id);

CREATE TABLE health_metric (
    metric_id   BIGSERIAL PRIMARY KEY,
    topic_code  TEXT NOT NULL REFERENCES health_topic(code) ON DELETE CASCADE,
    name_zh     TEXT NOT NULL,
    unit        TEXT,
    target_value TEXT
);

CREATE TABLE health_log_entry (
    log_id    BIGSERIAL PRIMARY KEY,
    user_id   TEXT NOT NULL,
    topic_code TEXT NOT NULL REFERENCES health_topic(code) ON DELETE CASCADE,
    metric_id BIGINT REFERENCES health_metric(metric_id) ON DELETE SET NULL,
    value     TEXT,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_health_log_user ON health_log_entry(user_id, logged_at);

-- =====================================================================
-- 十、用户域（书签 / 差量同步）
-- =====================================================================
CREATE TABLE user_bookmark (
    bookmark_id BIGSERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    ref         TEXT NOT NULL,
    note        TEXT,
    seq         BIGINT NOT NULL DEFAULT 0,         -- 差量同步游标
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, ref)
);
CREATE INDEX idx_bookmark_user ON user_bookmark(user_id);
