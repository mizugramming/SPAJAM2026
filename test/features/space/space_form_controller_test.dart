import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/core/models/category_type.dart';
import 'package:spajam2026/core/models/emotion_type.dart';
import 'package:spajam2026/core/models/space_record.dart';
import 'package:spajam2026/features/space/controllers/space_form_controller.dart';

void main() {
  test(
    'requires selections and retains inputs/ID on failure, clears on success',
    () async {
      final form = SpaceFormController();
      addTearDown(form.dispose);
      form.next();
      form.next();
      expect(form.step, SpaceStep.emotion);
      expect(await form.save((_) async => fail('must not persist')), isNull);
      form.selectEmotion(EmotionType.tired);
      form.next();
      form.next();
      expect(form.step, SpaceStep.category);
      form.selectCategory(CategoryType.workStudy);
      form.next();
      form.setNote('  おつかれさま  ');
      form.next();
      expect(form.step, SpaceStep.review);
      form.next();
      expect(form.step, SpaceStep.review);
      form.back();
      expect(form.step, SpaceStep.note);
      expect(form.note, '  おつかれさま  ');
      form.next();
      SpaceRecord? attempted;
      expect(
        await form.save((r) async {
          attempted = r;
          throw StateError('failed');
        }),
        isNull,
      );
      expect(form.note, '  おつかれさま  ');
      expect(form.emotion, EmotionType.tired);
      expect(form.error, isNotNull);
      final saved = await form.save((_) async {});
      expect(saved!.id, attempted!.id);
      expect(saved.note, 'おつかれさま');
      expect(form.hasInput, false);
      expect(form.step, SpaceStep.complete);
    },
  );
  test('double submission is blocked, empty note is valid', () async {
    final form = SpaceFormController();
    addTearDown(form.dispose);
    form.selectEmotion(EmotionType.uneasy);
    form.selectCategory(CategoryType.self);
    form.next();
    form.next();
    form.next();
    form.next();
    final barrier = Completer<void>();
    var calls = 0;
    final pending = form.save((_) {
      calls++;
      return barrier.future;
    });
    expect(form.saving, true);
    expect(
      await form.save((_) async {
        calls++;
      }),
      isNull,
    );
    barrier.complete();
    final saved = await pending;
    expect(calls, 1);
    expect(saved!.note, '');
    expect(form.saving, false);
  });
}
