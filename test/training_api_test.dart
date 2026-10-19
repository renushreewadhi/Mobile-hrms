import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_demo/services/api_client.dart';

void main() {
  group('ApiClient unwrap tests', () {
    test('unwraps data field from API response envelope', () {
      final responseMap = {
        'success': true,
        'message': 'Courses retrieved successfully',
        'data': [
          {'id': '1', 'title': 'ASP.NET Core 8 & Web API Mastery'},
        ],
      };

      final unwrapped = ApiClient.unwrap(responseMap);
      expect(unwrapped, isA<List>());
      expect((unwrapped as List).length, equals(1));
      expect(unwrapped.first['title'], equals('ASP.NET Core 8 & Web API Mastery'));
    });

    test('returns raw object when data key is missing', () {
      final rawList = [
        {'id': '1', 'title': 'Angular Microfrontends'},
      ];

      final unwrapped = ApiClient.unwrap(rawList);
      expect(unwrapped, equals(rawList));
    });
  });

  group('YouTube URL extraction tests', () {
    String extractEmbedUrl(String rawUrl) {
      final url = rawUrl.trim();
      final ytMatch = RegExp(
        r'(?:youtube\.com/(?:[^/]+/.+/|(?:v|e(?:mbed)?)/|.*[?&]v=)|youtu\.be/)([^"&?/\s]{11})',
        caseSensitive: false,
      ).firstMatch(url);

      if (ytMatch != null && ytMatch.groupCount >= 1) {
        final videoId = ytMatch.group(1);
        return 'https://www.youtube.com/embed/$videoId?autoplay=1&playsinline=1&enablejsapi=1';
      }
      return url;
    }

    test('converts standard YouTube watch link to embed URL', () {
      const watchUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final embedUrl = extractEmbedUrl(watchUrl);
      expect(embedUrl, equals('https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&playsinline=1&enablejsapi=1'));
    });

    test('converts short YouTube youtu.be link to embed URL', () {
      const shortUrl = 'https://youtu.be/dQw4w9WgXcQ';
      final embedUrl = extractEmbedUrl(shortUrl);
      expect(embedUrl, equals('https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&playsinline=1&enablejsapi=1'));
    });
  });
}
