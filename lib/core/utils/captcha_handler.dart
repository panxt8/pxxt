import 'dart:typed_data';
import 'package:image/image.dart' as img;

int calculateDistance(Uint8List bgBytes, Uint8List sliderBytes) {
  final bg = img.decodeImage(bgBytes);
  final slider = img.decodeImage(sliderBytes);

  if (bg == null || slider == null) {
    throw Exception("图片解码失败");
  }

  int bestX = 0;
  double minDifference = double.infinity;

  final maxSlideX = bg.width - slider.width;

  for (int x = 0; x <= maxSlideX; x++) {
    double currentDifference = 0;

    for (int y = 0; y < slider.height; y++) {
      for (int tx = 0; tx < slider.width; tx++) {
        final sliderPixel = slider.getPixel(tx, y);

        // 如果滑块像素完全透明，跳过
        if (sliderPixel.a == 0) continue;

        final bgPixel = bg.getPixel(x + tx, y);

        // 计算 RGB 差值和
        final diff = (sliderPixel.r - bgPixel.r).abs() +
            (sliderPixel.g - bgPixel.g).abs() +
            (sliderPixel.b - bgPixel.b).abs();

        currentDifference += diff;
      }
    }

    if (currentDifference < minDifference) {
      minDifference = currentDifference;
      bestX = x;
    }
  }

  return bestX;
}