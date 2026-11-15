import 'dart:math' as math;

import '../data/models.dart';
import 'px.dart';

class PhotoMetrics {
  PhotoMetrics({
    required this.k,
    required this.drawW,
    required this.drawH,
    required this.maxOffX,
    required this.maxOffY,
  });

  final double k;
  final double drawW;
  final double drawH;
  final double maxOffX;
  final double maxOffY;
}

/// 计算照片在 1×1 归一化方框内的绘制参数。
/// 结论复用给渲染器和手势，保证"手指拖到哪，导出就是哪"。
PhotoMetrics photoMetrics(PhotoCfg photo, double imgW, double imgH) {
  final rot = photo.rotate;
  final c = math.cos(rad(rot)).abs();
  final s = math.sin(rad(rot)).abs();
  final w = math.max(1.0, imgW);
  final h = math.max(1.0, imgH);

  final kMin = math.max(1 / (w * c + h * s), 1 / (w * s + h * c));
  final scale = math.max(1.0, photo.scale);
  final k = kMin * scale;

  final drawW = w * k;
  final drawH = h * k;
  final bboxW = drawW * c + drawH * s;
  final bboxH = drawW * s + drawH * c;

  return PhotoMetrics(
    k: k,
    drawW: drawW,
    drawH: drawH,
    maxOffX: math.max(0, (bboxW - 1) / 2),
    maxOffY: math.max(0, (bboxH - 1) / 2),
  );
}

void clampPhotoOffset(PhotoCfg photo, PhotoMetrics m) {
  photo.x = clampd(photo.x, -m.maxOffX, m.maxOffX);
  photo.y = clampd(photo.y, -m.maxOffY, m.maxOffY);
}
