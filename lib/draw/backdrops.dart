import 'package:flutter/painting.dart';

import '../core/px.dart';
import '../data/models.dart';

/// 背景铺满整块画布。[Backdrop.stops] 为 [(color, offset), ...]
void drawBackdrop(Pc c, double L, Backdrop cfg) {
  final stops = cfg.stops.isEmpty
      ? <(Color, double)>[(const Color(0xFFFFFFFF), 0), (const Color(0xFFFFFFFF), 1)]
      : cfg.stops;

  final full = Rect.fromLTWH(0, 0, L, L);

  switch (cfg.type) {
    case 'linear':
      c.fillRect(full, shader: linearAngle(L, stops, cfg.angle));
      break;

    case 'radial':
      c.fillRect(
        full,
        shader: radialShader(
          Offset(L / 2 + cfg.cx * L, L / 2 + cfg.cy * L),
          L * 0.04,
          Offset(L / 2, L / 2),
          L * 0.75,
          stops,
        ),
      );
      break;

    case 'stripes':
      {
        c.fillRect(full, color: stops[0].$1);
        c.save();
        c.translate(L / 2, L / 2);
        c.rotate(rad(cfg.angle));
        final color = stops.length > 1 ? stops[1].$1 : stops[0].$1;
        final w = L * 0.075;
        final gap = L * 0.075;
        final span = L * 1.6;
        for (var x = -span; x < span; x += w + gap) {
          c.fillRect(Rect.fromLTWH(x, -span, w, span * 2), color: color);
        }
        c.restore();
        break;
      }

    case 'checker':
      {
        c.fillRect(full, color: stops[0].$1);
        final color = stops.length > 1 ? stops[1].$1 : stops[0].$1;
        final n = cfg.cells;
        final cell = L / n;
        for (var y = 0; y < n; y++) {
          for (var x = 0; x < n; x++) {
            if ((x + y) % 2 == 0) {
              c.fillRect(Rect.fromLTWH(x * cell, y * cell, cell, cell),
                  color: color);
            }
          }
        }
        break;
      }

    case 'split':
      {
        c.fillRect(full, color: stops[0].$1);
        final color = stops.length > 1 ? stops[1].$1 : stops[0].$1;
        c.save();
        c.translate(L / 2, L / 2);
        c.rotate(rad(cfg.angle));
        c.fillRect(Rect.fromLTWH(0, -L, L * 2, L * 2), color: color);
        c.restore();
        break;
      }

    default:
      c.fillRect(full, color: stops[0].$1);
      break;
  }
}
