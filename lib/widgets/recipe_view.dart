import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/renderer.dart';
import '../data/models.dart';

/// 全局色板：干净白底 + 珊瑚红强调色
class AppColors {
  static const coral = Color(0xFFFF6B6B);
  static const ink = Color(0xFF1A1A1A);
  static const grey = Color(0xFF8A8A8E);
  static const line = Color(0xFFEEEEF0);
  static const soft = Color(0xFFF7F7F8);
}

/// 任意尺寸渲染一份配方（缩略图 / 编辑画布 / 导出共用）
class RecipePainter extends CustomPainter {
  RecipePainter({
    required this.recipe,
    this.photo,
    this.placeholder = 0,
    this.mask = 'square',
    this.guides = false,
    this.maskImg,
    this.overlayImg,
  });

  final Recipe recipe;
  final ui.Image? photo;
  final int placeholder;
  final String mask;
  final bool guides;
  final ui.Image? maskImg;
  final ui.Image? overlayImg;

  @override
  void paint(Canvas canvas, Size size) {
    renderRecipe(
      canvas,
      size.width,
      recipe,
      RenderOpts(
        photo: photo,
        placeholder: placeholder,
        mask: mask,
        guides: guides,
        maskImg: maskImg,
        overlayImg: overlayImg,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant RecipePainter old) => true;
}

/// 素材格子：边框 / 纹样 / 形状 / 贴纸
class SwatchPainter extends CustomPainter {
  SwatchPainter({
    required this.kind,
    required this.id,
    this.color = AppColors.coral,
    this.bg = const Color(0xFF3A3A44),
  });

  final String kind;
  final String id;
  final Color color;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    renderSwatch(canvas, size.width, kind: kind, id: id, color: color, bg: bg);
  }

  @override
  bool shouldRepaint(covariant SwatchPainter old) => true;
}
