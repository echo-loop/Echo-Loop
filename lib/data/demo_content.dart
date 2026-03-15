/// 演示模式静态数据定义
///
/// 包含 5 篇演示音频的完整转录文本、句子时间轴、学习进度配置、
/// 收藏句子/单词列表、每日学习统计等。所有数据来自精心设计的
/// 演示用户画像（28 岁职场人，B1-B2 水平，连续学习 14 天）。
library;

/// 演示音频元数据
class DemoAudioMeta {
  final String id;
  final String title;
  final int durationSeconds;
  final int difficulty; // DifficultyLevel.value: 1=easy, 2=medium, 3=hard
  final String currentStage; // LearningStage.key
  final String currentSubStage; // SubStageType.key
  final List<DemoSentence> sentences;
  final List<int> bookmarkIndices;

  /// 首次学习完成距今天数（null = 尚未完成首次学习）
  final int? firstLearnCompletedDaysAgo;

  /// 上一阶段完成距今天数（null = 无）
  final int? lastStageCompletedDaysAgo;

  /// 跟读断点句子索引（仅首次学习阶段有效）
  final int? shadowingSentenceIndex;

  const DemoAudioMeta({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.difficulty,
    required this.currentStage,
    required this.currentSubStage,
    required this.sentences,
    required this.bookmarkIndices,
    this.firstLearnCompletedDaysAgo,
    this.lastStageCompletedDaysAgo,
    this.shadowingSentenceIndex,
  });

  int get sentenceCount => sentences.length;
  int get wordCount =>
      sentences.fold(0, (sum, s) => sum + s.text.split(RegExp(r'\s+')).length);

  /// 生成 SRT 格式字幕内容
  String toSrt() {
    final buf = StringBuffer();
    for (var i = 0; i < sentences.length; i++) {
      final s = sentences[i];
      buf.writeln(i + 1);
      buf.writeln('${_formatSrtTime(s.startTime)} --> ${_formatSrtTime(s.endTime)}');
      buf.writeln(s.text);
      buf.writeln();
    }
    return buf.toString();
  }

  static String _formatSrtTime(double seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).truncate().toString().padLeft(2, '0');
    final ms = ((seconds * 1000) % 1000).truncate().toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }
}

/// 演示句子数据
class DemoSentence {
  final double startTime;
  final double endTime;
  final String text;

  const DemoSentence(this.startTime, this.endTime, this.text);
}

// ---------------------------------------------------------------------------
// 固定 UUID（确保幂等）
// ---------------------------------------------------------------------------

/// 演示合集 ID
const demoCollectionId = 'demo-collection-0001';

/// 演示音频 ID
const demoAudioIds = [
  'demo-audio-0001',
  'demo-audio-0002',
  'demo-audio-0003',
  'demo-audio-0004',
  'demo-audio-0005',
];

// ---------------------------------------------------------------------------
// 5 篇演示音频
// ---------------------------------------------------------------------------

const demoAudios = [
  // #1 Why We Procrastinate — easy, review4 locked（review2 完成 2 天前，review4 需 4 天→锁定）
  DemoAudioMeta(
    id: 'demo-audio-0001',
    title: 'Why We Procrastinate',
    durationSeconds: 44,
    difficulty: 1, // easy
    currentStage: 'review4',
    currentSubStage: 'blindListen',
    firstLearnCompletedDaysAgo: 12,
    lastStageCompletedDaysAgo: 2,
    sentences: [
      DemoSentence(0.0, 4.2,
          'We all know that sinking feeling when a deadline is approaching and we haven\'t even started.'),
      DemoSentence(4.5, 8.8,
          'Instead of working on what matters, we find ourselves scrolling through social media or reorganizing our desk.'),
      DemoSentence(9.1, 13.5,
          'Procrastination isn\'t really about being lazy or having poor time management skills.'),
      DemoSentence(13.8, 18.2,
          'It\'s actually an emotional regulation problem, a way our brain tries to avoid negative feelings.'),
      DemoSentence(18.5, 22.8,
          'When a task feels overwhelming, boring, or tied to our fear of failure, our brain seeks immediate comfort.'),
      DemoSentence(23.1, 27.0,
          'Research from psychology shows that procrastinators often struggle with managing difficult emotions.'),
      DemoSentence(27.3, 31.5,
          'The irony is that avoiding the task usually makes those negative feelings even stronger over time.'),
      DemoSentence(31.8, 36.2,
          'One simple strategy is to break your work into tiny pieces and commit to just five minutes.'),
      DemoSentence(36.5, 40.5,
          'Once you actually start, you\'ll often find that the resistance fades away surprisingly quickly.'),
      DemoSentence(40.8, 44.0,
          'Understanding the emotional root of procrastination is the first step toward beating it.'),
    ],
    bookmarkIndices: [3, 4, 5],
  ),

  // #2 The Hidden Cost of Fast Fashion — medium, review2 locked（review1 完成 1 天前，review2 需 2 天→锁定）
  DemoAudioMeta(
    id: 'demo-audio-0002',
    title: 'The Hidden Cost of Fast Fashion',
    durationSeconds: 56,
    difficulty: 2, // medium
    currentStage: 'review2',
    currentSubStage: 'blindListen',
    firstLearnCompletedDaysAgo: 10,
    lastStageCompletedDaysAgo: 1,
    sentences: [
      DemoSentence(0.0, 5.0,
          'Have you ever wondered what happens to that ten-dollar T-shirt after you throw it away?'),
      DemoSentence(5.3, 10.2,
          'The fast fashion industry produces over a hundred billion garments every single year.'),
      DemoSentence(10.5, 15.5,
          'Most of these clothes are designed to be worn just a handful of times before being discarded.'),
      DemoSentence(15.8, 20.8,
          'The environmental impact is staggering, from water pollution to massive textile waste in landfills.'),
      DemoSentence(21.1, 26.0,
          'It takes about twenty-seven hundred liters of water to produce a single cotton T-shirt.'),
      DemoSentence(26.3, 31.0,
          'That\'s roughly what one person drinks in two and a half years.'),
      DemoSentence(31.3, 36.5,
          'Beyond the environment, there\'s a human cost that often goes unnoticed by consumers.'),
      DemoSentence(36.8, 42.0,
          'Many garment workers in developing countries earn far below a living wage and work in unsafe conditions.'),
      DemoSentence(42.3, 47.5,
          'Some brands are now embracing sustainable practices, using recycled materials and ethical supply chains.'),
      DemoSentence(47.8, 52.0,
          'As consumers, we can make a difference by buying less and choosing quality over quantity.'),
      DemoSentence(52.3, 56.0,
          'Every purchase we make is essentially a vote for the kind of world we want to live in.'),
    ],
    bookmarkIndices: [3, 4, 6, 7],
  ),

  // #3 How Your Brain Learns a Language — medium, review1 到期（review0 完成 2 天前，review1 需 1 天→到期 1 天）
  DemoAudioMeta(
    id: 'demo-audio-0003',
    title: 'How Your Brain Learns a Language',
    durationSeconds: 59,
    difficulty: 2, // medium
    currentStage: 'review1',
    currentSubStage: 'blindListen',
    firstLearnCompletedDaysAgo: 7,
    lastStageCompletedDaysAgo: 2,
    sentences: [
      DemoSentence(0.0, 5.5,
          'Learning a new language might feel impossible at first, but your brain is actually wired for it.'),
      DemoSentence(5.8, 10.5,
          'Babies can distinguish between all the sounds in every language during their first six months of life.'),
      DemoSentence(10.8, 16.0,
          'As we grow older, our brains become specialized for our native language, making new sounds harder to hear.'),
      DemoSentence(16.3, 21.0,
          'But here\'s the good news: adults have one major advantage that children don\'t.'),
      DemoSentence(21.3, 26.5,
          'We can use our existing knowledge to make connections and learn vocabulary much faster.'),
      DemoSentence(26.8, 32.0,
          'The key to language learning isn\'t memorizing grammar rules or vocabulary lists in isolation.'),
      DemoSentence(32.3, 37.0,
          'It\'s about getting massive amounts of comprehensible input, listening and reading at your level.'),
      DemoSentence(37.3, 42.5,
          'Your brain needs to encounter new words in context, ideally multiple times across different situations.'),
      DemoSentence(42.8, 48.0,
          'Neuroscience research suggests that sleep plays a critical role in consolidating new language memories.'),
      DemoSentence(48.3, 53.5,
          'So the most effective approach combines regular practice during the day with good sleep at night.'),
      DemoSentence(53.8, 59.0,
          'With consistent exposure and practice, your brain will gradually rewire itself to think in the new language.'),
    ],
    bookmarkIndices: [1, 2, 6, 7, 8],
  ),

  // #4 Remote Work Changed Everything — hard, review0 locked（今天刚完成首学，review0 需 6h→锁定）
  DemoAudioMeta(
    id: 'demo-audio-0004',
    title: 'Remote Work Changed Everything',
    durationSeconds: 53,
    difficulty: 3, // hard
    currentStage: 'review0',
    currentSubStage: 'reviewDifficultPractice',
    firstLearnCompletedDaysAgo: 0,
    lastStageCompletedDaysAgo: 0,
    sentences: [
      DemoSentence(0.0, 5.0,
          'Three years ago, most of us couldn\'t have imagined working from our kitchen tables every day.'),
      DemoSentence(5.3, 10.5,
          'The pandemic forced a massive experiment in remote work that nobody had planned for.'),
      DemoSentence(10.8, 16.0,
          'What surprised many companies was that productivity actually went up, not down, when people worked from home.'),
      DemoSentence(16.3, 21.5,
          'Employees saved hours of commuting time and gained more flexibility to manage their personal lives.'),
      DemoSentence(21.8, 27.0,
          'But remote work also brought unexpected challenges, like loneliness and the blurring of work-life boundaries.'),
      DemoSentence(27.3, 32.0,
          'Many people found themselves working longer hours because there was no clear signal to stop.'),
      DemoSentence(32.3, 37.5,
          'The debate between fully remote, hybrid, and return-to-office models continues to divide opinions.'),
      DemoSentence(37.8, 43.0,
          'Some CEOs argue that innovation requires spontaneous in-person interactions that video calls can\'t replicate.'),
      DemoSentence(43.3, 48.0,
          'Others point out that forcing people back to the office ignores the diversity of how people do their best work.'),
      DemoSentence(48.3, 53.0,
          'Whatever the future holds, it\'s clear that our relationship with the workplace has fundamentally changed.'),
    ],
    bookmarkIndices: [2, 4, 7, 8],
  ),

  // #5 The Art of Small Talk — medium, firstLearn 进行中（已完成盲听/精听/跟读，正在复述）
  DemoAudioMeta(
    id: 'demo-audio-0005',
    title: 'The Art of Small Talk',
    durationSeconds: 62,
    difficulty: 2, // medium
    currentStage: 'firstLearn',
    currentSubStage: 'retell',
    firstLearnCompletedDaysAgo: null,
    lastStageCompletedDaysAgo: null,
    sentences: [
      DemoSentence(0.0, 5.0,
          'Small talk gets a bad reputation, but it\'s actually one of the most important social skills you can develop.'),
      DemoSentence(5.3, 10.0,
          'It\'s the gateway to deeper conversations and meaningful connections with other people.'),
      DemoSentence(10.3, 15.0,
          'The biggest mistake people make is thinking they need to say something brilliant or witty.'),
      DemoSentence(15.3, 20.0,
          'In reality, the best small talkers are simply good listeners who show genuine curiosity.'),
      DemoSentence(20.3, 25.5,
          'Instead of asking yes-or-no questions, try open-ended ones that invite people to share their stories.'),
      DemoSentence(25.8, 31.0,
          'For example, rather than asking "Did you have a good weekend?", try "What was the highlight of your weekend?"'),
      DemoSentence(31.3, 36.0,
          'People love talking about their experiences, their passions, and their opinions on everyday topics.'),
      DemoSentence(36.3, 41.5,
          'Another useful technique is to comment on your shared environment or situation.'),
      DemoSentence(41.8, 47.0,
          'Something as simple as mentioning the weather, the venue, or the event can spark a natural conversation.'),
      DemoSentence(47.3, 52.0,
          'Don\'t be afraid of brief silences; they\'re a normal part of any conversation.'),
      DemoSentence(52.3, 57.0,
          'The key is to stay present and engaged rather than worrying about what to say next.'),
      DemoSentence(57.3, 62.0,
          'With practice, small talk becomes less awkward and more enjoyable for everyone involved.'),
    ],
    bookmarkIndices: [0, 3, 4, 5],
  ),
];

// ---------------------------------------------------------------------------
// 收藏单词列表（22 个，来源于 5 篇音频中的关键词汇）
// ---------------------------------------------------------------------------

/// 演示收藏单词
class DemoSavedWord {
  final String word;
  final int audioIndex; // demoAudios 中的索引
  final int sentenceIndex;

  const DemoSavedWord(this.word, this.audioIndex, this.sentenceIndex);
}

const demoSavedWords = [
  // Audio 1: Why We Procrastinate
  DemoSavedWord('procrastination', 0, 2),
  DemoSavedWord('overwhelming', 0, 4),
  DemoSavedWord('resistance', 0, 8),
  // Audio 2: Fast Fashion
  DemoSavedWord('garments', 1, 1),
  DemoSavedWord('staggering', 1, 3),
  DemoSavedWord('discarded', 1, 2),
  DemoSavedWord('sustainable', 1, 8),
  DemoSavedWord('ethical', 1, 8),
  // Audio 3: Brain & Language
  DemoSavedWord('distinguish', 2, 1),
  DemoSavedWord('specialized', 2, 2),
  DemoSavedWord('comprehensible', 2, 6),
  DemoSavedWord('consolidating', 2, 8),
  DemoSavedWord('isolation', 2, 5),
  // Audio 4: Remote Work
  DemoSavedWord('spontaneous', 3, 7),
  DemoSavedWord('blurring', 3, 4),
  DemoSavedWord('hybrid', 3, 6),
  DemoSavedWord('replicate', 3, 7),
  DemoSavedWord('diversity', 3, 8),
  DemoSavedWord('fundamentally', 3, 9),
  // Audio 5: Small Talk
  DemoSavedWord('brilliant', 4, 2),
  DemoSavedWord('genuine', 4, 3),
  DemoSavedWord('witty', 4, 2),
];

// ---------------------------------------------------------------------------
// 阶段完成历史生成配置
// ---------------------------------------------------------------------------

/// 生成某篇音频已完成的阶段列表。
///
/// 返回 (stage, subStage, daysAgo) 三元组列表。
List<(String, String, int)> generateStageCompletions(int audioIndex) {
  // 根据每篇音频的进度，回推完成历史
  return switch (audioIndex) {
    // Audio 1: review4 locked（review2 完成 2 天前）
    0 => [
        ('firstLearn', 'blindListen', 13),
        ('firstLearn', 'intensiveListen', 13),
        ('firstLearn', 'listenAndRepeat', 12),
        ('firstLearn', 'retell', 12),
        ('review0', 'reviewDifficultPractice', 12),
        ('review0', 'reviewRetellParagraph', 12),
        ('review1', 'blindListen', 5),
        ('review1', 'reviewDifficultPractice', 5),
        ('review1', 'reviewRetellParagraph', 5),
        ('review2', 'blindListen', 2),
        ('review2', 'reviewDifficultPractice', 2),
        ('review2', 'reviewRetellParagraph', 2),
      ],
    // Audio 2: review2 locked（review1 完成 1 天前）
    1 => [
        ('firstLearn', 'blindListen', 11),
        ('firstLearn', 'intensiveListen', 11),
        ('firstLearn', 'listenAndRepeat', 10),
        ('firstLearn', 'retell', 10),
        ('review0', 'reviewDifficultPractice', 10),
        ('review0', 'reviewRetellParagraph', 10),
        ('review1', 'blindListen', 1),
        ('review1', 'reviewDifficultPractice', 1),
        ('review1', 'reviewRetellParagraph', 1),
      ],
    // Audio 3: review1 到期（review0 完成 2 天前）
    2 => [
        ('firstLearn', 'blindListen', 8),
        ('firstLearn', 'intensiveListen', 8),
        ('firstLearn', 'listenAndRepeat', 7),
        ('firstLearn', 'retell', 7),
        ('review0', 'reviewDifficultPractice', 2),
        ('review0', 'reviewRetellParagraph', 2),
      ],
    // Audio 4: review0 locked（今天刚完成首学）
    3 => [
        ('firstLearn', 'blindListen', 3),
        ('firstLearn', 'intensiveListen', 2),
        ('firstLearn', 'listenAndRepeat', 1),
        ('firstLearn', 'retell', 0), // 今天
      ],
    // Audio 5: firstLearn.retell（已完成盲听/精听/跟读）
    4 => [
        ('firstLearn', 'blindListen', 3),
        ('firstLearn', 'intensiveListen', 2),
        ('firstLearn', 'listenAndRepeat', 1),
      ],
    _ => [],
  };
}

// ---------------------------------------------------------------------------
// 每日学习记录（14 天）
// ---------------------------------------------------------------------------

/// 返回 14 天学习记录，每条为 (daysAgo, inputSeconds, outputSeconds, inputWords, outputWords)
const demoDailyRecords = [
  // 第 1 周（较早）
  (13, 1200, 480, 980, 220),
  (12, 1380, 720, 1120, 330),
  (11, 1620, 900, 1340, 410),
  (10, 1440, 660, 1180, 300),
  (9, 1740, 960, 1430, 440),
  (8, 1560, 840, 1280, 380),
  (7, 1680, 780, 1370, 360),
  // 第 2 周（最近 7 天，对应柱状图）
  (6, 1500, 780, 1230, 360),
  (5, 1800, 960, 1480, 440),
  (4, 1200, 600, 990, 280),
  (3, 2160, 1200, 1770, 550),
  (2, 1560, 840, 1280, 390),
  (1, 1920, 1080, 1570, 500),
  (0, 1680, 1140, 1650, 620), // 今天
];
