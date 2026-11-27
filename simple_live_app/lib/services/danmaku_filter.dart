import 'package:simple_live_app/app/utils.dart';

enum DanmakuFilterAction {
  allow,
  blockKeyword,
  blockUser,
  suppressDuplicate,
  foldDuplicate,
}

class DanmakuFilterDecision {
  const DanmakuFilterDecision({
    required this.action,
    this.displayMessage,
    this.duplicateCount = 1,
    this.matchedRule,
  });

  final DanmakuFilterAction action;
  final String? displayMessage;
  final int duplicateCount;
  final String? matchedRule;

  bool get shouldDisplay =>
      action == DanmakuFilterAction.allow ||
      action == DanmakuFilterAction.foldDuplicate;
}

class _CompiledRule {
  _CompiledRule(this.raw, this.pattern);
  final String raw;
  final Pattern pattern;
}

class _DuplicateBucket {
  _DuplicateBucket(this.firstSeen, this.lastSeen, this.count);
  DateTime firstSeen;
  DateTime lastSeen;
  int count;
}

/// Evaluates keyword/regex shields, blocked senders, and sliding-window spam
/// deduplication with cached compiled regexes.
class DanmakuFilter {
  DanmakuFilter({
    DateTime Function()? now,
    this.foldMilestones = const {5, 15, 30, 50, 100},
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Set<int> foldMilestones;

  List<String> _cachedRuleKeys = const [];
  List<_CompiledRule> _compiledRules = const [];
  final Map<String, _DuplicateBucket> _recentMessages = {};

  /// Validates user-supplied keyword or `/regex/` rule before persisting.
  /// Returns an error message when invalid, or null when valid.
  static String? validateRule(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '请输入关键词或正则表达式';
    if (trimmed == '//' || trimmed == '//i') return '正则表达式内容不能为空';
    if (isRegexRule(trimmed)) {
      final parsed = _parseRegex(trimmed);
      if (parsed == null) return '正则表达式格式错误';
    }
    return null;
  }

  /// Supports `/pattern/` and `/pattern/i` syntax.
  static bool isRegexRule(String raw) {
    if (raw.length < 3 || !raw.startsWith('/')) return false;
    if (raw.endsWith('/')) return true;
    if (raw.length >= 4 && raw.endsWith('/i')) return true;
    return false;
  }

  static RegExp? _parseRegex(String raw) {
    var caseSensitive = true;
    String body;
    if (raw.endsWith('/i') && raw.length >= 4) {
      caseSensitive = false;
      body = raw.substring(1, raw.length - 2);
    } else if (raw.endsWith('/') && raw.length >= 3) {
      body = raw.substring(1, raw.length - 1);
    } else {
      return null;
    }
    if (body.isEmpty) return null;
    try {
      return RegExp(body, caseSensitive: caseSensitive);
    } catch (_) {
      return null;
    }
  }

  void resetDeduplication() {
    _recentMessages.clear();
  }

  void _syncCompiledRules(Iterable<String> rules) {
    final nextKeys = rules.toList(growable: false);
    if (_sameList(_cachedRuleKeys, nextKeys)) return;
    _cachedRuleKeys = nextKeys;
    final compiled = <_CompiledRule>[];
    for (final raw in nextKeys) {
      if (raw.isEmpty) continue;
      if (isRegexRule(raw) || Utils.isRegexFormat(raw)) {
        final regex = _parseRegex(raw);
        if (regex != null) {
          compiled.add(_CompiledRule(raw, regex));
        }
      } else {
        compiled.add(_CompiledRule(raw, raw));
      }
    }
    _compiledRules = compiled;
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String normalizeMessage(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static String normalizeUser(String userName) {
    return userName.trim().toLowerCase();
  }

  DanmakuFilterDecision evaluate({
    required String message,
    required String userName,
    required Iterable<String> keywordRules,
    required Iterable<String> blockedUsers,
    bool isSelf = false,
    bool mergeDuplicate = true,
    int mergeWindowSeconds = 5,
  }) {
    if (isSelf) {
      return DanmakuFilterDecision(
        action: DanmakuFilterAction.allow,
        displayMessage: message,
      );
    }

    final normalizedUser = normalizeUser(userName);
    if (normalizedUser.isNotEmpty) {
      for (final blocked in blockedUsers) {
        if (normalizeUser(blocked) == normalizedUser) {
          return DanmakuFilterDecision(
            action: DanmakuFilterAction.blockUser,
            matchedRule: blocked,
          );
        }
      }
    }

    _syncCompiledRules(keywordRules);
    for (final rule in _compiledRules) {
      if (message.contains(rule.pattern)) {
        return DanmakuFilterDecision(
          action: DanmakuFilterAction.blockKeyword,
          matchedRule: rule.raw,
        );
      }
    }

    if (!mergeDuplicate || mergeWindowSeconds <= 0) {
      return DanmakuFilterDecision(
        action: DanmakuFilterAction.allow,
        displayMessage: message,
      );
    }

    final normalized = normalizeMessage(message);
    if (normalized.isEmpty) {
      return DanmakuFilterDecision(
        action: DanmakuFilterAction.allow,
        displayMessage: message,
      );
    }

    final now = _now();
    final window = Duration(seconds: mergeWindowSeconds);
    _pruneExpired(now, window);

    final bucket = _recentMessages[normalized];
    if (bucket == null || now.difference(bucket.firstSeen) >= window) {
      _recentMessages[normalized] = _DuplicateBucket(now, now, 1);
      return DanmakuFilterDecision(
        action: DanmakuFilterAction.allow,
        displayMessage: message,
      );
    }

    bucket.count += 1;
    bucket.lastSeen = now;
    if (foldMilestones.contains(bucket.count)) {
      return DanmakuFilterDecision(
        action: DanmakuFilterAction.foldDuplicate,
        displayMessage: '$message (×${bucket.count})',
        duplicateCount: bucket.count,
      );
    }
    return DanmakuFilterDecision(
      action: DanmakuFilterAction.suppressDuplicate,
      duplicateCount: bucket.count,
    );
  }

  void _pruneExpired(DateTime now, Duration window) {
    if (_recentMessages.length < 64) return;
    _recentMessages.removeWhere(
      (_, bucket) => now.difference(bucket.lastSeen) >= window,
    );
  }
}
