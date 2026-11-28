import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RemoteWebGame {
  const RemoteWebGame({
    required this.id,
    required this.title,
    required this.genre,
    required this.description,
    required this.url,
    required this.accentHex,
    this.tags = const ['WebView'],
    this.active = true,
  });

  final String id;
  final String title;
  final String genre;
  final String description;
  final String url;
  final String accentHex;
  final List<String> tags;
  final bool active;

  Color get accentColor {
    final cleaned = accentHex.replaceAll('#', '').trim();
    final val = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return Color(val ?? 0xFFC084FC);
  }

  factory RemoteWebGame.fromJson(Map<String, dynamic> j) {
    final rawTags = j['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
        : const <String>['WebView'];
    return RemoteWebGame(
      id: '${j['id'] ?? ''}'.trim(),
      title: '${j['title'] ?? ''}'.trim(),
      genre: '${j['genre'] ?? 'Cloud Arcade'}'.trim(),
      description: '${j['description'] ?? ''}'.trim(),
      url: '${j['url'] ?? ''}'.trim(),
      accentHex: '${j['accent'] ?? '#C084FC'}'.trim(),
      tags: tags.isEmpty ? const ['WebView'] : tags,
      active: j['active'] == null ? true : (j['active'] == true || j['active'] == 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'genre': genre,
        'description': description,
        'url': url,
        'accent': accentHex,
        'tags': tags,
        'active': active,
      };
}

class RemoteGamesService {
  RemoteGamesService._();
  static final RemoteGamesService instance = RemoteGamesService._();

  static const String catalogUrl = 'https://nufat.id/games/catalog.json';
  static const String _cacheKey = 'nufat_remote_games_cache_v1';
  static String _bestKey(String id) => 'nufat_web_best_$id';

  static const List<RemoteWebGame> fallbackGames = [
    RemoteWebGame(
      id: 'neon-stack',
      title: 'NEON STACK',
      genre: 'Precision Tower Arcade',
      description:
          'Tap tepat waktu untuk menumpuk blok neon setinggi mungkin. Perfect combo memperlebar blok & skor berlipat!',
      url: 'https://nufat.id/games/neon-stack/',
      accentHex: '#C084FC',
      tags: ['WebView', '1-Tap', 'Combo'],
    ),
  ];

  static List<RemoteWebGame> parseCatalog(String rawJson) {
    final decoded = jsonDecode(rawJson);
    final list = decoded is Map && decoded['games'] is List
        ? decoded['games'] as List
        : (decoded is List ? decoded : const []);
    return list
        .whereType<Map>()
        .map((m) => RemoteWebGame.fromJson(Map<String, dynamic>.from(m)))
        .where((g) => g.active && g.id.isNotEmpty && g.url.startsWith('https://'))
        .toList();
  }

  Future<({List<RemoteWebGame> games, bool fromServer})> fetchCatalog() async {
    try {
      final res = await http
          .get(Uri.parse(catalogUrl), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final parsed = parseCatalog(res.body);
        if (parsed.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            _cacheKey,
            jsonEncode({'games': parsed.map((e) => e.toJson()).toList()}),
          );
          return (games: parsed, fromServer: true);
        }
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final parsed = parseCatalog(cached);
        if (parsed.isNotEmpty) return (games: parsed, fromServer: false);
      }
    } catch (_) {}

    return (games: fallbackGames, fromServer: false);
  }

  Future<Map<String, int>> loadWebBestScores(List<RemoteWebGame> games) async {
    final out = <String, int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final g in games) {
        out[g.id] = prefs.getInt(_bestKey(g.id)) ?? 0;
      }
    } catch (_) {}
    return out;
  }

  Future<void> recordWebScore(String gameId, int score) async {
    if (gameId.isEmpty || score <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cur = prefs.getInt(_bestKey(gameId)) ?? 0;
      if (score > cur) {
        await prefs.setInt(_bestKey(gameId), score);
      }
    } catch (_) {}
  }
}
