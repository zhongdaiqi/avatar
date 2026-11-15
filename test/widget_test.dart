import 'package:flutter_test/flutter_test.dart';

import 'package:avatar/data/presets.dart';
import 'package:avatar/data/recipe_check.dart';

void main() {
  test('60 套内置模板都能构建出完整配方', () {
    expect(presetList.length, 60);
    for (final rec in presetList) {
      expect(rec.id.isNotEmpty, true);
      expect(rec.name.isNotEmpty, true);
      expect(rec.backdrop.stops.length, 2);
      expect(rec.shape.type.isNotEmpty, true);
    }
  });

  test('配方 JSON 往返不丢字段', () {
    for (final rec in presetList) {
      final round = recipeRoundTrip(rec);
      expect(round.id, rec.id);
      expect(round.shape.type, rec.shape.type);
      expect(round.frame.id, rec.frame.id);
      expect(round.pattern.id, rec.pattern.id);
      expect(round.texts.length, rec.texts.length);
      expect(round.stickers.length, rec.stickers.length);
    }
  });
}
