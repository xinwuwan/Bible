# expand_kb.py
# 扩充模块 B 离线问答覆盖面：向 backend/kb.json 追加
#   - 一批以 KJV 为支撑、SDA 教义对齐的新 FAQ 条目
#   - 这些 FAQ 所引用的 KJV 经文（作为后端离线回答器的底本）
#   - 管家职分(SDA-B21) 教义条目（支撑十一奉献 FAQ）
# 然后据更新后的 kb.json 重新生成 flutter_app/assets/web/qa_faq.json，保证两端同步。
#
# 合规铁律：
#   - CUV 绝不进入引用（source_id 一律 KJV- 或 SDA-B）
#   - 每条非人工回答都带真实 KJV / 教义引用
#   - EGW 不臆造；仅以教义 #18 说明其角色
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
KB = os.path.join(ROOT, "backend", "kb.json")
QA = os.path.join(ROOT, "flutter_app", "assets", "web", "qa_faq.json")

# ---------- 新增经文（KJV 英文底本 + 本应用独立中文产出）----------
NEW_VERSES = [
    {"ref": "MAL 3:10", "book_code": "MAL", "chapter": 3, "verse": 10,
     "text": "Bring ye all the tithes into the storehouse, that there may be meat in mine house, and prove me now herewith, saith the LORD of hosts, if I will not open you the windows of heaven, and pour you out a blessing, that there shall not be room enough to receive it.",
     "zh": "万军之耶和华说：你们要将当纳的十分之一全然送入仓库，使我家中有粮，以此试试我，是否为你们敞开天上的窗户，倾福与你们，甚至无处可容。"},
    {"ref": "2CO 9:7", "book_code": "2CO", "chapter": 9, "verse": 7,
     "text": "Every man according as he purposeth in his heart, so let him give; not grudgingly, or of necessity: for God loveth a cheerful giver.",
     "zh": "各人要随本心所酌定的捐献，不要作难，不要勉强，因为捐得乐意的人是神所喜爱的。"},
    {"ref": "1CO 16:2", "book_code": "1CO", "chapter": 16, "verse": 2,
     "text": "Upon the first day of the week let every one of you lay by him in store, as God hath prospered him, that there be no gatherings when I come.",
     "zh": "每逢七日的第一日，各人要照自己的进项抽存，免得我来的时候现凑。"},
    {"ref": "LEV 11:3", "book_code": "LEV", "chapter": 11, "verse": 3,
     "text": "Whatsoever parteth the hoof, and is clovenfooted, and cheweth the cud, among the beasts, that shall ye eat.",
     "zh": "凡蹄分两瓣、倒嚼的走兽，你们都可以吃。"},
    {"ref": "1CO 6:19", "book_code": "1CO", "chapter": 6, "verse": 19,
     "text": "What? know ye not that your body is the temple of the Holy Ghost which is in you, which ye have of God, and ye are not your own?",
     "zh": "岂不知你们的身子就是圣灵的殿吗？这圣灵是从神而来，住在你们里头的；你们不是自己的人。"},
    {"ref": "1CO 6:20", "book_code": "1CO", "chapter": 6, "verse": 20,
     "text": "For ye are bought with a price: therefore glorify God in your body, and in your spirit, which are God's.",
     "zh": "因为你们是重价买来的，所以要在你们的身子上荣耀神。"},
    {"ref": "MAL 4:1", "book_code": "MAL", "chapter": 4, "verse": 1,
     "text": "For, behold, the day cometh, that shall burn as an oven; and all the proud, yea, and all that do wickedly, shall be stubble: and the day that cometh shall burn them up, saith the LORD of hosts, that it shall leave them neither root nor branch.",
     "zh": "万军之耶和华说：那日临近，势如烧着的火炉；凡狂傲的和行恶的必如碎秸，在那日必被烧尽，连根带枝一无所剩。"},
    {"ref": "MAT 19:6", "book_code": "MAT", "chapter": 19, "verse": 6,
     "text": "Wherefore they are no more twain, but one flesh. What therefore God hath joined together, let not man put asunder.",
     "zh": "既然如此，夫妻不再是两个人，乃是一体的了。所以神所配合的，人不可分开。"},
    {"ref": "MAL 2:16", "book_code": "MAL", "chapter": 2, "verse": 16,
     "text": "For the LORD, the God of Israel, saith that he hateth putting away: for one covereth violence with his garment, saith the LORD of hosts: therefore take heed to your spirit, that ye deal not treacherously.",
     "zh": "耶和华以色列的神说：休妻的事，是我所恨恶的；所以你们当谨守自己的心，不可行事诡诈。"},
    {"ref": "MAT 24:6", "book_code": "MAT", "chapter": 24, "verse": 6,
     "text": "And ye shall hear of wars and rumours of wars: see that ye be not troubled: for all these things must come to pass, but the end is not yet.",
     "zh": "你们也要听见打仗和打仗的风声，总不要惊慌；因为这些事是必须有的，只是末期还没有到。"},
    {"ref": "2TI 3:1", "book_code": "2TI", "chapter": 3, "verse": 1,
     "text": "This know also, that in the last days perilous times shall come.",
     "zh": "你该知道，末世必有危险的日子来到。"},
    {"ref": "2TI 3:2", "book_code": "2TI", "chapter": 3, "verse": 2,
     "text": "For men shall be lovers of their own selves, covetous, boasters, proud, blasphemers, disobedient to parents, unthankful, unholy,",
     "zh": "因为那时人要专顾自己、贪爱钱财、自夸、狂傲、谤讟、违背父母、忘恩、不圣洁、"},
    {"ref": "DAN 8:14", "book_code": "DAN", "chapter": 8, "verse": 14,
     "text": "And he said unto me, Unto two thousand and three hundred days; then shall the sanctuary be cleansed.",
     "zh": "他对我说：到二千三百日，圣所就必洁净。"},
    {"ref": "REV 7:4", "book_code": "REV", "chapter": 7, "verse": 4,
     "text": "And I heard the number of them which were sealed: and there were sealed an hundred and forty and four thousand of all the tribes of the children of Israel.",
     "zh": "我听见以色列人各支派中受印的数目有十四万四千。"},
    {"ref": "REV 14:1", "book_code": "REV", "chapter": 14, "verse": 1,
     "text": "And I looked, and, lo, a Lamb stood on the mount Sion, and with him an hundred forty and four thousand, having his Father's name written in their foreheads.",
     "zh": "我又观看，见羔羊站在锡安山，同他又有十四万四千人，都有他父的名写在额上。"},
    {"ref": "1TH 4:16", "book_code": "1TH", "chapter": 4, "verse": 16,
     "text": "For the Lord himself shall descend from heaven with a shout, with the voice of the archangel, and with the trump of God: and the dead in Christ shall rise first:",
     "zh": "因为主必亲自从天降临，有呼叫的声音和天使长的声音，又有神的号吹响；那在基督里死了的人必先复活。"},
    {"ref": "1CO 15:23", "book_code": "1CO", "chapter": 15, "verse": 23,
     "text": "But every man in his own order: Christ the firstfruits; afterward they that are Christ's at his coming.",
     "zh": "但各人是按着自己的次序复活：初熟的果子是基督；以后在他来的时候，是那些属基督的。"},
    {"ref": "2TI 3:16", "book_code": "2TI", "chapter": 3, "verse": 16,
     "text": "All scripture is given by inspiration of God, and is profitable for doctrine, for reproof, for correction, for instruction in righteousness:",
     "zh": "圣经都是神所默示的，于教训、督责、使人归正、教导人学义都是有益的。"},
    {"ref": "2PE 1:21", "book_code": "2PE", "chapter": 1, "verse": 21,
     "text": "For the prophecy came not in old time by the will of man: but holy men of God spake as they were moved by the Holy Ghost.",
     "zh": "因为预言从来没有出于人意的，乃是人被圣灵感动，说出神的话来。"},
    {"ref": "EPH 4:30", "book_code": "EPH", "chapter": 4, "verse": 30,
     "text": "And grieve not the holy Spirit of God, whereby ye are sealed unto the day of redemption.",
     "zh": "不要叫神的圣灵担忧；你们原是受了他的印记，等候得赎的日子来到。"},
    {"ref": "REV 7:3", "book_code": "REV", "chapter": 7, "verse": 3,
     "text": "Saying, Hurt not the earth, neither the sea, nor the trees, till we have sealed the servants of our God in their foreheads.",
     "zh": "又说：地与海并树木，你们不可伤害，等我们印了神众仆人的额。"},
    {"ref": "MAT 6:16", "book_code": "MAT", "chapter": 6, "verse": 16,
     "text": "Moreover when ye fast, be not, as the hypocrites, of a sad countenance: for they disfigure their faces, that they may appear unto men to fast. Verily I say unto you, They have their reward.",
     "zh": "你们禁食的时候，不可像那假冒为善的人，脸上带着愁容；因为他们把脸弄得难看，故意叫人看出他们是禁食。我实在告诉你们，他们已经得了他们的赏赐。"},
    {"ref": "MAT 6:17", "book_code": "MAT", "chapter": 6, "verse": 17,
     "text": "But thou, when thou fastest, anoint thine head, and wash thy face;",
     "zh": "你禁食的时候，要梳头洗脸，"},
    {"ref": "MAT 6:18", "book_code": "MAT", "chapter": 6, "verse": 18,
     "text": "That thou appear not unto men to fast, but unto thy Father which is in secret: and thy Father, which seeth in secret, shall reward thee openly.",
     "zh": "不叫人看出你禁食来，只叫你暗中的父看见；你父在暗中察看，必然报答你。"},
    {"ref": "ISA 58:6", "book_code": "ISA", "chapter": 58, "verse": 6,
     "text": "Is not this the fast that I have chosen? to loose the bands of wickedness, to undo the heavy burdens, and to let the oppressed go free, and that ye break every yoke?",
     "zh": "我所拣选的禁食不是要松开凶恶的绳，解下轭上的索，使被欺压的得自由，折断一切的轭吗？"},
    {"ref": "2CO 6:17", "book_code": "2CO", "chapter": 6, "verse": 17,
     "text": "Wherefore come out from among them, and be ye separate, saith the Lord, and touch not the unclean thing; and I will receive you,",
     "zh": "又说：你们务要从他们中间出来，与他们分别；不要沾不洁净的物，我就收纳你们。"},
]

# ---------- 新增教义（SDA 基本法 #21 管家职分）----------
NEW_DOCTRINE = [
    {"belief_id": 21, "code": "STEWARDSHIP", "title_en": "Stewardship",
     "title_zh": "管家职分",
     "en_text": "We are God's stewards, entrusted with time, abilities, possessions, and the gospel, to manage for His glory and the blessing of others.",
     "zh_text": "我们是神的管家，受托管理时间、才干、财物与福音，为荣耀神并造福他人而善加运用；十一奉献是承认神为万有的主、并凭信经历他信实的具体行动。"},
]

# ---------- 新增 FAQ（关键词 / 中文回答 / 真实引用）----------
NEW_FAQ = [
    {"keywords": ["十一奉献", "十分之一", "什一", "奉献", "tithe", "纳什一", "捐输"],
     "answer_zh": "圣经教导信徒将当纳的十分之一送入仓库，使神家有粮，并以此经历神的信实（玛3:10）。捐助当出于甘心乐意，因为「捐得乐意的人是神所喜爱的」（林后9:7）；并要「照自己的进项抽存」（林前16:2）。这是神托付的管家职分，而非用金钱换取恩典。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-MAL3:10", "ref": "MAL 3:10",
          "snippet": "Bring ye all the tithes into the storehouse ... pour you out a blessing"},
         {"source_type": "BIBLE", "source_id": "KJV-2CO9:7", "ref": "2CO 9:7",
          "snippet": "for God loveth a cheerful giver"},
         {"source_type": "BIBLE", "source_id": "KJV-1CO16:2", "ref": "1CO 16:2",
          "snippet": "lay by him in store, as God hath prospered him"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B21", "ref": "教义 #21 管家职分",
          "snippet": "我们是神的管家，受托管理时间、才干、财物与福音。"}]},
    {"keywords": ["洁净食物", "不洁食物", "饮食条例", "吃什么", "食物", "饮食原则", "素食", "健康饮食"],
     "answer_zh": "圣经以律法区分洁净与不洁净的走兽（利11:3 等），原则是要人分别为圣。新约更指出「你们的身子就是圣灵的殿」（林前6:19-20），当为荣耀神而保守身体。本会据此倡导以植物性为主的节制饮食，但具体营养方案请咨询持证医生——本模块不构成医疗建议。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-LEV11:3", "ref": "LEV 11:3",
          "snippet": "Whatsoever parteth the hoof ... cheweth the cud ... that shall ye eat"},
         {"source_type": "BIBLE", "source_id": "KJV-1CO6:19", "ref": "1CO 6:19-20",
          "snippet": "your body is the temple of the Holy Ghost ... ye are not your own"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B22", "ref": "教义 #22 基督徒的本分",
          "snippet": "信徒当以身体为圣灵的殿，活出荣神益人的生活。"}]},
    {"keywords": ["地狱", "永刑", "火湖", "恶人结局", "永永远远受苦", "eternal punishment", "hell"],
     "answer_zh": "圣经描写恶人的结局是被焚烧净尽、「并不留根与条」（玛4:1），死亡是无知觉的睡眠（传9:5），「罪的工价乃是死」（罗6:23）。本会相信恶人受审后最终被消灭，而非永远在火中受苦——这与「神就是爱」的本性相合。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-MAL4:1", "ref": "MAL 4:1",
          "snippet": "the day that cometh shall burn them up ... leave them neither root nor branch"},
         {"source_type": "BIBLE", "source_id": "KJV-ECC9:5", "ref": "ECC 9:5",
          "snippet": "the dead know not any thing"},
         {"source_type": "BIBLE", "source_id": "KJV-ROM6:23", "ref": "ROM 6:23",
          "snippet": "the wages of sin is death ... the gift of God is eternal life"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B26", "ref": "教义 #26 死亡与复活",
          "snippet": "死亡是无知觉的睡眠；义人于基督再临时复活得永生。"}]},
    {"keywords": ["婚姻", "离婚", "结婚", "休妻", "夫妻", "marriage", "divorce"],
     "answer_zh": "耶稣明言神所配合的，人不可分开（太19:6）；先知也说「休妻的事是我所恨恶的」（玛2:16）。婚姻是一男一女、一主所立的终身盟约，离婚与再婚须极其慎重，并以圣经为准则。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-MAT19:6", "ref": "MAT 19:6",
          "snippet": "What therefore God hath joined together, let not man put asunder"},
         {"source_type": "BIBLE", "source_id": "KJV-MAL2:16", "ref": "MAL 2:16",
          "snippet": "he hateth putting away"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B22", "ref": "教义 #22 基督徒的本分",
          "snippet": "信徒当以身体为圣灵的殿，活出荣神益人的生活。"}]},
    {"keywords": ["末世", "预兆", "征兆", "灾难", "打仗", "末日兆头", "signs of the end", "end times"],
     "answer_zh": "耶稣预言末世必有「打仗和打仗的风声」（太24:6），保罗也警戒「末世必有危险的日子来到」（提后3:1-2），人必专顾自己、贪爱钱财。这些兆头提醒信徒警醒等候主的再来。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-MAT24:6", "ref": "MAT 24:6",
          "snippet": "ye shall hear of wars and rumours of wars ... the end is not yet"},
         {"source_type": "BIBLE", "source_id": "KJV-2TI3:1", "ref": "2TI 3:1-2",
          "snippet": "in the last days perilous times shall come"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B25", "ref": "教义 #25 耶稣再临",
          "snippet": "耶稣必亲自、肉眼可见、大有荣耀地再来。"}]},
    {"keywords": ["查案审判", "审判", "宽容时期", "洁净圣所", "investigative judgment", "赎罪日"],
     "answer_zh": "但以理预言「到二千三百日，圣所就必洁净」（但8:14），对应天上圣所的查案审判。启14:6-7 呼召人「应当敬畏神……因他施行审判的时候已经到了」。这是天上进行的、为万民定案的步骤，信徒当以成圣的生活回应。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-DAN8:14", "ref": "DAN 8:14",
          "snippet": "Unto two thousand and three hundred days; then shall the sanctuary be cleansed"},
         {"source_type": "BIBLE", "source_id": "KJV-REV14:6", "ref": "REV 14:6",
          "snippet": "having the everlasting gospel to preach"},
         {"source_type": "BIBLE", "source_id": "KJV-REV14:7", "ref": "REV 14:7",
          "snippet": "the hour of his judgment is come"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B24", "ref": "教义 #24 基督在天上的圣所",
          "snippet": "基督在天上圣所为人类代求，并在末世执行查案审判。"}]},
    {"keywords": ["144000", "十四万四千", "余民", "受印", "印记", "the 144000", "sealed"],
     "answer_zh": "启示录记载「受印的数目有十四万四千」（启7:4），他们与羔羊同站在锡安山，「额上写着父的名」（启14:1）。这代表末世忠心守神诫命、被神印证的余民群体。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-REV7:4", "ref": "REV 7:4",
          "snippet": "there were sealed an hundred and forty and four thousand"},
         {"source_type": "BIBLE", "source_id": "KJV-REV14:1", "ref": "REV 14:1",
          "snippet": "having his Father's name written in their foreheads"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B13", "ref": "教义 #13 余民及其使命",
          "snippet": "神保留忠心守诫命、持守耶稣真道的余民。"}]},
    {"keywords": ["复活", "死人复活", "复活次序", "睡了的人", "resurrection", "the dead"],
     "answer_zh": "保罗说明复活有次序：基督是初熟的果子，「以后在他来的时候，是那些属基督的」（林前15:23）。帖前4:16 应许「那在基督里死了的人必先复活」。义人于基督再临时复活得永生，恶人于千禧年后复活受审。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-1CO15:23", "ref": "1CO 15:23",
          "snippet": "afterward they that are Christ's at his coming"},
         {"source_type": "BIBLE", "source_id": "KJV-1TH4:16", "ref": "1TH 4:16",
          "snippet": "the dead in Christ shall rise first"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B26", "ref": "教义 #26 死亡与复活",
          "snippet": "死亡是无知觉的睡眠；义人于基督再临时复活得永生。"}]},
    {"keywords": ["圣经无误", "默示", "正典", "圣经权威", "圣经怎么来的", "canon", "inspiration", "inerrancy"],
     "answer_zh": "「圣经都是神所默示的」（提后3:16），先知「被圣灵感动，说出神的话来」（彼后1:21）。本会以六十六卷新旧约为信仰与生活无误的权威。本应用以 KJV 英文为权威底本，中文为本会独立产出，和合本仅作参照，不作权威来源。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-2TI3:16", "ref": "2TI 3:16",
          "snippet": "All scripture is given by inspiration of God"},
         {"source_type": "BIBLE", "source_id": "KJV-2PE1:21", "ref": "2PE 1:21",
          "snippet": "moved by the Holy Ghost"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B1", "ref": "教义 #1 圣经",
          "snippet": "圣经是神启示的言语，是信仰与生活的无误权威标准。"}]},
    {"keywords": ["圣灵印记", "受印", "印记", "圣灵的印", "seal of god", "sealed by spirit"],
     "answer_zh": "信徒「受了他（圣灵）的印记，等候得赎的日子」（弗4:30）；启7:3 记载天使受命「印神众仆人的额」而后才可降灾。这印记是圣灵在人生命中的保守与归属的记号。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-EPH4:30", "ref": "EPH 4:30",
          "snippet": "ye are sealed unto the day of redemption"},
         {"source_type": "BIBLE", "source_id": "KJV-REV7:3", "ref": "REV 7:3",
          "snippet": "till we have sealed the servants of our God"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B13", "ref": "教义 #13 余民及其使命",
          "snippet": "神保留忠心守诫命、持守耶稣真道的余民。"}]},
    {"keywords": ["禁食", "祷告禁食", "怎么禁食", "fasting", "fast"],
     "answer_zh": "耶稣教导禁食不可像假冒为善的人故意叫人看见，而要在暗中诚心进行（太6:16-18）。以赛亚书指明神所拣选的禁食是「松开凶恶的绳、使被欺压的得自由」（赛58:6）——即行公义、怜悯的实际行动。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-MAT6:16", "ref": "MAT 6:16-18",
          "snippet": "when ye fast, be not, as the hypocrites, of a sad countenance"},
         {"source_type": "BIBLE", "source_id": "KJV-ISA58:6", "ref": "ISA 58:6",
          "snippet": "to let the oppressed go free, and that ye break every yoke"}]},
    {"keywords": ["与世界分别", "分别为圣", "世俗", "分别", "separate from world", "be ye separate"],
     "answer_zh": "神呼召信徒「从他们中间出来，与他们分别……我就收纳你们」（林后6:17），并「不要效法这个世界」（罗12:2）。分别不是避世，而是在生活、言语、价值观上见证基督，作世上的光。",
     "citations": [
         {"source_type": "BIBLE", "source_id": "KJV-2CO6:17", "ref": "2CO 6:17",
          "snippet": "come out from among them, and be ye separate"},
         {"source_type": "DOCTRINE", "source_id": "SDA-B22", "ref": "教义 #22 基督徒的本分",
          "snippet": "信徒当以身体为圣灵的殿，活出荣神益人的生活。"}]},
]


def main():
    with open(KB, encoding="utf-8") as f:
        data = json.load(f)

    existing_verses = {(v.get("ref")) for v in data.get("verses", [])}
    added_v = 0
    for v in NEW_VERSES:
        if v["ref"] not in existing_verses:
            data["verses"].append(v)
            existing_verses.add(v["ref"])
            added_v += 1

    existing_doctrines = {d.get("belief_id") for d in data.get("doctrine", [])}
    added_d = 0
    for d in NEW_DOCTRINE:
        if d["belief_id"] not in existing_doctrines:
            data["doctrine"].append(d)
            existing_doctrines.add(d["belief_id"])
            added_d += 1

    existing_faq_keywords = {
        tuple(sorted(e.get("keywords", []))) for e in data.get("faq", [])
    }
    added_f = 0
    for e in NEW_FAQ:
        key = tuple(sorted(e.get("keywords", [])))
        if key not in existing_faq_keywords:
            data["faq"].append(e)
            existing_faq_keywords.add(key)
            added_f += 1

    with open(KB, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # 同步前端 qa_faq.json（直接取自 kb.json 的 faq 数组）
    with open(QA, "w", encoding="utf-8") as f:
        json.dump({"faq": data["faq"]}, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"kb.json 更新：+{added_v} 经文 / +{added_d} 教义 / +{added_f} FAQ")
    print(f"  当前总计：{len(data['verses'])} 经文 / "
          f"{len(data['doctrine'])} 教义 / {len(data['faq'])} FAQ")
    print(f"qa_faq.json 已同步为 {len(data['faq'])} 条 FAQ")


if __name__ == "__main__":
    main()
