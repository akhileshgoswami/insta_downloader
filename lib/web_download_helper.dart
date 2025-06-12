// web_download_helper.dart
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadFileWeb(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes], 'video/mp4');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "$fileName.mp4")
    ..style.display = "none";

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  html.Url.revokeObjectUrl(url);
}
