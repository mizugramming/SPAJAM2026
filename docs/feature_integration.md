# 画面担当向け：共通変数と画面のつなぎ方

現在の画面は動作確認用の仮UIです。見た目・ボタン配置・アニメーションは担当ごとに変更できます。以下のモデル、Provider、ルートを共通の接続口として使うことで、画面同士を直接importせずに開発できます。

## 共通の記録データ

`lib/core/models/space_record.dart` の `SpaceRecord` を全画面で使用します。

| 変数 | 型 | 意味 |
|---|---|---|
| `id` | `String` | UUID。再試行時は同じIDを使う |
| `createdAt` | `DateTime` | 記録日時。表示・日別抽出は端末のローカル日付 |
| `emotion` | `EmotionType` | `joyful`, `calm`, `neutral`, `tired`, `uneasy` |
| `category` | `CategoryType` | `challenge`, `relationships`, `future`, `workStudy`, `self`, `dailyLife` |
| `note` | `String` | 任意メモ。前後の空白除去、200文字以内 |

感情・テーマには `.id`, `.label`, `.color`, `.icon`、テーマには `.hint` があります。保存に使うIDは変更しないでください。表示色やラベルの共通変更はAに集約します。

## 全画面で同じ記録を読む

`ConsumerWidget` または `ConsumerStatefulWidget` から以下を利用します。

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spajam2026/core/providers/space_records_provider.dart';

final recordsAsync = ref.watch(spaceRecordsProvider);
final today = ref.watch(todayProvider);

return recordsAsync.when(
  loading: () => const CircularProgressIndicator(),
  error: (_, _) => const ErrorState(),
  data: (records) => YourWidget(records: records),
);
```

`YourWidget` は担当画面のUIに置き換えます。`ErrorState` は `core/widgets/error_state.dart` にあります。`AsyncValue<List<SpaceRecord>>` の読み込み中・失敗・成功を分けて表示してください。`todayProvider` は日付変更とアプリ復帰時に更新されます。

`records` は読み取り専用です。画面ごとの独立した記録リストを保存したり、RepositoryやSharedPreferencesを画面で直接生成したりせず、次のメソッドを利用します。

## 記録を追加・削除する

```dart
await ref.read(spaceRecordsProvider.notifier).save(record);
await ref.read(spaceRecordsProvider.notifier).deleteById(record.id);
```

保存・削除は `Future<void>` を返し、失敗時には例外を返します。成功すると永続化とProviderの更新が済んでいるため、別画面の更新処理は不要です。保存中はボタンの連打を防ぎ、失敗時には入力を残して再試行できるようにします。

SPACE担当は `features/space/controllers/space_form_controller.dart` をそのまま利用できます。

- `step`：`pause / emotion / category / note / complete`
- `emotion`, `category`, `note`：入力値
- `selectEmotion(value)`, `selectCategory(value)`, `setNote(value)`：入力更新
- `next()`, `back()`：ステップ移動
- `saving`, `error`, `canSave`, `hasInput`：保存中・エラー・入力状態
- `await form.save(ref.read(spaceRecordsProvider.notifier).save)`：成功時は保存した `SpaceRecord`、失敗時は `null`

コントローラーは画面で生成して `dispose()` し、`ListenableBuilder` でUIを更新します。失敗時の入力保持、連打防止、再試行時のID維持、成功時の入力リセットはコントローラー内にあります。戻る・閉じるときの入力破棄確認は現在の `SpacePage` を参照してください。

削除はユーザー確認後に呼び出してください。共通の詳細シート `showRecordDetail(context, record)` には確認ダイアログ・削除・失敗時の再試行が実装済みです。

## 各画面で使う派生データ

`core/utils/record_queries.dart` と `core/utils/date_key.dart` に共通処理があります。

```dart
final stars = recordsOnDay(records, selectedDate); // 時刻昇順
final counts = categoryCounts(records); // Map<CategoryType, int>
final stage = planetStage(counts[CategoryType.challenge]!); // 0〜3
final key = dateKey(selectedDate); // YYYY-MM-DD
```

| 画面 | 入力・共有状態 | 画面内だけに持つ状態 |
|---|---|---|
| ホーム | `spaceRecordsProvider`, `todayProvider` | プレビューの見た目 |
| SPACE | 保存先は同じProvider | `SpaceFormController` の入力とステップ |
| 今日の星座 | `ConstellationPage(date: ...)` と全記録 | 描画・表示の状態 |
| 宇宙 | 全記録からテーマ別に集計 | 開いている惑星・シート |
| 振り返り | 全記録から日付別に抽出 | 選択日 `_selected`、表示月 `_focused` |

星座・惑星・カレンダーは別々に保存しません。全記録から計算するため、削除はすべての画面へ自動反映されます。テーマ別一覧にも同じProviderを使います。

## 画面遷移と日付の受け渡し

`core/constants/app_routes.dart` の `AppRoutes` と `go_router` を利用します。

```dart
import 'package:go_router/go_router.dart';
import 'package:spajam2026/core/constants/app_routes.dart';

context.push(AppRoutes.space); // 全画面の入力フロー
context.go(AppRoutes.constellationOn(selectedDate)); // 日付を渡す
context.go(AppRoutes.universe);
context.go(AppRoutes.history);
context.go(AppRoutes.home);
```

保存後は、保存結果の `record.createdAt` を `constellationOn` に渡します。深夜に日付が変わっても、実際に記録した日の星座を開けます。保存しないで閉じる場合は、戻れるなら `context.pop()`、直接 `/space` を開いていた場合はホームへ移動します。

`/constellation` に日付がなければ今日を表示します。日付は `?date=YYYY-MM-DD` で渡し、ルーターが `DateTime?` に変換します。

## 変更する場所

- A：`app/`, `core/`, `main.dart`, `pubspec.yaml`, `features/home/`
- B：`features/space/` と対応する素材・テスト
- C：`features/constellation/` と対応する素材・テスト
- D：`features/universe/`, `features/history/` と対応する素材・テスト

画面のUIを変更するときも、他Featureのファイルをimportする必要はありません。モデル・Provider・ルートの変更は共通基盤担当に集約してください。プレビュー画像や仮UIに合わせる必要はありません。

接続の確認は `flutter analyze` と `flutter test` で行えます。特に `test/widget_test.dart` が、記録 → 星座 → 再読み込み → 惑星 → カレンダー → 削除を通して検証しています。文言やボタンを変更した場合は、対応する画面操作テストのFinderも更新してください。
