import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LearnedShape {
  final String signature;
  final String label;
  final DateTime updatedAt;

  LearnedShape({
    required this.signature,
    required this.label,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'label': label,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static LearnedShape fromJson(Map<String, dynamic> json) {
    return LearnedShape(
      signature: json['signature'] as String,
      label: json['label'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class LearnedSequence {
  final String sequence;
  final String description;
  final DateTime updatedAt;

  LearnedSequence({
    required this.sequence,
    required this.description,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'sequence': sequence,
        'description': description,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static LearnedSequence fromJson(Map<String, dynamic> json) {
    return LearnedSequence(
      sequence: json['sequence'] as String,
      description: json['description'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class LearnedComposite {
  final String signature;
  final String label;
  final int partCount;
  final DateTime updatedAt;

  LearnedComposite({
    required this.signature,
    required this.label,
    required this.partCount,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'label': label,
        'partCount': partCount,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static LearnedComposite fromJson(Map<String, dynamic> json) {
    return LearnedComposite(
      signature: json['signature'] as String,
      label: json['label'] as String,
      partCount: json['partCount'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class LearningSnapshot {
  final Map<String, LearnedShape> shapes;
  final Map<String, LearnedSequence> sequences;
  final Map<String, LearnedComposite> composites;

  LearningSnapshot({
    required this.shapes,
    required this.sequences,
    required this.composites,
  });

  Map<String, dynamic> toJson() => {
        'shapes': shapes.map((k, v) => MapEntry(k, v.toJson())),
        'sequences': sequences.map((k, v) => MapEntry(k, v.toJson())),
        'composites': composites.map((k, v) => MapEntry(k, v.toJson())),
      };

  static LearningSnapshot fromJson(Map<String, dynamic> json) {
    final shapesJson = (json['shapes'] as Map?) ?? {};
    final sequencesJson = (json['sequences'] as Map?) ?? {};
    final compositesJson = (json['composites'] as Map?) ?? {};
    return LearningSnapshot(
      shapes: shapesJson.map(
          (key, value) => MapEntry(key as String, LearnedShape.fromJson(value))),
      sequences: sequencesJson.map((key, value) =>
          MapEntry(key as String, LearnedSequence.fromJson(value))),
      composites: compositesJson.map((key, value) =>
          MapEntry(key as String, LearnedComposite.fromJson(value))),
    );
  }
}

class LearningStore {
  static const _fileName = 'learning_store.json';

  Future<File> _getStoreFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<LearningSnapshot> load() async {
    try {
      final file = await _getStoreFile();
      if (!await file.exists()) {
        return LearningSnapshot(shapes: {}, sequences: {}, composites: {});
      }
      final content = await file.readAsString();
      final jsonMap = jsonDecode(content) as Map<String, dynamic>;
      return LearningSnapshot.fromJson(jsonMap);
    } catch (_) {
      return LearningSnapshot(shapes: {}, sequences: {}, composites: {});
    }
  }

  Future<void> save(LearningSnapshot snapshot) async {
    final file = await _getStoreFile();
    await file.writeAsString(jsonEncode(snapshot.toJson()));
  }

  Future<File?> exportTo(String targetPath, LearningSnapshot snapshot) async {
    final file = File(targetPath);
    await file.writeAsString(jsonEncode(snapshot.toJson()));
    return file;
  }

  Future<LearningSnapshot> importFrom(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      return LearningSnapshot(shapes: {}, sequences: {}, composites: {});
    }
    final content = await file.readAsString();
    final jsonMap = jsonDecode(content) as Map<String, dynamic>;
    return LearningSnapshot.fromJson(jsonMap);
  }
}

class SupabaseSyncStatus {
  final bool hasConfig;
  final bool connected;
  final String? message;

  SupabaseSyncStatus({
    required this.hasConfig,
    required this.connected,
    this.message,
  });
}

class SupabaseSyncService {
  static const _envPath = 'assets/.env';
  bool _initialized = false;
  SupabaseSyncStatus _status =
      SupabaseSyncStatus(hasConfig: false, connected: false);

  SupabaseSyncStatus get status => _status;

  Future<SupabaseSyncStatus> initIfPossible() async {
    if (_initialized) return _status;
    _initialized = true;
    try {
      final envContent = await rootBundle.loadString(_envPath);
      final lines = envContent.split('\n');
      final map = <String, String>{};
      for (final line in lines) {
        final parts = line.split('=');
        if (parts.length >= 2) {
          map[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
      final url = map['SUPABASE_URL'];
      final key = map['SUPABASE_ANON_KEY'];
      if (url == null || key == null || url.isEmpty || key.isEmpty) {
        _status = SupabaseSyncStatus(
          hasConfig: false,
          connected: false,
          message: 'Missing SUPABASE_URL or SUPABASE_ANON_KEY',
        );
        return _status;
      }
      await Supabase.initialize(url: url, anonKey: key);
      _status = SupabaseSyncStatus(hasConfig: true, connected: true);
    } catch (e) {
      _status = SupabaseSyncStatus(
        hasConfig: true,
        connected: false,
        message: e.toString(),
      );
    }
    return _status;
  }

  Future<void> syncSnapshot(LearningSnapshot snapshot) async {
    if (!_status.connected) return;
    // Implement actual Supabase sync if desired. Placeholder to avoid runtime failures.
  }
}
