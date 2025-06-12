import 'dart:convert';
import 'package:http/http.dart' as http;

/// Extract Instagram Reel video URL (2025-safe)
Future<String?> extractInstagramVideoUrl(String url) async {
  try {
    if (!url.endsWith('/')) url += '/';

    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
      'Accept-Language': 'en-US,en;q=0.5',
      'Referer': 'https://www.google.com/',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    });

    if (response.statusCode != 200) {
      print('HTTP error: ${response.statusCode}');
      return null;
    }

    final html = response.body;

    // Try finding the JSON containing video_url
    final jsonPattern = RegExp(r'{"props":{.*"video_url":"(https:[^"]+\.mp4)".*}}}');
    final match = jsonPattern.firstMatch(html);

    if (match != null) {
      final videoUrl = match.group(1)?.replaceAll(r'\/', '/');
      print('Video URL: $videoUrl');
      return videoUrl;
    }

    // As fallback, check __NEXT_DATA__ script
    final nextDataStart = html.indexOf('<script type="application/json" id="__NEXT_DATA__">');
    if (nextDataStart == -1) {
      print('Could not find __NEXT_DATA__ script.');
      return null;
    }

    final nextDataEnd = html.indexOf('</script>', nextDataStart);
    final jsonString = html.substring(
      nextDataStart + '<script type="application/json" id="__NEXT_DATA__">'.length,
      nextDataEnd,
    );

    final data = json.decode(jsonString);
    final media = data['props']?['pageProps']?['postPage']?['graphql']?['shortcode_media'];
    final videoUrl = media?['video_url'];

    print('Parsed video URL: $videoUrl');
    return videoUrl;
  } catch (e) {
    print('Error extracting video URL: $e');
    return null;
  }
}
