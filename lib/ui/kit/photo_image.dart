import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'transitions.dart';

import '../../theme/theme.dart';

/// 饮食照片：本地私有目录里的 JPEG（路径来自记录的 photo_ids），或刚选好还没保存的内存字节。
class PhotoImage extends StatelessWidget {
  const PhotoImage({
    super.key,
    this.path,
    this.bytes,
    this.width,
    this.height,
    this.radius = 0,
  });

  final String? path;
  final Uint8List? bytes;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width == null ? null : (width! * ratio).round();
    Widget fallback() => ColoredBox(color: p.fill);
    Widget image;
    if (bytes != null) {
      image = Image.memory(
        bytes!,
        width: width,
        height: height,
        frameBuilder: revealImageFrame,
        fit: BoxFit.cover,
        cacheWidth: cacheW,
        gaplessPlayback: true,
      );
    } else if (path != null && path!.isNotEmpty) {
      image = Image.file(
        File(path!),
        width: width,
        height: height,
        frameBuilder: revealImageFrame,
        fit: BoxFit.cover,
        cacheWidth: cacheW,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback(),
      );
    } else {
      image = fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(color: p.fill, child: image),
      ),
    );
  }
}
