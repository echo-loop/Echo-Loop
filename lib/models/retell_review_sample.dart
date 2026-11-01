/// 复述 AI 评估的调试假数据。
///
/// 用途：不访问 AI 端点也能把结果弹窗的各种情况一次看全（五种要点状态、五种纠错
/// 类别、缺失字段、超长文本、流式半成品条目）。
///
/// 开关是本文件里的 [retellReviewSampleEnabled]：改成 true，热重启（R）即可生效，
/// 复述页点「AI 评估」直接用本文件的数据填充弹窗，不发请求。用完记得改回 false。
library;

import 'retell_review_evaluation.dart';

/// 是否用假数据替代真实评估请求。
///
/// 默认 false；本地调试界面时手动改成 true。测试也可临时改写它来覆盖两条分支，
/// 记得在 tearDown 里改回来。
bool retellReviewSampleEnabled = false;

/// 覆盖各种展示情况的完整评估结果。
///
/// 刻意包含的边界：`missed` 没有转录摘录、`added` 没有原文摘录、`covered` 没有
/// 反馈、一条状态尚未到达的流式半成品、超出一行的长文本。
RetellReviewEvaluation
retellReviewSampleEvaluation() => const RetellReviewEvaluation(
  transcript:
      'Many cities have turned empty lots into community gardens, and '
      'neighbours grow vegetables together there, so people who live on '
      'the same street finally get to know each other.',
  summary:
      '你把「空地改成社区花园」和「邻居因此熟识」这两条主线说清楚了，'
      '但漏掉了原文给出的花园数量增长，结尾的因果关系说反了一处。',
  rating: RetellReviewRating.good,
  keyPoints: [
    // covered：原文、转录都有，判定无需额外说明。
    RetellReviewKeyPoint(
      keyPoint: '很多城市把闲置空地改造成了社区花园。',
      original: 'cities have turned empty lots into community gardens',
      transcript: 'many cities have turned empty lots into community gardens',
      status: RetellReviewKeyPointStatus.covered,
      feedback: '',
    ),
    // partial：说到了但不完整，带反馈。
    RetellReviewKeyPoint(
      keyPoint: '居民在花园里合种蔬菜，日常照料轮流分担。',
      original:
          'residents grow vegetables together and take turns with the '
          'daily watering',
      transcript: 'neighbours grow vegetables together there',
      status: RetellReviewKeyPointStatus.partial,
      feedback: '只说了一起种菜，没有点出日常照料是轮流分担的。',
    ),
    // missed：完全没说，转录侧为空，整行略去。
    RetellReviewKeyPoint(
      keyPoint: '过去五年里这类花园的数量翻了一倍。',
      original: 'the number of such gardens has doubled in the past five years',
      transcript: '',
      status: RetellReviewKeyPointStatus.missed,
      feedback: '原文给了具体的时间跨度和倍数，这条完全没有提到。',
    ),
    // distorted：说了但因果关系反了。
    RetellReviewKeyPoint(
      keyPoint: '一起劳动让同一条街的居民彼此熟悉起来。',
      original:
          'working side by side is what makes neighbours get to know each '
          'other',
      transcript: 'people know each other so they start to work in the garden',
      status: RetellReviewKeyPointStatus.distorted,
      feedback: '因果说反了：是一起劳动带来熟识，不是先熟识才去花园。',
    ),
    // added：原文没有这层意思，原文摘录侧整行不出现。
    RetellReviewKeyPoint(
      keyPoint: '市政府应该出钱给每个街区都建一个花园。',
      original: '',
      transcript: 'the government should pay for a garden in every district',
      status: RetellReviewKeyPointStatus.added,
      feedback: '这是你自己的主张，原文没有提出任何拨款建议。',
    ),
    // 流式半成品：文本先到、状态未到，图标是中性省略号。
    RetellReviewKeyPoint(
      keyPoint: '花园同时改变了街区的绿化面貌。',
      original: 'the gardens also changed how the street looks',
      transcript: 'the street looks greener now',
      status: null,
      feedback: '',
    ),
  ],
  corrections: [
    RetellReviewCorrection(
      type: RetellReviewCorrectionType.grammar,
      transcript: 'the neighbours was working in the garden',
      correction: 'the neighbours were working in the garden',
      explanation: 'neighbours 是复数，be 动词用 were。',
    ),
    RetellReviewCorrection(
      type: RetellReviewCorrectionType.wordChoice,
      transcript: 'open the tap to water the plants',
      correction: 'turn on the tap to water the plants',
      explanation: '英语里开水龙头用 turn on，open 用于门窗、书本这类物体。',
    ),
    RetellReviewCorrection(
      type: RetellReviewCorrectionType.redundancy,
      transcript: 'in my own personal opinion',
      correction: 'in my opinion',
      explanation: 'own 和 personal 与 my 重复，去掉更利落。',
    ),
    RetellReviewCorrection(
      type: RetellReviewCorrectionType.phrasing,
      transcript: 'the empty lot was very not useful',
      correction: 'the empty lot was of little use',
      explanation: 'very not useful 不是自然说法，口语里用 of little use 更贴切。',
    ),
    RetellReviewCorrection(
      type: RetellReviewCorrectionType.cohesion,
      transcript: 'people grow vegetables. they meet every weekend.',
      correction:
          'people grow vegetables, so they end up meeting every weekend.',
      explanation: '两句之间有因果关系，用 so 连起来听感更连贯。',
    ),
  ],
  suggestion:
      '复述前先用三个关键词记住原文的主线（空地 → 共种 → 熟识），'
      '按这条线讲能显著减少漏点和顺序错乱。',
);
