import 'package:flutter_test/flutter_test.dart';
import 'package:vibesight_tracker/services/link_preview_service.dart';

void main() {
  group('parseFirstUrl', () {
    test('returns empty when no URL is present', () {
      final r = parseFirstUrl('просто заметка без ссылок');
      expect(r.isEmpty, true);
      expect(r.url, null);
    });

    test('extracts plain https URL', () {
      final r = parseFirstUrl('посмотри https://example.com/foo!');
      expect(r.url, 'https://example.com/foo');
      expect(r.domain, 'example.com');
      expect(r.platform, 'web');
    });

    test('strips trailing punctuation', () {
      final r = parseFirstUrl('see https://x.com/post.');
      expect(r.url, 'https://x.com/post');
      expect(r.domain, 'x.com');
      expect(r.platform, 'twitter');
    });

    test('strips www. from domain', () {
      final r = parseFirstUrl('https://www.youtube.com/watch?v=abc');
      expect(r.domain, 'youtube.com');
      expect(r.platform, 'youtube');
    });

    test('returns first URL when multiple are present', () {
      final r = parseFirstUrl('https://a.com и https://b.com');
      expect(r.url, 'https://a.com');
    });

    test('handles youtu.be short links', () {
      final r = parseFirstUrl('лови https://youtu.be/dQw4w9WgXcQ');
      expect(r.platform, 'youtube');
    });

    test('handles t.me telegram links', () {
      final r = parseFirstUrl('https://t.me/some_channel/123');
      expect(r.platform, 'telegram');
    });

    test('handles instagram', () {
      final r = parseFirstUrl('https://www.instagram.com/p/abc/');
      expect(r.platform, 'instagram');
    });

    test('handles tiktok subdomains', () {
      final r = parseFirstUrl('https://vm.tiktok.com/ZSabc/');
      expect(r.platform, 'tiktok');
    });
  });

  group('detectPlatform', () {
    test('null/empty -> web', () {
      expect(detectPlatform(null), 'web');
      expect(detectPlatform(''), 'web');
    });

    test('unknown -> web', () {
      expect(detectPlatform('example.com'), 'web');
      expect(detectPlatform('news.ycombinator.com'), 'web');
    });

    test('known platforms', () {
      expect(detectPlatform('youtube.com'), 'youtube');
      expect(detectPlatform('youtu.be'), 'youtube');
      expect(detectPlatform('instagram.com'), 'instagram');
      expect(detectPlatform('vm.tiktok.com'), 'tiktok');
      expect(detectPlatform('twitter.com'), 'twitter');
      expect(detectPlatform('x.com'), 'twitter');
      expect(detectPlatform('threads.net'), 'threads');
      expect(detectPlatform('t.me'), 'telegram');
      expect(detectPlatform('vk.com'), 'vk');
      expect(detectPlatform('reddit.com'), 'reddit');
      expect(detectPlatform('pinterest.com'), 'pinterest');
      expect(detectPlatform('fb.watch'), 'facebook');
      expect(detectPlatform('open.spotify.com'), 'spotify');
      expect(detectPlatform('github.com'), 'github');
    });
  });

  group('extractHashtags', () {
    test('returns empty when no hashtags', () {
      expect(extractHashtags('просто текст'), <String>[]);
    });

    test('extracts unicode hashtags lowercase + dedup', () {
      final out = extractHashtags('купить #Идея #идея и потом #прочитать');
      expect(out, containsAll(['идея', 'прочитать']));
      expect(out.length, 2);
    });

    test('ignores single-char hashtags', () {
      expect(extractHashtags('#a vs #ab'), ['ab']);
    });

    test('extracts latin hashtags', () {
      final out = extractHashtags('#TODO and #idea');
      expect(out, containsAll(['todo', 'idea']));
    });
  });
}
