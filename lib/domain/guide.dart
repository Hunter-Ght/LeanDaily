// Content copied verbatim from Web guide.js and guide-extra.js.
// ignore_for_file: constant_identifier_names
const Map<String, dynamic> LIB = {
  "incline-pushup": {
    "label": "高位俯卧撑",
    "steps": [
      "双手撑在稳固的厨房台面或高桌上，略宽于肩，脚尖着地后退到身体成斜线",
      "从头到脚保持一条直线，收腹夹臀",
      "屈肘整块身体下降，胸口接近台面，再推回起始位置",
    ],
    "mistakes": ["先塌腰或撅屁股", "只点头、身体没往下", "台面会晃或打滑（不要用带轮子的椅子）"],
  },
  "incline-pushup-low": {
    "label": "低台面俯卧撑",
    "steps": [
      "手撑在比之前更低、但仍然稳固的支撑物上（矮桌、沙发扶手、楼梯台阶）",
      "其余动作和高位俯卧撑一样：身体成直线，整块下降",
      "胸口接近支撑物后推回",
    ],
    "mistakes": ["支撑物不稳", "为了多做一个而塌腰", "下降幅度越做越浅"],
  },
  "pushup": {
    "label": "俯卧撑（跪姿 / 标准）",
    "steps": [
      "手略宽于肩撑地；标准版脚尖着地，跪姿版膝盖着地，肩—髋—膝成一条线",
      "手肘约 45° 向后，不要外张成 T 形",
      "胸口接近地面后推起，顶端肩胛自然展开，不耸肩",
    ],
    "mistakes": ["塌腰或臀部翘太高", "手肘外张", "只做半程"],
  },
  "band-press": {
    "label": "弹力带胸推",
    "steps": [
      "弹力带从背后肩胛附近绕过，两手握住带的两端，手肘与肩大致同高",
      "向前推直，手肘不要完全锁死",
      "慢慢收回到胸侧，全程保持张力",
    ],
    "mistakes": ["弹力带老化破损还在用", "把带子挂在不牢的门把或家具上", "耸肩、让带子朝脸回弹"],
  },
  "db-shoulder-press": {
    "label": "哑铃肩推",
    "steps": ["坐或站，哑铃放在肩两侧，掌心朝前", "向上推到手臂接近伸直", "慢慢放回到耳朵两侧的高度"],
    "mistakes": ["腰往后仰借力", "5 kg 太重就改用水瓶，别硬上", "耸肩"],
  },
  "lateral-raise": {
    "label": "侧平举",
    "steps": ["站立，手握水瓶垂在身体两侧，肘微屈", "向两侧抬起到与肩同高", "控制速度慢慢放下"],
    "mistakes": ["耸肩", "甩手借力", "抬得比肩还高"],
  },
  "crunch": {
    "label": "卷腹",
    "steps": ["仰卧屈膝，双手轻放耳侧或胸前", "用腹部发力把肩胛卷离地面，顶端停 1 秒", "慢慢放回，下背不要弹起"],
    "mistakes": ["双手扯脖子", "过度拱腰", "靠甩上半身借力"],
  },
  "dead-bug": {
    "label": "死虫式",
    "steps": ["仰卧，双臂指向天花板，髋膝各弯曲 90°", "下背贴地，对侧的手和脚缓慢向远处伸直", "回到起始，换另一侧"],
    "mistakes": ["下背离开地面", "动作太快", "憋气"],
  },
  "db-row": {
    "label": "单臂哑铃划船",
    "steps": [
      "一手一膝撑在稳固的桌面或椅子上，背自然平直",
      "另一手握哑铃，把它拉向髋部，顶端停 1 秒",
      "慢慢放下，做完一侧再换另一侧",
    ],
    "mistakes": ["耸肩或扭转身体", "用惯性甩上来", "塌腰"],
  },
  "squat": {
    "label": "深蹲",
    "steps": ["双脚略宽于肩，脚尖微微向外", "屈髋屈膝向后坐，膝盖朝脚尖方向，背保持挺直", "大腿接近水平后踩地站起"],
    "mistakes": ["膝盖内扣", "为了负重弯腰塌背", "脚跟离地"],
  },
  "split-squat": {
    "label": "分腿蹲",
    "steps": ["一脚在前一脚在后站成弓步，身体保持直立", "垂直下降，后膝接近地面", "前脚发力站起，做完一侧再换另一侧"],
    "mistakes": ["身体前倾晃动", "前膝内扣", "站不稳时没有扶东西"],
  },
  "db-curl": {
    "label": "哑铃弯举",
    "steps": ["站立，手握哑铃垂在身侧，上臂贴紧身体", "弯起前臂到顶端，稍作停顿", "慢慢放下"],
    "mistakes": ["甩腰借力", "手肘前后晃", "5 kg 太重就交替单臂做"],
  },
  "glute-bridge": {
    "label": "臀桥",
    "steps": ["仰卧屈膝，双脚踩地", "臀部发力顶起，肩—髋—膝成一条线，顶端收紧臀部 1 秒", "慢慢放下"],
    "mistakes": ["用腰而不是臀部发力", "顶得太高导致腰拱", "膝盖往外或往里倒"],
  },
  "floor-press": {
    "label": "哑铃地板卧推",
    "steps": ["地上铺毛巾或垫子，仰卧屈膝，哑铃放在胸两侧", "手肘约 45°，把哑铃向上推到手臂伸直", "慢慢放回，上臂轻触地面即可"],
    "mistakes": ["手肘过度外张", "放下时砸地", "两只哑铃推得不同步"],
  },
  "reverse-crunch": {
    "label": "反向卷腹",
    "steps": ["仰卧，屈膝把小腿抬起", "用下腹把骨盆轻轻卷离地面", "慢慢放回，不要靠甩腿"],
    "mistakes": ["靠惯性甩腿", "腰部拱起", "速度太快"],
  },
  "plank": {
    "label": "平板支撑",
    "steps": ["前臂撑地，手肘在肩的正下方", "身体从头到脚成一条直线，收腹夹臀", "保持均匀呼吸，坚持到目标秒数"],
    "mistakes": ["屁股下塌或撅高", "腰拱起", "憋气"],
  },
  "machine-chest-press": {
    "label": "坐姿推胸机",
    "steps": [
      "调座椅，让握柄大致在胸部中段；背靠稳，肩胛收稳",
      "向前推到手臂接近伸直，不要耸肩，也不要锁死手肘",
      "慢慢收回，感受胸部被拉开，不要让重量片砸下去",
    ],
    "mistakes": ["座椅太高或太低，变成肩在发力", "耸肩", "借腰部或身体前冲来推"],
  },
  "machine-incline-press": {
    "label": "上斜推胸机",
    "steps": ["调座椅，让握柄在上胸前方；背靠稳", "向前上方推出，重点兼顾上胸", "慢慢收回，保持控制"],
    "mistakes": ["座椅调得过高，变成纯肩推", "耸肩", "推得太快"],
  },
  "machine-shoulder-press": {
    "label": "坐姿肩推机",
    "steps": ["调座椅，让握柄约在肩的高度；背靠稳", "在可控范围内向上推，不用推到锁死", "慢慢放回起始位置"],
    "mistakes": ["后仰、腰部过度拱起", "耸肩", "用爆发力猛推"],
  },
  "lat-pulldown": {
    "label": "高位下拉",
    "steps": [
      "坐稳，大腿压在垫子下，双手略宽于肩握横杆",
      "把横杆拉向上胸，肩膀下沉，不要一直耸着",
      "慢慢放回，手臂接近伸直，背部有被拉长的感觉",
    ],
    "mistakes": ["猛甩身体借力", "拉到脑后", "耸肩"],
  },
  "seated-row": {
    "label": "坐姿划船机",
    "steps": ["坐稳，胸口自然挺起，膝盖微屈", "把手柄拉向腹部，肩胛向后向下收", "慢慢放回，不要弓背前扑"],
    "mistakes": ["靠后仰借力", "耸肩", "手臂拉但背没发力"],
  },
  "leg-press": {
    "label": "腿举机",
    "steps": [
      "坐稳，双脚踩在踏板中间，与肩同宽，脚尖朝外微微打开",
      "膝盖对着脚尖方向，慢慢放下，腰背始终贴紧靠垫",
      "踩住脚掌推回，不要把膝盖完全锁死",
    ],
    "mistakes": ["放得太深导致腰背离开靠垫", "膝盖内扣", "脚跟离开踏板"],
  },
  "leg-curl": {
    "label": "腿弯举",
    "steps": ["调好座椅和靠垫，让膝盖对准机器转轴", "缓慢把小腿向后向下弯，感觉大腿后侧发力", "慢慢放回，不要弹"],
    "mistakes": ["借身体的力量甩", "速度太快", "重量过大导致臀部离开座椅"],
  },
  "cable-crossover": {
    "label": "拉力器高位向下夹胸",
    "steps": [
      "两侧滑轮调到较高位置，一脚在前站稳，身体微微前倾",
      "双手从胸侧较高位置，向身体前下方合拢",
      "慢慢放回，肩部不要被拉得过度向后",
    ],
    "mistakes": ["重量过重、肩不舒服还硬做", "耸肩", "用手臂拉而不是用胸"],
  },
  "butterfly": {
    "label": "蝴蝶机夹胸",
    "steps": ["调座椅，让握柄与胸同高；背靠稳", "双臂向中间合拢，感觉整个胸大肌收缩", "慢慢打开到有拉伸感，不要过度后拉"],
    "mistakes": ["耸肩", "打开得太大伤肩", "重量过重靠甩"],
  },
  "ab-machine": {
    "label": "卷腹机",
    "steps": ["调座椅和握把，让背靠稳", "卷动躯干，用腹部发力", "慢慢放回，不要只用手臂拉"],
    "mistakes": ["只用手臂拉", "速度太快", "腰部过度拱起"],
  },
  "cable-crunch": {
    "label": "绳索卷腹",
    "steps": ["跪在拉力器前，双手拉住绳索放在头两侧", "髋部固定不动，卷动躯干，肘向膝盖方向靠", "慢慢放回，保持腹部张力"],
    "mistakes": ["用手臂拉绳子", "整个身体前后晃动", "重量过大"],
  },
  "db-bench": {
    "label": "哑铃平板卧推",
    "steps": ["躺在平凳上，双脚踩稳，哑铃放在胸两侧，手肘约 45°", "向上推到手臂接近伸直", "慢慢放回，先用很轻的重量熟悉"],
    "mistakes": ["手肘过度外张", "重量太重失去控制", "背部过度拱起"],
  },
  "db-incline-press": {
    "label": "上斜哑铃卧推",
    "steps": ["凳子调成约 30° 上斜，哑铃放在胸上方两侧", "向上推起，重点在上胸", "慢慢放回，用很轻的重量先学动作"],
    "mistakes": ["凳子角度过大变成肩推", "重量过重", "耸肩"],
  },
  "goblet-squat": {
    "label": "高脚杯深蹲",
    "steps": ["双手抱住一只哑铃放在胸前，双脚略宽于肩", "背挺直向下坐，肘部在膝盖内侧", "踩地站起，膝盖朝脚尖方向"],
    "mistakes": ["含胸塌背", "膝盖内扣", "脚跟离地"],
  },
  "rdl": {
    "label": "罗马尼亚硬拉（髋部折叠）",
    "steps": [
      "站立，手握轻哑铃放在大腿前，膝盖微屈",
      "臀部向后推，背保持平直，重量沿腿下滑到膝盖附近",
      "感觉大腿后侧被拉长后，髋部向前把身体带起",
    ],
    "mistakes": ["弯腰而不是折髋", "膝盖弯得太多变成深蹲", "重量离腿太远"],
  },
  "machine-curl": {
    "label": "二头弯举机",
    "steps": ["调座椅，让上臂贴住垫子，肘部对准转轴", "弯起前臂，感觉肱二头肌发力", "慢慢放回，不要完全放松"],
    "mistakes": ["借腰部甩", "肘部离开垫子", "放得太快"],
  },
  "assisted-pullup": {
    "label": "辅助引体向上",
    "steps": ["调好辅助重量（辅助越大越容易），双手握住把手", "把胸口向横杆拉近，肩膀下沉", "慢慢放回到手臂接近伸直"],
    "mistakes": ["借身体摆动", "耸肩", "辅助重量太小还硬做"],
  },
  "hammer-curl": {
    "label": "锤式弯举",
    "steps": [
      "站稳，双手各握一只哑铃，拳眼朝前，手臂自然下垂",
      "肘部贴住身体两侧，把哑铃弯举到肩前，顶端停 1 秒",
      "慢慢放回，手臂接近伸直再做下一次",
    ],
    "mistakes": ["借身体后仰把哑铃甩上去", "肘部往前顶", "放下去太快"],
  },
  "band-pull-apart": {
    "label": "弹力带拉开",
    "steps": [
      "双手握住弹力带，手臂向前平伸到胸前高度，带子有轻微张力",
      "手臂保持伸直，向两侧水平拉开，肩胛向后夹",
      "顶端停 1 秒，慢慢回到起始位置",
    ],
    "mistakes": ["耸肩，用脖子和斜方肌发力", "腰向后仰借力", "带子没握稳，松手回弹打到脸"],
  },
  "rear-delt-fly": {
    "label": "俯身哑铃反向飞鸟",
    "steps": [
      "双脚与肩同宽，髋部向后推，上身前倾到接近与地面平行，背保持平直",
      "手握轻哑铃或水瓶自然下垂，肘部微屈",
      "向两侧抬起到与肩同高，顶端夹紧肩胛后停 1 秒，再慢慢放下",
    ],
    "mistakes": ["用太重的重量，变成甩着抬", "抬起时耸肩或拱背", "手臂完全伸直锁住肘关节"],
  },
  "front-raise": {
    "label": "前平举",
    "steps": ["站稳，双手各握一个轻哑铃或水瓶放在大腿前", "手臂微屈，向前抬到与肩同高", "停 1 秒，慢慢放回，不要靠身体晃动"],
    "mistakes": ["抬过头顶", "身体后仰借力", "重量太重"],
  },
  "bent-row": {
    "label": "弯腰双臂哑铃划船",
    "steps": [
      "双脚与肩同宽，髋部向后推，上身前倾约 45 度，背平直，膝微屈",
      "双手握哑铃自然下垂，把哑铃拉向肚脐两侧，肘贴近身体",
      "顶端夹紧肩胛停 1 秒，慢慢放下",
    ],
    "mistakes": ["圆背、塌腰", "用手臂拉而不是用背", "身体随着重量上下晃"],
  },
  "bench-dip": {
    "label": "椅子臂屈伸",
    "steps": [
      "双手撑在稳固的椅子边缘，手指朝前，双腿向前伸出，脚跟着地",
      "屈肘让身体垂直向下，到上臂接近水平",
      "用手臂力量撑回起始位置，肩不要耸起",
    ],
    "mistakes": ["椅子会滑或带轮子", "下放太深，肩前侧压得很紧", "身体离椅子太远"],
  },
  "db-tricep-ext": {
    "label": "站姿哑铃臂屈伸",
    "steps": [
      "站稳，双手托住一只哑铃举过头顶，手臂伸直",
      "上臂贴近耳侧不动，只弯曲肘部，把哑铃放到脑后",
      "用肱三头肌发力把哑铃推回头顶",
    ],
    "mistakes": ["手肘向两边打开", "腰向后拱", "重量太重，放到一半就失控"],
  },
  "kickback": {
    "label": "哑铃臂后屈伸",
    "steps": [
      "一手一膝撑在稳固的椅子或床沿，上身前倾，背平直",
      "另一手握轻哑铃，上臂贴住身体，肘弯成 90 度",
      "把哑铃向后伸直手臂，顶端停 1 秒，慢慢放回；每侧做完为一组",
    ],
    "mistakes": ["甩手臂借力", "上臂不贴身，肘部乱晃", "重量太重，背跟着晃"],
  },
  "side-plank": {
    "label": "侧平板支撑",
    "steps": [
      "侧躺，前臂撑地，肘在肩正下方，双脚叠放",
      "抬起髋部，让身体从头到脚成一条直线",
      "保持呼吸，坚持到设定的秒数；每侧做完为一组",
    ],
    "mistakes": ["髋部下沉", "肩膀耸起贴近耳朵", "憋气"],
  },
  "russian-twist": {
    "label": "俄罗斯转体",
    "steps": [
      "坐在垫子上，膝盖弯曲，上身后倾到能保持背部平直的位置",
      "双手合十（或抱一只轻哑铃）放在胸前",
      "带动躯干向左右转动，眼睛跟着手；左右各一次算 1 次",
    ],
    "mistakes": ["只是手臂在摆，躯干没转", "拱背低头", "脚下滑，用惯性甩"],
  },
  "superman": {
    "label": "超人式",
    "steps": [
      "俯卧在垫子上，手臂向前伸直，双腿并拢伸直",
      "同时抬起手臂和双腿，用下背和臀部发力，顶端停 1～2 秒",
      "慢慢放回，不要猛地甩下去",
    ],
    "mistakes": ["抬得太高，腰部发紧或刺痛", "猛抬头，颈部过伸", "憋气"],
  },
  "single-leg-bridge": {
    "label": "单腿臀桥",
    "steps": [
      "仰卧屈膝，一只脚踩稳，另一条腿伸直抬起",
      "用踩地的脚发力把髋部向上顶到身体成一条线",
      "顶端收紧臀部 1 秒，慢慢放下；每侧做完为一组",
    ],
    "mistakes": ["腰部过度挺起，用腰而不是臀发力", "骨盆左右歪", "踩地的脚离臀部太远"],
  },
  "calf-raise": {
    "label": "站姿提踵",
    "steps": [
      "站稳，双脚与髋同宽，一手扶墙保持平衡（可站在台阶边缘，脚跟悬空）",
      "脚跟慢慢抬到最高，停 1 秒",
      "慢慢放下，脚跟下沉到有拉伸感再做下一次",
    ],
    "mistakes": ["速度太快，靠弹跳", "膝盖弯曲借力", "没有抬到最高、也没有放到最低"],
  },
  "feet-up-pushup": {
    "label": "脚抬高俯卧撑",
    "steps": [
      "双脚搭在稳固的椅子或台面上，双手撑地略宽于肩，身体成一条直线",
      "屈肘整块身体下降，胸口接近地面",
      "推回起始位置，保持收腹夹臀",
    ],
    "mistakes": ["塌腰或撅屁股", "台面会晃", "做不动还硬撑，动作变形"],
  },
  "band-fly": {
    "label": "弹力带夹胸",
    "steps": [
      "把弹力带绕过背后稳固的位置，双手握住两端，手臂向两侧微屈抬到胸前高度",
      "保持肘部微屈，把手向身体前方合拢到胸前",
      "顶端夹紧胸部停 1 秒，慢慢打开",
    ],
    "mistakes": ["带子没固定牢，回弹", "耸肩", "手臂完全伸直锁住肘关节"],
  },
  "leg-extension": {
    "label": "腿屈伸机",
    "steps": [
      "调整座椅，让膝盖对准机器转轴，脚踝垫贴在小腿下端",
      "用大腿前侧发力把腿伸直，顶端停 1 秒",
      "慢慢放回，不要让配重片砸下去",
    ],
    "mistakes": ["重量太重，用惯性甩起来", "臀部离开座椅", "放下太快"],
  },
  "pushdown": {
    "label": "绳索下压",
    "steps": [
      "站在高位拉力器前，双手握住绳索或横杆，肘部贴住身体两侧",
      "只动前臂，把绳索向下压到手臂伸直",
      "停 1 秒，慢慢放回，肘部始终贴身",
    ],
    "mistakes": ["肘部向前后晃", "身体前倾压着下去", "重量太重，耸肩"],
  },
  "face-pull": {
    "label": "绳索面拉",
    "steps": [
      "把拉力器调到与脸齐高，双手握住绳索两端，后退一步",
      "把绳索拉向脸部两侧，手肘向外打开，肩胛向后夹",
      "停 1 秒，慢慢放回",
    ],
    "mistakes": ["重量太重，身体后仰", "只用手臂拉，肩胛没动", "耸肩"],
  },
  "straight-arm": {
    "label": "直臂下拉",
    "steps": [
      "面对高位拉力器站立，双手握住横杆，手臂近乎伸直，上身微前倾",
      "手臂保持伸直，用背阔肌把横杆压到大腿前",
      "停 1 秒，慢慢放回到高过头顶的位置",
    ],
    "mistakes": ["弯曲手臂变成下压", "用身体往下压重量", "重量太重，腰部代偿"],
  },
  "reverse-pec-deck": {
    "label": "反向蝴蝶机",
    "steps": [
      "面朝机器靠垫坐好，调整座椅使握把与肩同高",
      "手臂微屈，向两侧向后打开，肩胛向后夹",
      "停 1 秒，慢慢放回，不要让配重片砸下去",
    ],
    "mistakes": ["重量太重，身体向后靠", "耸肩", "手臂伸直锁肘"],
  },
  "seated-calf": {
    "label": "坐姿提踵机",
    "steps": [
      "坐在机器上，调整膝垫压在大腿下端，前脚掌踩在踏板上",
      "脚跟慢慢降到有拉伸感，再用小腿发力抬到最高",
      "顶端停 1 秒，慢慢放下",
    ],
    "mistakes": ["速度太快", "幅度太小", "用膝盖的力量弹起来"],
  },
  "back-extension": {
    "label": "背部伸展",
    "steps": [
      "趴在罗马椅上，髋部贴住垫子边缘，脚跟固定，手臂交叉放在胸前",
      "上身保持平直，从髋部折叠向下，再用臀部和下背抬起到身体成一条直线",
      "顶端不要过度后仰",
    ],
    "mistakes": ["抬得太高，腰部过度后伸", "甩着上来", "圆背向下"],
  },
};
const Map<String, String> NAME_MAP = {
  "高位俯卧撑": "incline-pushup",
  "低台面俯卧撑": "incline-pushup-low",
  "跪姿俯卧撑": "pushup",
  "标准俯卧撑": "pushup",
  "俯卧撑": "pushup",
  "弹力带胸推": "band-press",
  "哑铃肩推": "db-shoulder-press",
  "轻重量侧平举": "lateral-raise",
  "轻哑铃侧平举": "lateral-raise",
  "侧平举": "lateral-raise",
  "卷腹": "crunch",
  "死虫式": "dead-bug",
  "单臂哑铃划船": "db-row",
  "深蹲": "squat",
  "分腿蹲": "split-squat",
  "哑铃弯举": "db-curl",
  "臀桥": "glute-bridge",
  "哑铃地板卧推": "floor-press",
  "反向卷腹": "reverse-crunch",
  "平板支撑": "plank",
  "坐姿推胸机": "machine-chest-press",
  "上斜推胸机": "machine-incline-press",
  "坐姿肩推机": "machine-shoulder-press",
  "高位下拉": "lat-pulldown",
  "坐姿划船机": "seated-row",
  "腿举机": "leg-press",
  "坐姿腿弯举": "leg-curl",
  "腿弯举": "leg-curl",
  "拉力器高位向下夹胸": "cable-crossover",
  "蝴蝶机夹胸": "butterfly",
  "卷腹机": "ab-machine",
  "绳索卷腹": "cable-crunch",
  "哑铃平板卧推": "db-bench",
  "上斜哑铃卧推": "db-incline-press",
  "高脚杯深蹲": "goblet-squat",
  "轻哑铃罗马尼亚硬拉": "rdl",
  "二头弯举机": "machine-curl",
  "辅助引体向上机": "assisted-pullup",
  "轻哑铃坐姿肩推": "db-shoulder-press",
  "徒手深蹲": "squat",
  "拉力器单臂侧平举": "lateral-raise",
  "锤式弯举": "hammer-curl",
  "弹力带拉开": "band-pull-apart",
  "俯身哑铃反向飞鸟": "rear-delt-fly",
  "前平举": "front-raise",
  "弯腰双臂哑铃划船": "bent-row",
  "椅子臂屈伸": "bench-dip",
  "站姿哑铃臂屈伸": "db-tricep-ext",
  "哑铃臂后屈伸": "kickback",
  "侧平板支撑": "side-plank",
  "俄罗斯转体": "russian-twist",
  "超人式": "superman",
  "单腿臀桥": "single-leg-bridge",
  "站姿提踵": "calf-raise",
  "脚抬高俯卧撑": "feet-up-pushup",
  "弹力带夹胸": "band-fly",
  "腿屈伸机": "leg-extension",
  "绳索下压": "pushdown",
  "绳索面拉": "face-pull",
  "直臂下拉": "straight-arm",
  "反向蝴蝶机": "reverse-pec-deck",
  "坐姿提踵机": "seated-calf",
  "背部伸展": "back-extension",
};
const List<Map<String, String>> LIB_OPTIONS = [
  {"key": "incline-pushup", "label": "高位俯卧撑"},
  {"key": "incline-pushup-low", "label": "低台面俯卧撑"},
  {"key": "pushup", "label": "俯卧撑（跪姿 / 标准）"},
  {"key": "band-press", "label": "弹力带胸推"},
  {"key": "db-shoulder-press", "label": "哑铃肩推"},
  {"key": "lateral-raise", "label": "侧平举"},
  {"key": "crunch", "label": "卷腹"},
  {"key": "dead-bug", "label": "死虫式"},
  {"key": "db-row", "label": "单臂哑铃划船"},
  {"key": "squat", "label": "深蹲"},
  {"key": "split-squat", "label": "分腿蹲"},
  {"key": "db-curl", "label": "哑铃弯举"},
  {"key": "glute-bridge", "label": "臀桥"},
  {"key": "floor-press", "label": "哑铃地板卧推"},
  {"key": "reverse-crunch", "label": "反向卷腹"},
  {"key": "plank", "label": "平板支撑"},
  {"key": "machine-chest-press", "label": "坐姿推胸机"},
  {"key": "machine-incline-press", "label": "上斜推胸机"},
  {"key": "machine-shoulder-press", "label": "坐姿肩推机"},
  {"key": "lat-pulldown", "label": "高位下拉"},
  {"key": "seated-row", "label": "坐姿划船机"},
  {"key": "leg-press", "label": "腿举机"},
  {"key": "leg-curl", "label": "腿弯举"},
  {"key": "cable-crossover", "label": "拉力器高位向下夹胸"},
  {"key": "butterfly", "label": "蝴蝶机夹胸"},
  {"key": "ab-machine", "label": "卷腹机"},
  {"key": "cable-crunch", "label": "绳索卷腹"},
  {"key": "db-bench", "label": "哑铃平板卧推"},
  {"key": "db-incline-press", "label": "上斜哑铃卧推"},
  {"key": "goblet-squat", "label": "高脚杯深蹲"},
  {"key": "rdl", "label": "罗马尼亚硬拉（髋部折叠）"},
  {"key": "machine-curl", "label": "二头弯举机"},
  {"key": "assisted-pullup", "label": "辅助引体向上"},
  {"key": "hammer-curl", "label": "锤式弯举"},
  {"key": "band-pull-apart", "label": "弹力带拉开"},
  {"key": "rear-delt-fly", "label": "俯身哑铃反向飞鸟"},
  {"key": "front-raise", "label": "前平举"},
  {"key": "bent-row", "label": "弯腰双臂哑铃划船"},
  {"key": "bench-dip", "label": "椅子臂屈伸"},
  {"key": "db-tricep-ext", "label": "站姿哑铃臂屈伸"},
  {"key": "kickback", "label": "哑铃臂后屈伸"},
  {"key": "side-plank", "label": "侧平板支撑"},
  {"key": "russian-twist", "label": "俄罗斯转体"},
  {"key": "superman", "label": "超人式"},
  {"key": "single-leg-bridge", "label": "单腿臀桥"},
  {"key": "calf-raise", "label": "站姿提踵"},
  {"key": "feet-up-pushup", "label": "脚抬高俯卧撑"},
  {"key": "band-fly", "label": "弹力带夹胸"},
  {"key": "leg-extension", "label": "腿屈伸机"},
  {"key": "pushdown", "label": "绳索下压"},
  {"key": "face-pull", "label": "绳索面拉"},
  {"key": "straight-arm", "label": "直臂下拉"},
  {"key": "reverse-pec-deck", "label": "反向蝴蝶机"},
  {"key": "seated-calf", "label": "坐姿提踵机"},
  {"key": "back-extension", "label": "背部伸展"},
];

String frameAsset(String key, int i) => 'assets/exercises/$key/$i.jpg';

Map<String, dynamic>? guideFor(Map<String, dynamic>? ex) {
  final img = ex?['img'];
  final key = img is String && img.isNotEmpty && LIB.containsKey(img)
      ? img
      : NAME_MAP[ex?['name']];
  final guide = LIB[key];
  return guide is Map
      ? {
          'key': key,
          ...Map<String, dynamic>.from(guide),
          'frames': [frameAsset(key!, 0), frameAsset(key, 1)],
        }
      : null;
}

// encodeComponent follows JavaScript encodeURIComponent, including !'()*.
String videoSearchUrl(String name) =>
    'https://search.bilibili.com/all?keyword=${Uri.encodeComponent('$name 动作 教学')}';
