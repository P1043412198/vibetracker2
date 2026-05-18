import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of [parseFirstUrl] — either an empty struct (no URL detected) or
/// the URL plus its bare domain and the social platform we recognize it as.
class ParsedUrl {
  ParsedUrl({this.url, this.domain, this.platform});
  final String? url;
  final String? domain;
  final String? platform;

  bool get isEmpty => url == null;
  bool get isNotEmpty => !isEmpty;
}

/// Quick & permissive URL detector. Picks the **first** http(s) URL inside
/// [text] and returns it together with the bare domain (no `www.`) and a
/// short platform key.
///
/// The intent is "good enough to drive a chat preview" — not a strict RFC
/// 3986 parser. We strip a trailing punctuation chunk that is commonly
/// glued to URLs in Telegram / Twitter shares (".,!?;:)]>"), but otherwise
/// preserve the URL as-is.
ParsedUrl parseFirstUrl(String text) {
  final match = RegExp(
    r'https?:\/\/[^\s<>"\u0027\)\]\}]+',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return ParsedUrl();
  var url = match.group(0)!;
  // Drop trailing punctuation that almost never belongs to the URL itself.
  while (url.isNotEmpty && '.,!?;:)]>'.contains(url[url.length - 1])) {
    url = url.substring(0, url.length - 1);
  }
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) return ParsedUrl();
  final host = uri.host.toLowerCase();
  final domain = host.startsWith('www.') ? host.substring(4) : host;
  return ParsedUrl(
    url: url,
    domain: domain,
    platform: detectPlatform(domain),
  );
}

/// Map a bare host (already lower-cased, no `www.`) to a short platform
/// key the UI can colour-code. Falls back to `'web'` for everything else.
///
/// Adding a new key here is the only change required to surface a new
/// platform chip in the chat — the bubble widget reads from this same key
/// space.
String detectPlatform(String? domain) {
  if (domain == null || domain.isEmpty) return 'web';
  if (domain == 'youtube.com' ||
      domain == 'm.youtube.com' ||
      domain == 'music.youtube.com' ||
      domain == 'youtu.be') {
    return 'youtube';
  }
  if (domain == 'instagram.com' || domain == 'instagr.am') {
    return 'instagram';
  }
  if (domain == 'tiktok.com' || domain.endsWith('.tiktok.com')) {
    return 'tiktok';
  }
  if (domain == 'twitter.com' ||
      domain == 'mobile.twitter.com' ||
      domain == 'x.com') {
    return 'twitter';
  }
  if (domain == 'threads.net') return 'threads';
  if (domain == 't.me' || domain == 'telegram.me' || domain == 'telegram.org') {
    return 'telegram';
  }
  if (domain == 'vk.com' || domain == 'm.vk.com' || domain == 'vk.ru') {
    return 'vk';
  }
  if (domain == 'reddit.com' || domain.endsWith('.reddit.com')) {
    return 'reddit';
  }
  if (domain == 'pinterest.com' || domain.endsWith('.pinterest.com')) {
    return 'pinterest';
  }
  if (domain == 'facebook.com' ||
      domain == 'm.facebook.com' ||
      domain == 'fb.com' ||
      domain == 'fb.watch') {
    return 'facebook';
  }
  if (domain == 'spotify.com' || domain.endsWith('.spotify.com')) {
    return 'spotify';
  }
  if (domain == 'github.com' || domain == 'gist.github.com') {
    return 'github';
  }
  return 'web';
}

/// Pull `#тэг`-style hashtags out of [text]. The result is lower-cased and
/// deduplicated, with leading `#` stripped — exactly what we want to store
/// in [InboxItem.tags] and to show as filter chips.
List<String> extractHashtags(String text) {
  final out = <String>{};
  for (final m in RegExp(r'#([\p{L}\p{N}_]{2,})', unicode: true)
      .allMatches(text)) {
    out.add(m.group(1)!.toLowerCase());
  }
  return out.toList();
}

/// Fetched metadata for a URL. We keep it deliberately small so we can
/// store it inline on every [InboxItem] without bloating Hive.
class LinkPreview {
  LinkPreview({this.title, this.imageUrl});
  final String? title;
  final String? imageUrl;

  bool get isEmpty => title == null && imageUrl == null;
}

/// Fire a short HTTP GET against [url] and try to extract `og:title` /
/// `og:image` (falling back to `<title>` if no Open Graph tags exist).
///
/// Network errors, non-2xx responses and parse failures all return an
/// empty [LinkPreview] — the caller should treat preview as best-effort
/// and fall back to a domain-only chip.
///
/// [timeout] caps how long we wait — keep it short so the chat composer
/// stays responsive even on flaky mobile connections. The default 6 s is
/// enough for og-tag pages but still snappy.
///
/// [client] is overridable for tests.
Future<LinkPreview> fetchLinkPreview(
  String url, {
  Duration timeout = const Duration(seconds: 6),
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  final ownsClient = client == null;
  try {
    final resp = await c
        .get(
          Uri.parse(url),
          headers: const {
            // Some sites (Instagram, Twitter, TikTok) refuse to serve OG
            // tags to non-browser UAs. A bog-standard desktop UA gets us
            // a usable response from most of them.
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.5',
          },
        )
        .timeout(timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 400) {
      return LinkPreview();
    }
    final body = _decode(resp);
    return _extract(body, baseUrl: url);
  } catch (_) {
    return LinkPreview();
  } finally {
    if (ownsClient) c.close();
  }
}

/// Best-effort body decoder — most pages we fetch will be UTF-8 but we
/// fall back to latin-1 (which is lossless byte → string) when bytes are
/// unrecognized. We never want a decode error to nuke the preview.
String _decode(http.Response resp) {
  try {
    return utf8.decode(resp.bodyBytes, allowMalformed: true);
  } catch (_) {
    return latin1.decode(resp.bodyBytes, allowInvalid: true);
  }
}

LinkPreview _extract(String html, {required String baseUrl}) {
  String? title = _firstMeta(html, property: 'og:title') ??
      _firstMeta(html, name: 'twitter:title') ??
      _firstTag(html, tag: 'title');
  if (title != null) {
    title = _decodeEntities(title.trim());
    if (title.isEmpty) title = null;
  }

  String? image = _firstMeta(html, property: 'og:image') ??
      _firstMeta(html, property: 'og:image:url') ??
      _firstMeta(html, name: 'twitter:image') ??
      _firstMeta(html, name: 'twitter:image:src');
  if (image != null) {
    image = image.trim();
    if (image.startsWith('//')) {
      image = '${Uri.parse(baseUrl).scheme}:$image';
    } else if (image.startsWith('/')) {
      final base = Uri.parse(baseUrl);
      image = '${base.scheme}://${base.host}$image';
    }
    if (image.isEmpty) image = null;
  }
  return LinkPreview(title: title, imageUrl: image);
}

String? _firstMeta(String html, {String? property, String? name}) {
  // Match <meta property="og:title" content="..."> in any attribute order.
  final attr = property != null ? 'property' : 'name';
  final value = property ?? name!;
  final pattern = RegExp(
    r'<meta\s+[^>]*' +
        attr +
        r'\s*=\s*["' +
        r"'" +
        r']' +
        RegExp.escape(value) +
        r'["' +
        r"'" +
        r'][^>]*>',
    caseSensitive: false,
  );
  for (final m in pattern.allMatches(html)) {
    final tag = m.group(0)!;
    final content = RegExp(
      r'content\s*=\s*["' r"'" r']([^"' r"'" r']*)["' r"'" r']',
      caseSensitive: false,
    ).firstMatch(tag);
    if (content != null) return content.group(1);
  }
  return null;
}

String? _firstTag(String html, {required String tag}) {
  final m = RegExp(
    '<$tag[^>]*>([^<]*)</$tag>',
    caseSensitive: false,
  ).firstMatch(html);
  return m?.group(1);
}

/// Tiny entity decoder — covers the handful of named entities OG titles
/// commonly use (`&amp;`, `&quot;`, `&#39;`, …) plus numeric refs. We
/// don't pull in a full HTML parser just for this.
String _decodeEntities(String s) {
  var out = s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1)!);
    if (code == null) return m.group(0)!;
    return String.fromCharCode(code);
  });
  out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1)!, radix: 16);
    if (code == null) return m.group(0)!;
    return String.fromCharCode(code);
  });
  return out;
}
