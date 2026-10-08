import 'dart:math';

// Editorial prompts, not measured popularity. Based on upstream README topics
// and the chapter/entry references in the bundled guide snapshot.
const popularQuestionPool = [
  '被裁员后，应该先做哪些事？', // README: 被裁了之后先做什么
  '换工作、换城市之前，要考虑什么？', // README: 换工作、换城市之前
  '家里有哪些值得准备的应急用品？', // README: 家庭应急装备清单
  '经常上夜班，怎样安排作息？', // README: 生物钟和夜班
  '孩子出生前后，需要办理哪些手续？', // README: 孩子出生前后要办的事
  '坐车时，后排乘客要注意哪些安全问题？', // 1.1
  '骑电动车，怎样选择和正确佩戴头盔？', // 1.2
  '家里需要装烟雾或一氧化碳报警器吗？', // 1.3
  '想戒烟，怎样开始更容易坚持？', // 2.1
  '怎样减少家人接触二手烟？', // 2.2
  '戒烟总是失败，可以寻求哪些专业帮助？', // 2.3
  '工作时总被手机打断，怎样减少干扰？', // 3.1
  '周末总想补觉，怎样安排起床时间？', // 3.2
  '每天只睡六小时够吗？怎样改善睡眠？', // 3.3
  '计划总是拖延，怎样把目标变成具体行动？', // 4.1
  '开始一件事前，怎样设定停止投入的条件？', // 4.2
  '已经投入很多却没效果，要不要继续？', // 4.3
  '怎样检查和减少不必要的自动续费？', // 5.1
  '做个税汇算前，需要核对哪些信息？', // 5.2
  '租房时，怎样了解公积金提取条件？', // 5.3
  '没有明确缺乏时，有必要吃复合维生素吗？', // 6.1
  '为了心血管健康，有必要买普通鱼油吗？', // 6.2
  '哪些情况下需要考虑补充维生素 D？', // 6.3
  '失业后，怎样了解失业保险金申领条件？', // 7.1
  '工资被拖欠，应该先准备哪些材料？', // 7.2
  '请不起律师，可以申请法律援助吗？', // 7.3
  '日常生活中，怎样识别常见的诈骗套路？', // 8.3
  '转发群里的消息前，怎样判断是否可靠？', // 9.1
  '想认识合适的人，可以从哪些行动开始？', // 10.1
  '怎样判断一段关系是否值得继续投入？', // 10.3
];

/// Keep a batch stable while editing; exclude the previous batch on re-entry.
List<String> pickPopularQuestions({
  List<String> previous = const [],
  Random? random,
}) {
  final candidates =
      popularQuestionPool
          .where((question) => !previous.contains(question))
          .toList()
        ..shuffle(random);
  return List.unmodifiable(candidates.take(5));
}
