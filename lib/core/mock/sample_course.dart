import '../models/course.dart';

/// モック用の仮コース。実際の固定コース（案内図・撮影対象・QR）は未確定。
const sampleCourse = Course(
  id: 'sample',
  name: 'サンプルコース（仮）',
  startQr: 'MQ-START-sample',
  goalQr: 'MQ-GOAL-sample',
  timeLimit: Duration(minutes: 30),
  checkpoints: [
    Checkpoint(
      id: 'cp-a',
      name: 'チェックポイントA（仮）',
      floor: '1F',
      qr: 'MQ-CP-sample-a',
      mission: '案内板を撮影する',
      points: 10,
      required: true,
    ),
    Checkpoint(
      id: 'cp-b',
      name: 'チェックポイントB（仮）',
      floor: '2F',
      qr: 'MQ-CP-sample-b',
      mission: '階段の踊り場の窓を撮影する',
      points: 10,
      required: true,
    ),
    Checkpoint(
      id: 'cp-free-1',
      name: '自由ミッション1（仮）',
      floor: '1F',
      qr: 'MQ-CP-sample-free-1',
      mission: '赤いものを撮影する',
      points: 5,
      required: false,
    ),
  ],
);
