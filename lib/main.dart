import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io' show Directory, File, IOSink, Platform, SocketException;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!Platform.isAndroid) return;
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushService.initialize();
  runApp(const GhostNetApp());
}

class GhostNetApp extends StatelessWidget {
  const GhostNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GhostNet Cyber VPN',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: GhostColors.black,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: GhostColors.orange,
          secondary: GhostColors.orangeSoft,
          surface: GhostColors.panel,
          background: GhostColors.black,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: GhostColors.panelLight,
          contentTextStyle: const TextStyle(color: GhostColors.text, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const AppBootstrap(),
    );
  }
}

class GhostColors {
  static const black = Color(0xFF050505);
  static const deep = Color(0xFF090603);
  static const panel = Color(0xFF111111);
  static const panelLight = Color(0xFF1A1A1A);
  static const glass = Color(0xB5161616);
  static const orange = Color(0xFFFF7A00);
  static const orangeSoft = Color(0xFFFFA033);
  static const gold = Color(0xFFFFC15A);
  static const text = Color(0xFFF7F7F7);
  static const muted = Color(0xFFA9A9A9);
  static const line = Color(0x33FF7A00);
  static const success = Color(0xFF32D583);
  static const danger = Color(0xFFFF4D4D);
}

const String telegramBuyUrl = 'https://t.me/GhostNetV_bot?start=pr_WELCOME';
const String telegramBotUrl = 'https://t.me/GhostNetV_bot';
const String newsUrl = 'https://telegram.me/ghostnetv_news';
const String supportUrl = 'https://t.me/baltazzap';

const String apiBaseUrl = 'https://api.ghostnetcyber.ru';
const String appPaymentReturnUrl = 'https://api.ghostnetcyber.ru/api/payments/yookassa/return';
const String _tokenKey = 'ghostnet_access_token';
const String _rememberMeKey = 'ghostnet_remember_me';
const String _rememberedEmailKey = 'ghostnet_remembered_email';
const String _pendingPaymentKey = 'ghostnet_pending_payment_id';
const String _manualSubscriptionKey = 'ghostnet_manual_subscription_url';
const String _manualSubscriptionMetaKey = 'ghostnet_manual_subscription_meta';
final ValueNotifier<int> manualSubscriptionRevision = ValueNotifier<int>(0);
const Set<String> _ghostNetSubscriptionHosts = {
  'sub.ghostnetcyber.ru',
};

bool isGhostNetSubscriptionUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
  if (!_ghostNetSubscriptionHosts.contains(uri.host.toLowerCase())) return false;
  if (uri.userInfo.isNotEmpty || uri.hasFragment) return false;
  return uri.path.isNotEmpty && uri.path != '/';
}

List<String> _extractGhostNetSubscriptionLinks(String source) {
  final result = <String>[];
  final seen = <String>{};
  final matches = RegExp(
    r'(?:vless|vmess|trojan|ss)://[^\s<>"]+',
    caseSensitive: false,
  ).allMatches(source.replaceAll('\r', '\n'));
  for (final match in matches) {
    final value = match.group(0)?.trim() ?? '';
    if (value.isNotEmpty && seen.add(value)) result.add(value);
  }
  return result;
}

String _decodeGhostNetSubscriptionPayload(String text) {
  final trimmed = text.trim();
  if (trimmed.contains('://')) return trimmed;
  try {
    var normalized = trimmed
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    final padding = normalized.length % 4;
    if (padding > 0) normalized += List.filled(4 - padding, '=').join();
    return utf8.decode(base64Decode(normalized), allowMalformed: true);
  } catch (_) {
    return trimmed;
  }
}

class GhostNetSubscriptionVerification {
  final int serverCount;
  final String? planCode;
  final String? planName;
  final DateTime? expiresAt;
  final int? deviceLimit;

  const GhostNetSubscriptionVerification({
    required this.serverCount,
    this.planCode,
    this.planName,
    this.expiresAt,
    this.deviceLimit,
  });
}

const Map<String, String> _knownGhostNetPlans = {
  'ghost_start': 'GHOST START',
  'ghost_net': 'GHOST NET',
  'ghost_plus': 'GHOST PLUS',
  'ghost_premium': 'GHOST PREMIUM',
  'ghost_ultimate': 'GHOST ULTIMATE',
};

String? _decodeProfileTitle(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (!raw.toLowerCase().startsWith('base64:')) return raw;
  try {
    var encoded = raw.substring(7).trim().replaceAll('-', '+').replaceAll('_', '/');
    final padding = encoded.length % 4;
    if (padding > 0) encoded += List.filled(4 - padding, '=').join();
    return utf8.decode(base64Decode(encoded), allowMalformed: true).trim();
  } catch (_) {
    return raw;
  }
}

MapEntry<String, String>? _detectGhostNetPlan(String source) {
  final normalized = source.toLowerCase().replaceAll(RegExp(r'[_\-]+'), ' ');
  for (final entry in _knownGhostNetPlans.entries) {
    final codeText = entry.key.replaceAll('_', ' ');
    final nameText = entry.value.toLowerCase();
    if (normalized.contains(codeText) || normalized.contains(nameText)) return entry;
  }
  return null;
}

DateTime? _subscriptionExpiryFromHeaders(Map<String, String> headers) {
  final info = headers['subscription-userinfo'] ?? headers['x-subscription-userinfo'] ?? '';
  final match = RegExp(r'(?:^|[;\s])expire=(\d+)', caseSensitive: false).firstMatch(info);
  final seconds = int.tryParse(match?.group(1) ?? '');
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

int? _subscriptionDeviceLimitFromHeaders(Map<String, String> headers) {
  for (final key in const ['x-ghostnet-device-limit', 'x-device-limit', 'device-limit']) {
    final value = int.tryParse(headers[key]?.trim() ?? '');
    if (value != null && value > 0 && value <= 100) return value;
  }
  return null;
}

Future<GhostNetSubscriptionVerification> _verifyGhostNetSubscriptionUrl(String value) async {
  final clean = value.trim();
  if (!isGhostNetSubscriptionUrl(clean)) {
    throw const FormatException('Разрешены только ссылки https://sub.ghostnetcyber.ru/...');
  }

  final client = http.Client();
  try {
    var currentUri = Uri.parse(clean);
    for (var redirect = 0; redirect <= 3; redirect++) {
      final request = http.Request('GET', currentUri)
        ..followRedirects = false
        ..headers['Accept'] = 'text/plain, application/octet-stream, */*';
      final response = await client.send(request).timeout(const Duration(seconds: 15));

      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty || redirect == 3) {
          throw const FormatException('Некорректное перенаправление ссылки GhostNet.');
        }
        final nextUri = currentUri.resolve(location.trim());
        if (!isGhostNetSubscriptionUrl(nextUri.toString())) {
          throw const FormatException('Ссылка перенаправляет за пределы sub.ghostnetcyber.ru.');
        }
        currentUri = nextUri;
        continue;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException('Ссылка подписки GhostNet недоступна.');
      }

      final bytes = await response.stream.toBytes();
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('Получен некорректный файл подписки GhostNet.');
      }

      final raw = utf8.decode(bytes, allowMalformed: true);
      final decoded = _decodeGhostNetSubscriptionPayload(raw);
      final links = _extractGhostNetSubscriptionLinks(decoded);
      if (links.isEmpty) {
        throw const FormatException('Ссылка не содержит серверов GhostNet.');
      }

      final metadataText = [
        _decodeProfileTitle(response.headers['profile-title']),
        _decodeProfileTitle(response.headers['x-profile-title']),
        response.headers['content-disposition'],
        response.headers['x-ghostnet-plan'],
        response.headers['x-plan-code'],
        response.headers['x-plan-name'],
        decoded.length > 4096 ? decoded.substring(0, 4096) : decoded,
      ].whereType<String>().join(' ');
      final detectedPlan = _detectGhostNetPlan(metadataText);

      return GhostNetSubscriptionVerification(
        serverCount: links.length,
        planCode: detectedPlan?.key,
        planName: detectedPlan?.value,
        expiresAt: _subscriptionExpiryFromHeaders(response.headers),
        deviceLimit: _subscriptionDeviceLimitFromHeaders(response.headers),
      );
    }
    throw const FormatException('Слишком много перенаправлений ссылки GhostNet.');
  } finally {
    client.close();
  }
}
const String _pushChannelId = 'ghostnet_notifications';
const String _pushChannelName = 'GhostNet уведомления';
const String appUpdateManifestUrl =
    'https://ghostnetcyber.ru/downloads/version.json';
const String _dismissedUpdateVersionKey =
    'ghostnet_dismissed_update_version';
const MethodChannel _androidUpdateChannel = MethodChannel(
  'ru.ghostnet.cybervpn/app_update',
);


class AuthTokenStorage {
  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(migrateWithBackup: true),
  );

  static Future<String?> read() async {
    final secureToken = await _storage.read(key: _tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    // Однократный перенос старого токена из SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenKey);
    if (legacyToken == null || legacyToken.isEmpty) {
      return null;
    }

    await _storage.write(key: _tokenKey, value: legacyToken);
    await prefs.remove(_tokenKey);
    return legacyToken;
  }

  static Future<void> write(String token) async {
    await _storage.write(key: _tokenKey, value: token);

    // Удаляем старую незашифрованную копию, если она осталась.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> delete() async {
    await _storage.delete(key: _tokenKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}


class LoginPreferences {
  static Future<bool> rememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_rememberMeKey);
    if (stored != null) return stored;

    // Пользователи предыдущих версий уже имели постоянную сессию.
    // Сохраняем прежнее поведение при обновлении приложения.
    final token = await AuthTokenStorage.read();
    final legacyRemember = token != null && token.isNotEmpty;
    if (legacyRemember) await prefs.setBool(_rememberMeKey, true);
    return legacyRemember;
  }

  static Future<String> rememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberedEmailKey)?.trim() ?? '';
  }

  static Future<void> save({required bool remember, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, remember);
    if (remember && email.trim().isNotEmpty) {
      await prefs.setString(_rememberedEmailKey, email.trim().toLowerCase());
    } else {
      await prefs.remove(_rememberedEmailKey);
    }
  }
}



class AppUpdateInfo {
  final String version;
  final int build;
  final String title;
  final String message;
  final String downloadUrl;
  final String publishedAt;
  final bool mandatory;
  final String sha256;
  final int expectedSize;

  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.title,
    required this.message,
    required this.downloadUrl,
    required this.publishedAt,
    required this.mandatory,
    required this.sha256,
    required this.expectedSize,
  });

  String get releaseId => '$version+$build';

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final platformKey = Platform.isWindows ? 'windows' : 'android';
    final platformRaw = json[platformKey];
    final platform = platformRaw is Map
        ? Map<String, dynamic>.from(platformRaw)
        : <String, dynamic>{};

    final rawBuild = platform['build'] ?? json['build'];
    final build = rawBuild is num
        ? rawBuild.toInt()
        : int.tryParse(rawBuild?.toString() ?? '') ?? 0;

    final legacyUrl = Platform.isWindows
        ? json['windows_url']?.toString() ?? ''
        : json['android_url']?.toString() ?? '';

    final downloadUrl =
        platform['url']?.toString().trim().isNotEmpty == true
        ? platform['url'].toString().trim()
        : legacyUrl.trim();

    final platformVersion =
        platform['version']?.toString().trim() ?? '';
    final version = platformVersion.isNotEmpty
        ? platformVersion
        : json['version']?.toString().trim() ?? '';

    return AppUpdateInfo(
      version: version,
      build: build,
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'Доступно обновление GhostNet',
      message: json['message']?.toString().trim().isNotEmpty == true
          ? json['message'].toString().trim()
          : 'Установите новую версию приложения.',
      downloadUrl: downloadUrl,
      publishedAt: json['published_at']?.toString().trim() ?? '',
      mandatory: json['mandatory'] == true,
      sha256: platform['sha256']?.toString().trim().toLowerCase() ?? '',
      expectedSize: platform['size'] is num
          ? (platform['size'] as num).toInt()
          : int.tryParse(platform['size']?.toString() ?? '') ?? 0,
    );
  }
}

enum _AppUpdateAction {
  later,
  download,
}

class AppUpdateService {
  static const Duration _timeout = Duration(seconds: 10);

  static Future<void> check(
    BuildContext context, {
    bool manual = false,
  }) async {
    if (!Platform.isAndroid && !Platform.isWindows) {
      if (manual && context.mounted) {
        _showSnack(context, 'Проверка обновлений доступна на Android и Windows.');
      }
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final update = await _fetch();

      if (update == null) {
        if (manual && context.mounted) {
          _showSnack(context, 'Сервер обновлений не вернул данные.');
        }
        return;
      }

      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint(
        '[GhostNet Update] installed='
        '${packageInfo.version}+$currentBuild, '
        'server=${update.version}+${update.build}, '
        'url=${update.downloadUrl}',
      );

      final isNewer = _isNewer(
        currentVersion: packageInfo.version,
        currentBuild: currentBuild,
        remoteVersion: update.version,
        remoteBuild: update.build,
      );

      if (!isNewer) {
        if (manual && context.mounted) {
          _showSnack(
            context,
            'Установлена последняя версия: ${packageInfo.version}+$currentBuild.',
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final dismissedRelease = prefs.getString(_dismissedUpdateVersionKey);

      if (!manual &&
          !update.mandatory &&
          dismissedRelease == update.releaseId) {
        return;
      }

      if (!context.mounted) return;

      final action = await _showUpdateDialog(
        context,
        update: update,
        currentVersion: packageInfo.version,
        currentBuild: currentBuild,
      );

      if (action == _AppUpdateAction.download) {
        if (Platform.isAndroid) {
          await _showAndroidUpdateInstaller(context, update);
        } else {
          await openExternal(update.downloadUrl);
        }
        return;
      }

      if (action == _AppUpdateAction.later && !update.mandatory) {
        await prefs.setString(
          _dismissedUpdateVersionKey,
          update.releaseId,
        );
      }
    } on TimeoutException {
      if (manual && context.mounted) {
        _showSnack(context, 'Сервер обновлений не ответил за 10 секунд.');
      }
    } on SocketException {
      if (manual && context.mounted) {
        _showSnack(context, 'Нет подключения к интернету.');
      }
    } catch (error) {
      if (manual && context.mounted) {
        _showSnack(
          context,
          'Не удалось проверить обновления: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  static Future<AppUpdateInfo?> _fetch() async {
    final baseUri = Uri.parse(appUpdateManifestUrl);
    final uri = baseUri.replace(
      queryParameters: {
        ...baseUri.queryParameters,
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Сервер обновлений вернул код ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный формат version.json.');
    }

    final update = AppUpdateInfo.fromJson(decoded);
    if (update.version.isEmpty ||
        update.build <= 0 ||
        update.downloadUrl.isEmpty) {
      throw Exception('В version.json отсутствуют обязательные поля.');
    }

    return update;
  }

  static bool _isNewer({
    required String currentVersion,
    required int currentBuild,
    required String remoteVersion,
    required int remoteBuild,
  }) {
    final versionComparison = _compareVersions(
      remoteVersion,
      currentVersion,
    );

    if (versionComparison > 0) return true;
    if (versionComparison < 0) return false;
    return remoteBuild > currentBuild;
  }

  static int _compareVersions(String first, String second) {
    final firstParts = _versionParts(first);
    final secondParts = _versionParts(second);
    final length = math.max(firstParts.length, secondParts.length);

    for (var index = 0; index < length; index++) {
      final firstValue =
          index < firstParts.length ? firstParts[index] : 0;
      final secondValue =
          index < secondParts.length ? secondParts[index] : 0;

      if (firstValue > secondValue) return 1;
      if (firstValue < secondValue) return -1;
    }

    return 0;
  }

  static List<int> _versionParts(String value) {
    return value
        .split('.')
        .map((part) {
          final match = RegExp(r'^\d+').firstMatch(part.trim());
          return int.tryParse(match?.group(0) ?? '') ?? 0;
        })
        .toList(growable: false);
  }

  static Future<_AppUpdateAction?> _showUpdateDialog(
    BuildContext context, {
    required AppUpdateInfo update,
    required String currentVersion,
    required int currentBuild,
  }) {
    return showDialog<_AppUpdateAction>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (dialogContext) {
        return PopScope(
          canPop: !update.mandatory,
          child: AlertDialog(
            backgroundColor: GhostColors.panel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: GhostColors.orange.withOpacity(.38),
              ),
            ),
            title: Row(
              children: [
                const CircleIcon(icon: Icons.system_update_alt_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    update.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      MiniBadge(
                        text: 'СЕЙЧАС $currentVersion+$currentBuild',
                      ),
                      MiniBadge(
                        text: 'НОВАЯ ${update.version}+${update.build}',
                      ),
                      if (update.mandatory)
                        const MiniBadge(text: 'ОБЯЗАТЕЛЬНО'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    update.message,
                    style: const TextStyle(
                      color: GhostColors.muted,
                      height: 1.5,
                    ),
                  ),
                  if (update.publishedAt.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Опубликовано: ${update.publishedAt}',
                      style: const TextStyle(
                        color: GhostColors.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (update.mandatory) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Для продолжения работы необходимо установить '
                      'актуальную версию.',
                      style: TextStyle(
                        color: GhostColors.orangeSoft,
                        fontWeight: FontWeight.w900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!update.mandatory)
                SecondaryButton(
                  text: 'Позже',
                  icon: Icons.schedule_rounded,
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _AppUpdateAction.later,
                  ),
                ),
              PrimaryButton(
                text: Platform.isWindows
                    ? 'Скачать установщик Windows'
                    : 'Скачать и установить',
                icon: Platform.isWindows
                    ? Icons.download_rounded
                    : Icons.install_mobile_rounded,
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _AppUpdateAction.download,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showAndroidUpdateInstaller(
  BuildContext context,
  AppUpdateInfo update,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.mandatory,
    builder: (_) => _AndroidUpdateInstallerDialog(update: update),
  );
}

class _AndroidUpdateInstallerDialog extends StatefulWidget {
  final AppUpdateInfo update;

  const _AndroidUpdateInstallerDialog({required this.update});

  @override
  State<_AndroidUpdateInstallerDialog> createState() =>
      _AndroidUpdateInstallerDialogState();
}

class _AndroidUpdateInstallerDialogState
    extends State<_AndroidUpdateInstallerDialog>
    with WidgetsBindingObserver {
  http.Client? _client;
  String _status = 'Подготовка загрузки...';
  String? _apkPath;
  double? _progress;
  int _receivedBytes = 0;
  int? _totalBytes;
  bool _busy = true;
  bool _failed = false;
  bool _waitingForInstallPermission = false;
  bool _installerOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_download());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _client?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _waitingForInstallPermission &&
        _apkPath != null) {
      unawaited(_launchInstaller(openPermissionSettings: false));
    }
  }

  Future<void> _download() async {
    _client?.close();
    _client = http.Client();

    if (mounted) {
      setState(() {
        _status = 'Скачивание обновления внутри GhostNet...';
        _progress = null;
        _receivedBytes = 0;
        _totalBytes = null;
        _busy = true;
        _failed = false;
        _waitingForInstallPermission = false;
        _installerOpened = false;
      });
    }

    late final File outputFile;
    IOSink? sink;

    try {
      final cachePath = await _androidUpdateChannel.invokeMethod<String>(
        'getCacheDir',
      );
      if (cachePath == null || cachePath.trim().isEmpty) {
        throw Exception('Android не вернул папку для загрузки.');
      }

      final updatesDirectory = Directory('$cachePath/updates');
      await updatesDirectory.create(recursive: true);

      await for (final entity in updatesDirectory.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }

      final uri = Uri.parse(widget.update.downloadUrl);
      var filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last.trim()
          : '';
      filename = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (!filename.toLowerCase().endsWith('.apk')) {
        filename =
            'GhostNet-Cyber-VPN-${widget.update.version}-${widget.update.build}.apk';
      }

      outputFile = File('${updatesDirectory.path}/$filename');
      final request = http.Request('GET', uri)
        ..headers.addAll(const {
          'Accept':
              'application/vnd.android.package-archive,application/octet-stream,*/*',
          'Cache-Control': 'no-cache',
        });

      final response = await _client!
          .send(request)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          'Сервер APK вернул код ${response.statusCode}.',
        );
      }

      _totalBytes = response.contentLength;
      sink = outputFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        _receivedBytes += chunk.length;

        final total = _totalBytes;
        if (total != null && total > 0) {
          _progress = (_receivedBytes / total).clamp(0.0, 1.0).toDouble();
        }

        if (mounted) {
          setState(() {
            _status = total != null && total > 0
                ? 'Скачано ${_formatBytes(_receivedBytes)} из ${_formatBytes(total)}'
                : 'Скачано ${_formatBytes(_receivedBytes)}';
          });
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      final fileLength = await outputFile.length();
      if (fileLength <= 0) {
        throw Exception('Сервер вернул пустой APK.');
      }

      if (_totalBytes != null &&
          _totalBytes! > 0 &&
          fileLength != _totalBytes) {
        throw Exception('APK скачан не полностью. Повторите попытку.');
      }

      if (widget.update.expectedSize > 0 &&
          fileLength != widget.update.expectedSize) {
        throw Exception('Размер APK не совпадает с данными релиза.');
      }

      final apkHeader = await outputFile.openRead(0, 4).fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      if (apkHeader.length < 4 ||
          apkHeader[0] != 0x50 ||
          apkHeader[1] != 0x4B ||
          apkHeader[2] != 0x03 ||
          apkHeader[3] != 0x04) {
        throw Exception(
          'Скачанный файл не является корректным APK.',
        );
      }

      if (widget.update.sha256.isNotEmpty) {
        if (mounted) {
          setState(() {
            _status = 'Проверка целостности APK...';
          });
        }
        final actualHash =
            await _androidUpdateChannel.invokeMethod<String>(
              'sha256',
              {'path': outputFile.path},
            ) ??
            '';
        if (actualHash.toLowerCase() != widget.update.sha256) {
          try {
            await outputFile.delete();
          } catch (_) {}
          throw Exception('Контрольная сумма APK не совпадает.');
        }
      }

      _apkPath = outputFile.path;
      if (mounted) {
        setState(() {
          _progress = 1;
          _status = 'APK скачан. Запускаю установку...';
        });
      }

      await _launchInstaller();
    } on TimeoutException {
      _setFailure('Сервер APK не ответил за 30 секунд.');
    } on SocketException {
      _setFailure('Нет подключения к интернету.');
    } on PlatformException catch (error) {
      _setFailure(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Android не смог запустить установку.',
      );
    } catch (error) {
      _setFailure(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      _client?.close();
      _client = null;
    }
  }

  Future<void> _launchInstaller({bool openPermissionSettings = true}) async {
    final apkPath = _apkPath;
    if (apkPath == null || apkPath.isEmpty) return;

    try {
      final canInstall =
          await _androidUpdateChannel.invokeMethod<bool>(
            'canInstallPackages',
          ) ??
          false;

      if (!canInstall) {
        if (mounted) {
          setState(() {
            _busy = false;
            _failed = false;
            _waitingForInstallPermission = true;
            _status =
                'Разрешите GhostNet устанавливать обновления. После возврата установщик запустится автоматически.';
          });
        }

        if (openPermissionSettings) {
          await _androidUpdateChannel.invokeMethod<void>(
            'openInstallPermissionSettings',
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _busy = true;
          _failed = false;
          _waitingForInstallPermission = false;
          _status = 'Открываю системный установщик Android...';
        });
      }

      final opened =
          await _androidUpdateChannel.invokeMethod<bool>(
            'installApk',
            {'path': apkPath},
          ) ??
          false;

      if (!opened) {
        throw Exception('Системный установщик не открылся.');
      }

      if (mounted) {
        setState(() {
          _busy = false;
          _installerOpened = true;
          _status =
              'Установщик открыт. Нажмите «Установить», чтобы завершить обновление.';
        });
      }
    } on PlatformException catch (error) {
      _setFailure(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Android не смог открыть установщик.',
      );
    } catch (error) {
      _setFailure(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openInstallPermissionSettings() async {
    try {
      if (mounted) {
        setState(() {
          _busy = true;
          _status = 'Открываю разрешение установки приложений...';
        });
      }
      await _androidUpdateChannel.invokeMethod<void>(
        'openInstallPermissionSettings',
      );
    } on PlatformException catch (error) {
      _setFailure(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Не удалось открыть настройки Android.',
      );
    }
  }

  void _setFailure(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = true;
      _waitingForInstallPermission = false;
      _status = message;
    });
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} КБ';
    final megabytes = kilobytes / 1024;
    return '${megabytes.toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) {
    final percent = _progress == null
        ? null
        : '${(_progress! * 100).round()}%';

    return PopScope(
      canPop: !widget.update.mandatory && !_busy,
      child: AlertDialog(
        backgroundColor: GhostColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: (_failed ? GhostColors.danger : GhostColors.orange)
                .withOpacity(.42),
          ),
        ),
        title: const Row(
          children: [
            CircleIcon(icon: Icons.install_mobile_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Обновление GhostNet',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _status,
                style: TextStyle(
                  color: _failed
                      ? GhostColors.danger
                      : GhostColors.muted,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_busy || _progress != null) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(99),
                ),
                if (percent != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      percent,
                      style: const TextStyle(
                        color: GhostColors.gold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
              if (_waitingForInstallPermission) ...[
                const SizedBox(height: 14),
                const Text(
                  'Это разрешение Android запрашивает один раз для приложений, установленных не из Google Play.',
                  style: TextStyle(
                    color: GhostColors.orangeSoft,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (_installerOpened) ...[
                const SizedBox(height: 14),
                const Text(
                  'Android не разрешает обычному приложению нажать кнопку установки вместо пользователя.',
                  style: TextStyle(
                    color: GhostColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_failed)
            SecondaryButton(
              text: 'Повторить',
              icon: Icons.refresh_rounded,
              onPressed: _download,
            ),
          if (_waitingForInstallPermission)
            PrimaryButton(
              text: 'Разрешить установку',
              icon: Icons.settings_rounded,
              onPressed: _openInstallPermissionSettings,
            ),
          if (_installerOpened ||
              (_apkPath != null && !_busy && !_failed))
            PrimaryButton(
              text: 'Открыть установщик снова',
              icon: Icons.install_mobile_rounded,
              onPressed: _launchInstaller,
            ),
          if (!widget.update.mandatory && !_busy)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          if (!widget.update.mandatory && _busy)
            TextButton(
              onPressed: () {
                _client?.close();
                Navigator.pop(context);
              },
              child: const Text('Отмена'),
            ),
        ],
      ),
    );
  }
}


class PushService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _tokenRefreshBound = false;

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    _pushChannelId,
    _pushChannelName,
    description: 'Системные уведомления GhostNet Cyber VPN',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_ghostnet'),
      );

      await _localNotifications.initialize(initSettings);

      final androidLocal = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidLocal?.createNotificationChannel(_androidChannel);
      await androidLocal?.requestNotificationsPermission();

      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((message) async {
        await _showLocalNotification(message);
      });

      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title'] ??
        message.data['notification_title'] ??
        'GhostNet Cyber VPN';
    final body = message.notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        'Новое уведомление';

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _pushChannelId,
          _pushChannelName,
          channelDescription: 'Системные уведомления GhostNet Cyber VPN',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@drawable/ic_stat_ghostnet',
          color: GhostColors.orange,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.status,
          ticker: 'GhostNet Cyber VPN',
        ),
      ),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  static Future<void> registerForUser(String authToken) async {
    if (!Platform.isAndroid || authToken.isEmpty) return;

    try {
      await initialize();
      final pushToken = await FirebaseMessaging.instance.getToken();
      if (pushToken != null && pushToken.isNotEmpty) {
        await GhostApi.registerPushToken(
          authToken: authToken,
          pushToken: pushToken,
          platform: 'android',
        );
      }

      if (!_tokenRefreshBound) {
        _tokenRefreshBound = true;
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          GhostApi.registerPushToken(
            authToken: authToken,
            pushToken: newToken,
            platform: 'android',
          );
        });
      }
    } catch (_) {}
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class GhostApi {
  static Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');
  static const Duration _requestTimeout = Duration(seconds: 15);

  static Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        'Сервер не ответил за 15 секунд. Попробуйте ещё раз.',
      );
    } on SocketException {
      throw const ApiException('Нет подключения к интернету.');
    } on http.ClientException {
      throw const ApiException('Ошибка сетевого подключения.');
    }
  }

  static Map<String, String> _headers([String? token]) {
    return {
      'accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static String _errorFrom(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && data['detail'] != null) {
        final detail = data['detail'];
        if (detail is String) return detail;
        return detail.toString();
      }
      if (data is Map && data['message'] != null) return data['message'].toString();
    } catch (_) {}
    return 'Ошибка API ${response.statusCode}';
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await _send(
      http.post(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorFrom(response));
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is Map<String, dynamic>) return data;
    throw const ApiException('API вернул неправильный формат ответа.');
  }

  static Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body, {String? token}) async {
    final response = await _send(
      http.put(
        _uri(path),
        headers: _headers(token),
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorFrom(response));
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is Map<String, dynamic>) return data;
    throw const ApiException('API вернул неправильный формат ответа.');
  }

  static Future<dynamic> _get(String path, {String? token}) async {
    final response = await _send(
      http.get(_uri(path), headers: _headers(token)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorFrom(response));
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Future<dynamic> _delete(String path, {String? token}) async {
    final response = await _send(
      http.delete(_uri(path), headers: _headers(token)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorFrom(response));
    }
    if (response.bodyBytes.isEmpty) return {};
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static Future<String> login({required String email, required String password}) async {
    final data = await _post('/api/auth/login', {'email': email, 'password': password});
    return data['access_token'].toString();
  }

  static Future<String> register({required String email, required String password, String? telegramUsername}) async {
    final telegram = (telegramUsername ?? '').trim();
    final data = await _post('/api/auth/register', {
      'email': email,
      'password': password,
      'telegram_username': telegram.isEmpty ? null : telegram,
    });
    return data['access_token'].toString();
  }

  static Future<UserProfile> me(String token) async {
    final data = await _get('/api/me', token: token);
    if (data is Map<String, dynamic>) return UserProfile.fromJson(data, token);
    throw const ApiException('Не удалось загрузить профиль.');
  }

  static Future<List<Tariff>> plans() async {
    final data = await _get('/api/plans');
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(Tariff.fromJson).toList();
    }
    return tariffs;
  }

  static Future<PaymentStart> createPayment({required String token, required String planCode, String? promocode}) async {
    final data = await _post('/api/payments/yookassa/create', {
      'plan_code': planCode,
      'promocode': promocode == null || promocode.trim().isEmpty ? null : promocode.trim().toUpperCase(),
      'return_url': appPaymentReturnUrl,
    }, token: token);
    return PaymentStart.fromJson(data);
  }

  static Future<PaymentStatus> paymentStatus({required String token, required int paymentId}) async {
    final data = await _get('/api/payments/$paymentId/status', token: token);
    if (data is Map<String, dynamic>) return PaymentStatus.fromJson(data);
    throw const ApiException('Не удалось проверить оплату.');
  }

  static Future<SubscriptionInfo> claimTrial(String token) async {
    final data = await _post('/api/trial/claim', {}, token: token);
    final sub = data['subscription'];
    if (sub is Map<String, dynamic>) return SubscriptionInfo.fromJson(sub);
    throw const ApiException('API не вернул пробную подписку.');
  }


  static Future<PromoCheckResult> checkPromocode({required String token, required String code, required String planCode}) async {
    final data = await _post('/api/promocode/check', {'code': code, 'plan_code': planCode}, token: token);
    return PromoCheckResult.fromJson(data);
  }

  static Future<ReferralInfo> referralMe(String token) async {
    final data = await _get('/api/referrals/me', token: token);
    if (data is Map<String, dynamic>) return ReferralInfo.fromJson(data);
    throw const ApiException('Не удалось загрузить реферальную систему.');
  }

  static Future<String> applyReferralCode({required String token, required String code}) async {
    final data = await _post('/api/referrals/apply-code', {'code': code.trim().toUpperCase()}, token: token);
    return data['message']?.toString() ?? 'Реферальный код применён.';
  }

  static Future<List<SupportTicketInfo>> supportTickets(String token) async {
    final data = await _get('/api/support/tickets', token: token);
    if (data is List) return data.whereType<Map<String, dynamic>>().map(SupportTicketInfo.fromJson).toList();
    return [];
  }

  static Future<SupportTicketInfo> createSupportTicket({required String token, required String subject, required String message}) async {
    final data = await _post('/api/support/tickets', {'subject': subject, 'message': message}, token: token);
    return SupportTicketInfo.fromJson(data);
  }

  static Future<SupportTicketInfo> supportAddMessage({required String token, required int ticketId, required String message}) async {
    final data = await _post('/api/support/tickets/$ticketId/messages', {'message': message}, token: token);
    return SupportTicketInfo.fromJson(data);
  }

  static Future<AdminOverview> adminOverview(String token) async {
    final data = await _get('/api/admin/app/overview', token: token);
    if (data is Map<String, dynamic>) return AdminOverview.fromJson(data);
    throw const ApiException('Не удалось загрузить админ-сводку.');
  }

  static Future<List<AdminUserInfo>> adminUsers(String token, {String query = ''}) async {
    final suffix = query.trim().isEmpty ? '' : '?q=${Uri.encodeComponent(query.trim())}';
    final data = await _get('/api/admin/app/users$suffix', token: token);
    if (data is List) return data.whereType<Map<String, dynamic>>().map(AdminUserInfo.fromJson).toList();
    return [];
  }

  static Future<AdminReferralStats> adminReferrals(String token) async {
    final data = await _get('/api/admin/app/referrals', token: token);
    if (data is Map<String, dynamic>) return AdminReferralStats.fromJson(data);
    throw const ApiException('Не удалось загрузить рефералов.');
  }

  static Future<List<AdminPromocodeInfo>> adminPromocodes(String token) async {
    final data = await _get('/api/admin/app/promocodes', token: token);
    if (data is List) return data.whereType<Map<String, dynamic>>().map(AdminPromocodeInfo.fromJson).toList();
    return [];
  }

  static Future<List<AdminPlanInfo>> adminPlans(String token) async {
    final data = await _get('/api/admin/app/plans', token: token);
    if (data is List) return data.whereType<Map<String, dynamic>>().map(AdminPlanInfo.fromJson).toList();
    return [];
  }

  static Future<AdminPlanInfo> adminCreatePlan({required String token, required String code, required String name, required int priceRub, required int durationDays, String? description, bool isActive = true}) async {
    final data = await _post('/api/admin/app/plans', {
      'code': code,
      'name': name,
      'price_rub': priceRub,
      'duration_days': durationDays,
      'description': description == null || description.trim().isEmpty ? null : description.trim(),
      'is_active': isActive,
    }, token: token);
    return AdminPlanInfo.fromJson(data);
  }

  static Future<AdminPlanInfo> adminUpdatePlan({required String token, required String code, required String name, required int priceRub, required int durationDays, String? description, required bool isActive}) async {
    final data = await _put('/api/admin/app/plans/${Uri.encodeComponent(code)}', {
      'name': name,
      'price_rub': priceRub,
      'duration_days': durationDays,
      'description': description == null || description.trim().isEmpty ? null : description.trim(),
      'is_active': isActive,
    }, token: token);
    return AdminPlanInfo.fromJson(data);
  }

  static Future<void> adminSetPlanActive({required String token, required String code, required bool enabled}) async {
    await _post('/api/admin/app/plans/${Uri.encodeComponent(code)}/active', {'enabled': enabled}, token: token);
  }

  static Future<void> adminDeletePlan({required String token, required String code}) async {
    await _delete('/api/admin/app/plans/${Uri.encodeComponent(code)}', token: token);
  }

  static Future<void> adminSetRole({required String token, required int userId, required String role, required bool enabled}) async {
    await _post('/api/admin/app/users/$userId/$role', {'enabled': enabled}, token: token);
  }

  static Future<void> adminDeleteUser({required String token, required int userId}) async {
    await _delete('/api/admin/app/users/$userId', token: token);
  }

  static Future<List<SubscriptionInfo>> adminUserSubscriptions({required String token, required int userId}) async {
    final data = await _get('/api/admin/app/users/$userId/subscriptions', token: token);
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map((e) => SubscriptionInfo.fromJson((e['subscription'] as Map).cast<String, dynamic>())).toList();
    }
    return [];
  }

  static Future<SubscriptionInfo> adminGrantSubscription({required String token, required int userId, required String planCode, required int days, required int deviceLimit}) async {
    final data = await _post('/api/admin/app/users/$userId/subscriptions/grant', {
      'plan_code': planCode,
      'duration_days': days,
      'device_limit': deviceLimit,
    }, token: token);
    return SubscriptionInfo.fromJson((data['subscription'] as Map).cast<String, dynamic>());
  }

  static Future<SubscriptionInfo> adminExtendSubscription({required String token, required int subscriptionId, required int days}) async {
    final data = await _post('/api/admin/app/subscriptions/$subscriptionId/extend', {'days': days}, token: token);
    return SubscriptionInfo.fromJson((data['subscription'] as Map).cast<String, dynamic>());
  }

  static Future<void> adminDeleteSubscription({required String token, required int subscriptionId}) async {
    await _delete('/api/admin/app/subscriptions/$subscriptionId', token: token);
  }

  static Future<void> adminCreatePromocode({required String token, required String code, required int discountPercent}) async {
    await _post('/api/admin/app/promocodes', {
      'code': code,
      'discount_percent': discountPercent,
      'first_purchase_only': true,
      'is_active': true,
    }, token: token);
  }

  static Future<void> adminDeletePromocode({required String token, required String code}) async {
    await _delete('/api/admin/app/promocodes/${Uri.encodeComponent(code)}', token: token);
  }

  static Future<void> adminSetPromocodeActive({required String token, required String code, required bool enabled}) async {
    await _post('/api/admin/app/promocodes/${Uri.encodeComponent(code)}/active', {'enabled': enabled}, token: token);
  }

  static Future<List<SupportTicketInfo>> adminSupportTickets(String token) async {
    final data = await _get('/api/admin/app/support/tickets', token: token);
    if (data is List) return data.whereType<Map<String, dynamic>>().map(SupportTicketInfo.fromJson).toList();
    return [];
  }

  static Future<SupportTicketInfo> adminReplyTicket({required String token, required int ticketId, required String message}) async {
    final data = await _post('/api/admin/app/support/tickets/$ticketId/reply', {'message': message}, token: token);
    return SupportTicketInfo.fromJson(data);
  }

  static Future<void> adminCloseTicket({required String token, required int ticketId}) async {
    await _post('/api/admin/app/support/tickets/$ticketId/close', {}, token: token);
  }

  static Future<void> adminDeleteTicket({required String token, required int ticketId}) async {
    await _delete('/api/admin/app/support/tickets/$ticketId', token: token);
  }

  static Future<void> adminDeleteAllTickets({required String token}) async {
    await _delete('/api/admin/app/support/tickets', token: token);
  }

  static Future<void> adminClearPaymentsHistory({required String token}) async {
    await _delete('/api/admin/app/payments/history', token: token);
  }

  static Future<Map<String, dynamic>> adminRunMaintenance({required String token}) async {
    final data = await _post('/api/admin/app/maintenance/run', {}, token: token);
    return data;
  }

  static Future<List<NotificationInfo>> notifications(String token) async {
    final data = await _get('/api/notifications/my', token: token);
    if (data is List) return data.whereType<Map<String, dynamic>>().map(NotificationInfo.fromJson).toList();
    return [];
  }

  static Future<void> notificationRead({required String token, required int id}) async {
    await _post('/api/notifications/$id/read', {}, token: token);
  }

  static Future<void> notificationsReadAll(String token) async {
    await _post('/api/notifications/read-all', {}, token: token);
  }


  static Future<void> registerPushToken({required String authToken, required String pushToken, String platform = 'android'}) async {
    await _post('/api/notifications/push-token', {
      'token': pushToken,
      'platform': platform,
    }, token: authToken);
  }

  static Future<List<Map<String, dynamic>>> vpnServers(String token) async {
    final data = await _get('/api/vpn/servers', token: token);
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  static Future<List<SubscriptionInfo>> mySubscriptions(String token) async {
    final data = await _get('/api/subscriptions/my', token: token);
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(SubscriptionInfo.fromJson).toList();
    }
    return [];
  }
}



class PaymentStart {
  final int paymentId;
  final String yookassaPaymentId;
  final String status;
  final String confirmationUrl;

  const PaymentStart({required this.paymentId, required this.yookassaPaymentId, required this.status, required this.confirmationUrl});

  factory PaymentStart.fromJson(Map<String, dynamic> json) {
    return PaymentStart(
      paymentId: (json['payment_id'] as num?)?.toInt() ?? 0,
      yookassaPaymentId: json['yookassa_payment_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      confirmationUrl: json['confirmation_url']?.toString() ?? '',
    );
  }
}

class PaymentStatus {
  final int id;
  final String status;
  final bool paid;
  final String message;
  final int? processedSubscriptionId;

  const PaymentStatus({required this.id, required this.status, required this.paid, required this.message, this.processedSubscriptionId});

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentStatus(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      paid: json['paid'] == true,
      message: json['message']?.toString() ?? 'Ожидаем оплату',
      processedSubscriptionId: (json['processed_subscription_id'] as num?)?.toInt(),
    );
  }

  bool get isSuccess => paid || status == 'succeeded';
  bool get isCanceled => status == 'canceled';
}


class NotificationInfo {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationInfo({required this.id, required this.title, required this.message, required this.type, required this.isRead, required this.createdAt});

  factory NotificationInfo.fromJson(Map<String, dynamic> json) {
    return NotificationInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? 'Уведомление',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'info',
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class PromoCheckResult {
  final bool valid;
  final String? code;
  final int discountPercent;
  final int? oldPrice;
  final int? newPrice;
  final String message;

  const PromoCheckResult({required this.valid, this.code, required this.discountPercent, this.oldPrice, this.newPrice, required this.message});

  factory PromoCheckResult.fromJson(Map<String, dynamic> json) {
    return PromoCheckResult(
      valid: json['valid'] == true,
      code: json['code']?.toString(),
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      oldPrice: (json['old_price_rub'] as num?)?.toInt(),
      newPrice: (json['new_price_rub'] as num?)?.toInt(),
      message: json['message']?.toString() ?? '',
    );
  }
}

class ReferralInfo {
  final String code;
  final String shareUrl;
  final int invitedTotal;
  final int paidTotal;
  final int rewardedTotal;
  final int bonusDaysTotal;
  final bool canApplyCode;
  final String? referredByCode;
  final String? referredByEmail;

  const ReferralInfo({
    required this.code,
    required this.shareUrl,
    required this.invitedTotal,
    required this.paidTotal,
    required this.rewardedTotal,
    required this.bonusDaysTotal,
    required this.canApplyCode,
    this.referredByCode,
    this.referredByEmail,
  });

  factory ReferralInfo.fromJson(Map<String, dynamic> json) {
    return ReferralInfo(
      code: json['code']?.toString() ?? '',
      shareUrl: json['share_url']?.toString() ?? '',
      invitedTotal: (json['invited_total'] as num?)?.toInt() ?? 0,
      paidTotal: (json['paid_total'] as num?)?.toInt() ?? 0,
      rewardedTotal: (json['rewarded_total'] as num?)?.toInt() ?? 0,
      bonusDaysTotal: (json['bonus_days_total'] as num?)?.toInt() ?? 0,
      canApplyCode: json['can_apply_code'] == true,
      referredByCode: json['referred_by_code']?.toString(),
      referredByEmail: json['referred_by_email']?.toString(),
    );
  }
}

class AdminReferralItem {
  final int id;
  final String referrerEmail;
  final String referredEmail;
  final String referralCode;
  final String status;
  final int rewardDays;
  final int? paymentId;

  const AdminReferralItem({required this.id, required this.referrerEmail, required this.referredEmail, required this.referralCode, required this.status, required this.rewardDays, this.paymentId});

  factory AdminReferralItem.fromJson(Map<String, dynamic> json) {
    return AdminReferralItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      referrerEmail: json['referrer_email']?.toString() ?? '',
      referredEmail: json['referred_email']?.toString() ?? '',
      referralCode: json['referral_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'registered',
      rewardDays: (json['reward_days'] as num?)?.toInt() ?? 0,
      paymentId: (json['payment_id'] as num?)?.toInt(),
    );
  }
}

class AdminReferralStats {
  final int invitedTotal;
  final int paidTotal;
  final int rewardedTotal;
  final int bonusDaysTotal;
  final List<AdminReferralItem> items;

  const AdminReferralStats({required this.invitedTotal, required this.paidTotal, required this.rewardedTotal, required this.bonusDaysTotal, required this.items});

  factory AdminReferralStats.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return AdminReferralStats(
      invitedTotal: (json['invited_total'] as num?)?.toInt() ?? 0,
      paidTotal: (json['paid_total'] as num?)?.toInt() ?? 0,
      rewardedTotal: (json['rewarded_total'] as num?)?.toInt() ?? 0,
      bonusDaysTotal: (json['bonus_days_total'] as num?)?.toInt() ?? 0,
      items: raw is List ? raw.whereType<Map<String, dynamic>>().map(AdminReferralItem.fromJson).toList() : <AdminReferralItem>[],
    );
  }
}

class AdminOverview {
  final int users;
  final int activeSubscriptions;
  final int payments;
  final int ticketsOpen;
  final int promocodesActive;

  const AdminOverview({required this.users, required this.activeSubscriptions, required this.payments, required this.ticketsOpen, required this.promocodesActive});

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      users: (json['users'] as num?)?.toInt() ?? 0,
      activeSubscriptions: (json['active_subscriptions'] as num?)?.toInt() ?? 0,
      payments: (json['payments'] as num?)?.toInt() ?? 0,
      ticketsOpen: (json['tickets_open'] as num?)?.toInt() ?? 0,
      promocodesActive: (json['promocodes_active'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminUserInfo {
  final int id;
  final String email;
  final String telegram;
  final bool isActive;
  final bool isAdmin;
  final bool isSupport;

  const AdminUserInfo({required this.id, required this.email, required this.telegram, required this.isActive, required this.isAdmin, required this.isSupport});

  factory AdminUserInfo.fromJson(Map<String, dynamic> json) {
    return AdminUserInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      telegram: json['telegram_username']?.toString() ?? '',
      isActive: json['is_active'] == true,
      isAdmin: json['is_admin'] == true,
      isSupport: json['is_support'] == true,
    );
  }
}

class AdminPlanInfo {
  final int id;
  final String code;
  final String name;
  final int priceRub;
  final int durationDays;
  final String description;
  final bool isActive;

  const AdminPlanInfo({required this.id, required this.code, required this.name, required this.priceRub, required this.durationDays, required this.description, required this.isActive});

  factory AdminPlanInfo.fromJson(Map<String, dynamic> json) {
    return AdminPlanInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priceRub: (json['price_rub'] as num?)?.toInt() ?? 0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }
}

class AdminPromocodeInfo {
  final String code;
  final int discountPercent;
  final bool firstPurchaseOnly;
  final bool isActive;

  const AdminPromocodeInfo({required this.code, required this.discountPercent, required this.firstPurchaseOnly, required this.isActive});

  factory AdminPromocodeInfo.fromJson(Map<String, dynamic> json) {
    return AdminPromocodeInfo(
      code: json['code']?.toString() ?? '',
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      firstPurchaseOnly: json['first_purchase_only'] == true,
      isActive: json['is_active'] == true,
    );
  }
}

class SupportMessageInfo {
  final String message;
  final bool isStaff;
  final String authorName;
  final String authorEmail;
  final DateTime? createdAt;

  const SupportMessageInfo({required this.message, required this.isStaff, required this.authorName, required this.authorEmail, required this.createdAt});

  factory SupportMessageInfo.fromJson(Map<String, dynamic> json) {
    final staff = json['is_staff'] == true;
    return SupportMessageInfo(
      message: json['message']?.toString() ?? '',
      isStaff: staff,
      authorName: json['author_name']?.toString() ?? (staff ? 'Поддержка GhostNet' : 'Пользователь'),
      authorEmail: json['author_email']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class SupportTicketInfo {
  final int id;
  final String userName;
  final String userEmail;
  final String subject;
  final String status;
  final DateTime? updatedAt;
  final List<SupportMessageInfo> messages;

  const SupportTicketInfo({required this.id, required this.userName, required this.userEmail, required this.subject, required this.status, required this.updatedAt, required this.messages});

  factory SupportTicketInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = raw is List ? raw.whereType<Map<String, dynamic>>().map(SupportMessageInfo.fromJson).toList() : <SupportMessageInfo>[];
    return SupportTicketInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userName: json['user_name']?.toString() ?? 'Пользователь',
      userEmail: json['user_email']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'Обращение',
      status: json['status']?.toString() ?? 'open',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      messages: messages,
    );
  }
}

class Tariff {
  final String code;
  final String icon;
  final String name;
  final int price;
  final String period;
  final String subtitle;
  final String? badge;
  final bool highlighted;

  const Tariff({
    required this.code,
    required this.icon,
    required this.name,
    required this.price,
    required this.period,
    required this.subtitle,
    this.badge,
    this.highlighted = false,
  });

  factory Tariff.fromJson(Map<String, dynamic> json) {
    final code = json['code'].toString();
    final name = json['name'].toString();
    final price = (json['price_rub'] as num?)?.toInt() ?? 0;
    final days = (json['duration_days'] as num?)?.toInt() ?? 0;
    return Tariff(
      code: code,
      icon: _tariffIcon(code),
      name: name,
      price: price,
      period: '$days ДНЕЙ',
      subtitle: json['description']?.toString() ?? _tariffSubtitle(code),
      badge: code == 'ghost_net' ? 'ПОПУЛЯРНЫЙ' : code == 'ghost_ultimate' ? 'ЛУЧШАЯ ЦЕНА' : null,
      highlighted: code == 'ghost_net',
    );
  }
}

String _tariffIcon(String code) {
  switch (code) {
    case 'ghost_start':
      return 'S';
    case 'ghost_plus':
      return 'P';
    case 'ghost_premium':
      return 'PR';
    case 'ghost_ultimate':
      return 'U';
    case 'ghost_net':
    default:
      return 'N';
  }
}


IconData _tariffIconData(String code) {
  switch (code) {
    case 'ghost_start':
      return Icons.bolt_rounded;
    case 'ghost_plus':
      return Icons.rocket_launch_rounded;
    case 'ghost_premium':
      return Icons.diamond_rounded;
    case 'ghost_ultimate':
      return Icons.shield_rounded;
    case 'ghost_net':
    default:
      return Icons.public_rounded;
  }
}

String _tariffSubtitle(String code) {
  switch (code) {
    case 'ghost_start':
      return 'Быстрый старт для проверки сервиса.';
    case 'ghost_plus':
      return 'Выгодный доступ на 3 месяца.';
    case 'ghost_premium':
      return 'Полгода стабильного доступа.';
    case 'ghost_ultimate':
      return 'Максимальная выгода на год.';
    case 'ghost_net':
    default:
      return 'Оптимальный тариф на каждый день.';
  }
}

const tariffs = <Tariff>[
  Tariff(
    code: 'ghost_start',
    icon: 'S',
    name: 'GHOST START',
    price: 150,
    period: '7 ДНЕЙ',
    subtitle: 'Быстрый старт для проверки сервиса.',
  ),
  Tariff(
    code: 'ghost_net',
    icon: 'N',
    name: 'GHOST NET',
    price: 250,
    period: '30 ДНЕЙ',
    subtitle: 'Оптимальный тариф на каждый день.',
    badge: 'ПОПУЛЯРНЫЙ',
    highlighted: true,
  ),
  Tariff(
    code: 'ghost_plus',
    icon: 'P',
    name: 'GHOST PLUS',
    price: 650,
    period: '90 ДНЕЙ',
    subtitle: 'Выгодный доступ на 3 месяца.',
  ),
  Tariff(
    code: 'ghost_premium',
    icon: 'PR',
    name: 'GHOST PREMIUM',
    price: 1200,
    period: '180 ДНЕЙ',
    subtitle: 'Полгода стабильного доступа.',
  ),
  Tariff(
    code: 'ghost_ultimate',
    icon: 'U',
    name: 'GHOST ULTIMATE',
    price: 2100,
    period: '365 ДНЕЙ',
    subtitle: 'Максимальная выгода на год.',
    badge: 'ЛУЧШАЯ ЦЕНА',
  ),
];

class UserProfile {
  final int id;
  final String email;
  final String telegram;
  final String token;
  final bool isActive;
  final bool isAdmin;
  final bool isSupport;

  const UserProfile({
    required this.id,
    required this.email,
    required this.telegram,
    required this.token,
    required this.isActive,
    required this.isAdmin,
    required this.isSupport,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, String token) {
    final email = json['email']?.toString() ?? '';
    final telegram = json['telegram_username']?.toString() ?? '';
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: email,
      telegram: telegram.isEmpty ? 'Telegram не указан' : telegram,
      token: token,
      isActive: json['is_active'] == true,
      isAdmin: json['is_admin'] == true,
      isSupport: json['is_support'] == true,
    );
  }

  String get name {
    final local = email.split('@').first.trim();
    return local.isEmpty ? 'GhostNet User' : local;
  }
}

class SubscriptionInfo {
  final int id;
  final String planCode;
  final String planName;
  final String vpnKeyName;
  final String? vpnKey;
  final String? subscriptionUrl;
  final int deviceLimit;
  final String status;
  final DateTime? expiresAt;

  const SubscriptionInfo({
    required this.id,
    required this.planCode,
    required this.planName,
    required this.vpnKeyName,
    required this.vpnKey,
    required this.subscriptionUrl,
    required this.deviceLimit,
    required this.status,
    required this.expiresAt,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      planCode: json['plan_code']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? 'Подписка',
      vpnKeyName: json['vpn_key_name']?.toString() ?? 'GhostNet Key',
      vpnKey: json['vpn_key']?.toString(),
      subscriptionUrl: json['subscription_url']?.toString(),
      deviceLimit: (json['device_limit'] as num?)?.toInt() ?? 3,
      status: json['status']?.toString() ?? 'active',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
    );
  }
}

String _canonicalSubscriptionUrl(String? value) {
  final raw = value?.trim() ?? '';
  final uri = Uri.tryParse(raw);
  if (uri == null) return raw;
  final normalized = uri.replace(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    fragment: '',
  ).toString();
  return normalized.endsWith('/') ? normalized.substring(0, normalized.length - 1) : normalized;
}

SubscriptionInfo? _findSubscriptionByUrl(List<SubscriptionInfo> subscriptions, String? url) {
  final target = _canonicalSubscriptionUrl(url);
  if (target.isEmpty) return null;
  for (final sub in subscriptions) {
    if (_canonicalSubscriptionUrl(sub.subscriptionUrl) == target) return sub;
  }
  return null;
}

class ManualSubscriptionMeta {
  final String planCode;
  final String planName;
  final DateTime? expiresAt;
  final int deviceLimit;
  final int serverCount;
  final String status;

  const ManualSubscriptionMeta({
    required this.planCode,
    required this.planName,
    required this.expiresAt,
    required this.deviceLimit,
    required this.serverCount,
    required this.status,
  });

  factory ManualSubscriptionMeta.fromSubscription(SubscriptionInfo sub, {int serverCount = 0}) {
    final keyCount = (sub.vpnKey ?? '').split('\n').where((e) => e.trim().isNotEmpty).length;
    return ManualSubscriptionMeta(
      planCode: sub.planCode,
      planName: sub.planName,
      expiresAt: sub.expiresAt,
      deviceLimit: sub.deviceLimit,
      serverCount: serverCount > 0 ? serverCount : keyCount,
      status: sub.status,
    );
  }

  factory ManualSubscriptionMeta.fromVerification(GhostNetSubscriptionVerification verification) {
    final expires = verification.expiresAt;
    return ManualSubscriptionMeta(
      planCode: verification.planCode ?? '',
      planName: verification.planName ?? 'Подписка GhostNet',
      expiresAt: expires,
      deviceLimit: verification.deviceLimit ?? 3,
      serverCount: verification.serverCount,
      status: expires == null || expires.isAfter(DateTime.now().toUtc()) ? 'active' : 'expired',
    );
  }

  factory ManualSubscriptionMeta.fromJson(Map<String, dynamic> json) {
    return ManualSubscriptionMeta(
      planCode: json['plan_code']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? 'Подписка GhostNet',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      deviceLimit: (json['device_limit'] as num?)?.toInt() ?? 3,
      serverCount: (json['server_count'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    'plan_code': planCode,
    'plan_name': planName,
    'expires_at': expiresAt?.toIso8601String(),
    'device_limit': deviceLimit,
    'server_count': serverCount,
    'status': status,
  };

  SubscriptionInfo toSubscription(String url) => SubscriptionInfo(
    id: -1,
    planCode: planCode,
    planName: planName,
    vpnKeyName: 'Импортированная подписка GhostNet',
    vpnKey: null,
    subscriptionUrl: url,
    deviceLimit: deviceLimit,
    status: status,
    expiresAt: expiresAt,
  );

  static Future<ManualSubscriptionMeta?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_manualSubscriptionMetaKey)?.trim() ?? '';
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return ManualSubscriptionMeta.fromJson(decoded);
      if (decoded is Map) return ManualSubscriptionMeta.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {}
    return null;
  }

  static Future<void> save(ManualSubscriptionMeta meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_manualSubscriptionMetaKey, jsonEncode(meta.toJson()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_manualSubscriptionMetaKey);
  }
}

Future<String?> _loadManualSubscriptionUrl() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString(_manualSubscriptionKey)?.trim() ?? '';
  return value.isEmpty ? null : value;
}

String formatDate(DateTime? value) {
  if (value == null) return '—';
  // API stores dates in UTC. If the backend sends a naive timestamp without Z,
  // Dart may treat it as local time. Do not call toUtc() here; simply add GMT+3.
  final msk = value.add(const Duration(hours: 3));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(msk.day)}.${two(msk.month)}.${msk.year} ${two(msk.hour)}:${two(msk.minute)} МСК';
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _loading = true;
  bool _updateCheckScheduled = false;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await AuthTokenStorage.read();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final profile = await GhostApi.me(token);
      unawaited(PushService.registerForUser(token));
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      await AuthTokenStorage.delete();
      if (!mounted) return;
      setState(() {
        _profile = null;
        _loading = false;
      });
    }
  }

  Future<void> _login(String email, String password, bool rememberMe) async {
    final token = await GhostApi.login(email: email, password: password);
    final profile = await GhostApi.me(token);
    await LoginPreferences.save(remember: rememberMe, email: email);
    if (rememberMe) {
      await AuthTokenStorage.write(token);
    } else {
      await AuthTokenStorage.delete();
    }
    unawaited(PushService.registerForUser(token));
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _register(String email, String password, String telegram) async {
    final token = await GhostApi.register(
      email: email,
      password: password,
      telegramUsername: telegram,
    );
    final profile = await GhostApi.me(token);
    await LoginPreferences.save(remember: true, email: email);
    await AuthTokenStorage.write(token);
    unawaited(PushService.registerForUser(token));
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _logout() async {
    await AuthTokenStorage.delete();
    if (!mounted) return;
    setState(() => _profile = null);
  }


  void _scheduleUpdateCheck() {
    if (_updateCheckScheduled) return;
    _updateCheckScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AppUpdateService.check(context));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashScreen();
    _scheduleUpdateCheck();
    if (_profile == null) return RegisterScreen(onLogin: _login, onRegister: _register);
    return MainShell(profile: _profile!, onLogout: _logout);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CyberBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 280, height: 280, child: Image(image: AssetImage('assets/images/logo_full.png'), fit: BoxFit.contain)),
              SizedBox(height: 18),
              SizedBox(width: 180, child: LinearProgressIndicator(minHeight: 3)),
            ],
          ),
        ),
      ),
    );
  }
}


class RegisterScreen extends StatefulWidget {
  final Future<void> Function(String email, String password, bool rememberMe) onLogin;
  final Future<void> Function(String email, String password, String telegram) onRegister;

  const RegisterScreen({super.key, required this.onLogin, required this.onRegister});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _telegram = TextEditingController();
  bool _saving = false;
  bool _registerMode = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadLoginPreferences();
  }

  Future<void> _loadLoginPreferences() async {
    final remember = await LoginPreferences.rememberMe();
    final email = remember ? await LoginPreferences.rememberedEmail() : '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (email.isNotEmpty) _email.text = email;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _telegram.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    final password = _password.text.trim();
    var telegram = _telegram.text.trim();
    if (telegram.isNotEmpty && !telegram.startsWith('@')) telegram = '@$telegram';

    if (!email.contains('@') || password.length < 6) {
      _showSnack(context, 'Введите email и пароль минимум 6 символов.');
      return;
    }
    if (_registerMode && telegram.length < 4) {
      _showSnack(context, 'Для регистрации укажите Telegram username.');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_registerMode) {
        await widget.onRegister(email, password, telegram);
        if (mounted) _showSnack(context, 'Аккаунт создан.');
      } else {
        await widget.onLogin(email, password, _rememberMe);
        if (mounted) _showSnack(context, 'Вход выполнен.');
      }
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: CyberBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final isPhone = width < 620;
            final isTiny = width < 380 || height < 720;
            final formWidth = isPhone ? double.infinity : 430.0;
            final horizontalPadding = width < 360 ? 14.0 : 20.0;
            final titleSize = width < 360 ? 26.0 : 30.0;

            final form = PremiumCard(
              padding: EdgeInsets.all(isTiny ? 18 : 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      LogoOrb(size: isTiny ? 58 : 66),
                      const SizedBox(width: 12),
                      const Expanded(child: LogoTitleBlock(compact: true)),
                    ],
                  ),
                  SizedBox(height: isTiny ? 18 : 22),
                  _AuthSwitcher(
                    registerMode: _registerMode,
                    onChanged: (value) => setState(() => _registerMode = value),
                  ),
                  SizedBox(height: isTiny ? 16 : 20),
                  Text(
                    _registerMode ? 'Создать аккаунт' : 'Вход в аккаунт',
                    style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, height: 1.08),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _registerMode
                        ? 'Регистрация идёт через твой GhostNet API.'
                        : 'Введите email и пароль от личного кабинета.',
                    style: const TextStyle(color: GhostColors.muted, height: 1.45),
                  ),
                  SizedBox(height: isTiny ? 18 : 22),
                  GhostTextField(controller: _email, label: 'Email', icon: Icons.email_rounded),
                  const SizedBox(height: 14),
                  GhostTextField(controller: _password, label: 'Пароль', icon: Icons.lock_rounded, obscureText: true),
                  if (!_registerMode) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _saving ? null : () => setState(() => _rememberMe = !_rememberMe),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: _saving ? null : (value) => setState(() => _rememberMe = value ?? false),
                              activeColor: GhostColors.orange,
                              checkColor: GhostColors.black,
                              side: BorderSide(color: GhostColors.orange.withOpacity(.65), width: 1.4),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Запомнить меня',
                                style: TextStyle(fontWeight: FontWeight.w800, color: GhostColors.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_registerMode) ...[
                    const SizedBox(height: 14),
                    GhostTextField(controller: _telegram, label: 'Telegram username', icon: Icons.alternate_email_rounded),
                  ],
                  SizedBox(height: isTiny ? 18 : 22),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: _saving ? 'Подключаемся...' : (_registerMode ? 'Зарегистрироваться' : 'Войти'),
                      icon: _registerMode ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                  if (!isTiny) ...[
                    const SizedBox(height: 18),
                    const _LoginAdvantages(),
                  ],
                ],
              ),
            );

            if (isPhone) {
              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: formWidth, minHeight: height - 46),
                    child: Center(child: form),
                  ),
                ),
              );
            }

            return Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(flex: 5, child: RegisterHero()),
                      const SizedBox(width: 22),
                      SizedBox(width: formWidth, child: form),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthSwitcher extends StatelessWidget {
  final bool registerMode;
  final ValueChanged<bool> onChanged;

  const _AuthSwitcher({required this.registerMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Row(
        children: [
          Expanded(child: _AuthTab(text: 'Вход', selected: !registerMode, onTap: () => onChanged(false))),
          Expanded(child: _AuthTab(text: 'Регистрация', selected: registerMode, onTap: () => onChanged(true))),
        ],
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _AuthTab({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected ? const LinearGradient(colors: [GhostColors.orange, GhostColors.gold]) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.black : GhostColors.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LoginAdvantages extends StatelessWidget {
  const _LoginAdvantages();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        FeaturePill(icon: Icons.flash_on_rounded, text: 'Быстро'),
        FeaturePill(icon: Icons.devices_rounded, text: '3 устройства'),
        FeaturePill(icon: Icons.all_inclusive_rounded, text: 'Безлимит'),
      ],
    );
  }
}

class RegisterHero extends StatelessWidget {
  const RegisterHero({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LogoHeader(compact: false),
          const SizedBox(height: 28),
          Builder(
            builder: (context) {
              final width = MediaQuery.sizeOf(context).width;
              final size = width < 900 ? 32.0 : 38.0;
              return Text(
                'Защищённый доступ\nв одном приложении',
                style: TextStyle(fontSize: size, height: 1.05, fontWeight: FontWeight.w900),
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'Покупайте подписку, управляйте ключами и открывайте поддержку без лишних действий.',
            style: TextStyle(color: GhostColors.muted, height: 1.5, fontSize: 15),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              FeaturePill(icon: Icons.flash_on_rounded, text: 'Быстро'),
              FeaturePill(icon: Icons.devices_rounded, text: '3 устройства'),
              FeaturePill(icon: Icons.all_inclusive_rounded, text: 'Безлимит'),
            ],
          ),
          const SizedBox(height: 28),
          const HeroPreviewCard(),
        ],
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onLogout;

  const MainShell({super.key, required this.profile, required this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingPayment());
  }

  Future<void> _checkPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final paymentId = prefs.getInt(_pendingPaymentKey);
    if (paymentId == null || !mounted) return;
    final result = await showPaymentStatusDialog(context, widget.profile.token, paymentId);
    await prefs.remove(_pendingPaymentKey);
    if (result == true && mounted) setState(() => _index = 2);
  }

  @override
  Widget build(BuildContext context) {
    final showAdmin = widget.profile.isAdmin || widget.profile.isSupport;
    final pages = [
      HomePage(profile: widget.profile, onOpenTariffs: () => setState(() => _index = 1), onOpenAccount: () => setState(() => _index = 2), onOpenGuide: () => setState(() => _index = 3), onOpenSupport: () => setState(() => _index = 4), onOpenNews: () => openExternal(newsUrl)),
      TariffsPage(profile: widget.profile, onOpenAccount: () => setState(() => _index = 2)),
      AccountPage(profile: widget.profile, onLogout: widget.onLogout, onOpenTariffs: () => setState(() => _index = 1), onOpenSupport: () => setState(() => _index = 4)),
      InstructionsPage(profile: widget.profile, onOpenAccount: () => setState(() => _index = 2), onOpenTariffs: () => setState(() => _index = 1)),
      HelpPage(profile: widget.profile),
      if (showAdmin) AdminPage(profile: widget.profile),
    ];
    if (_index >= pages.length) _index = 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Scaffold(
            body: CyberBackground(
              child: Row(
                children: [
                  GhostSideBar(index: _index, showAdmin: showAdmin, onSelect: (v) => setState(() => _index = v)),
                  Expanded(child: pages[_index]),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: CyberBackground(child: pages[_index]),
          bottomNavigationBar: GhostBottomNav(index: _index, showAdmin: showAdmin, onSelect: (v) => setState(() => _index = v)),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onOpenTariffs;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenNews;

  const HomePage({super.key, required this.profile, required this.onOpenTariffs, required this.onOpenAccount, required this.onOpenGuide, required this.onOpenSupport, required this.onOpenNews});

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderBar(profile: profile),
          const SizedBox(height: 18),
          HomeHeroCard(profile: profile, onOpenTariffs: onOpenTariffs, onOpenAccount: onOpenAccount),
          const SizedBox(height: 16),
          QuickActionsGrid(onOpenTariffs: onOpenTariffs, onOpenAccount: onOpenAccount, onOpenGuide: onOpenGuide, onOpenSupport: onOpenSupport, onOpenNews: onOpenNews),
          const SizedBox(height: 16),
          const StatsGrid(),
          const SizedBox(height: 18),
          const SectionTitle(title: 'Преимущества сервиса', subtitle: 'Всё, что нужно для комфортного подключения.'),
          const SizedBox(height: 12),
          const AdvantageGrid(),
        ],
      ),
    );
  }
}


class VpnServerItem {
  final String name;
  final String link;
  final String? subscriptionUrl;

  const VpnServerItem({required this.name, required this.link, this.subscriptionUrl});
}

class VpnPage extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onOpenTariffs;
  final VoidCallback onOpenAccount;

  const VpnPage({super.key, required this.profile, required this.onOpenTariffs, required this.onOpenAccount});

  @override
  State<VpnPage> createState() => _VpnPageState();
}

class _VpnPageState extends State<VpnPage> {
  bool _loading = true;
  String? _error;
  List<VpnServerItem> _servers = const [];
  List<SubscriptionInfo> _subscriptions = const [];
  final TextEditingController _manualSubscriptionController = TextEditingController();
  String? _manualSubscriptionUrl;
  bool _importingSubscription = false;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _manualSubscriptionController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedManualUrl = prefs.getString(_manualSubscriptionKey)?.trim();
      _manualSubscriptionUrl = savedManualUrl != null && savedManualUrl.isNotEmpty ? savedManualUrl : null;
      _manualSubscriptionController.text = _manualSubscriptionUrl ?? '';

      final subs = await GhostApi.mySubscriptions(widget.profile.token);
      final servers = await _loadServers(subs);
      if (!mounted) return;
      setState(() {
        _subscriptions = subs;
        _servers = servers;
        _loading = false;
        if (_selected >= _servers.length) _selected = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<List<VpnServerItem>> _loadServers(List<SubscriptionInfo> subs) async {
    final parsed = <VpnServerItem>[];
    final seen = <String>{};

    Future<void> addLink(String link, {String? name, String? subscriptionUrl}) async {
      final clean = link.trim();
      if (clean.isEmpty || seen.contains(clean)) return;
      seen.add(clean);
      final parsedNameRaw = (name ?? '').trim().isNotEmpty ? name!.trim() : _nameFromLink(clean);
      final parsedName = _normalizeServerName(parsedNameRaw);
      parsed.add(VpnServerItem(name: parsedName, link: clean, subscriptionUrl: subscriptionUrl));
    }

    final manualUrl = _manualSubscriptionUrl?.trim();
    if (manualUrl != null && manualUrl.isNotEmpty && isGhostNetSubscriptionUrl(manualUrl)) {
      try {
        await _appendSubscriptionServers(manualUrl, addLink);
      } catch (_) {
        // Старая или временно недоступная импортированная ссылка не должна ломать ключи из аккаунта.
      }
    }

    try {
      final apiServers = await GhostApi.vpnServers(widget.profile.token);
      for (final item in apiServers) {
        final link = (item['link'] ?? item['raw_link'] ?? '').toString().trim();
        if (link.isEmpty) continue;
        final name = (item['name'] ?? '').toString().trim();
        await addLink(link, name: name.isEmpty ? null : name);
      }
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // Если endpoint /api/vpn/servers недоступен, используем подписки из кабинета.
    }

    final activeSubs = subs.where((sub) => sub.status == 'active').toList();

    for (final sub in activeSubs) {
      final key = sub.vpnKey ?? '';
      for (final link in _extractShareLinks(key)) {
        await addLink(link, subscriptionUrl: sub.subscriptionUrl);
      }
    }

    for (final sub in activeSubs) {
      final url = sub.subscriptionUrl?.trim() ?? '';
      if (url.isEmpty) continue;
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = _decodeSubscriptionPayload(utf8.decode(response.bodyBytes));
          for (final link in _extractShareLinks(decoded)) {
            await addLink(link, subscriptionUrl: url);
          }
        }
      } catch (_) {}
    }

    return parsed;
  }

  Future<int> _appendSubscriptionServers(
    String url,
    Future<void> Function(String link, {String? name, String? subscriptionUrl}) addLink,
  ) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const FormatException('Ссылка GhostNet недоступна.');
    }
    final decoded = _decodeSubscriptionPayload(utf8.decode(response.bodyBytes));
    final links = _extractShareLinks(decoded);
    for (final link in links) {
      await addLink(link, subscriptionUrl: url);
    }
    return links.length;
  }

  Future<void> _pasteManualSubscription() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (value.isEmpty) {
      if (mounted) _showSnack(context, 'В буфере обмена нет ссылки.');
      return;
    }
    _manualSubscriptionController.text = value;
  }

  Future<void> _saveManualSubscription() async {
    final value = _manualSubscriptionController.text.trim();
    if (!isGhostNetSubscriptionUrl(value)) {
      _showSnack(context, 'Можно добавить только HTTPS-ссылку подписки GhostNet.');
      return;
    }

    setState(() => _importingSubscription = true);
    try {
      final links = <String>[];
      Future<void> collect(String link, {String? name, String? subscriptionUrl}) async {
        if (!links.contains(link)) links.add(link);
      }
      final count = await _appendSubscriptionServers(value, collect);
      if (count == 0) {
        throw const FormatException('Ссылка не содержит серверов GhostNet.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_manualSubscriptionKey, value);
      _manualSubscriptionUrl = value;
      if (mounted) _showSnack(context, 'Подписка GhostNet добавлена.');
      await _initialize();
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('FormatException: ', '').replaceFirst('Exception: ', '');
        _showSnack(context, message.isEmpty ? 'Не удалось проверить подписку.' : message);
      }
    } finally {
      if (mounted) setState(() => _importingSubscription = false);
    }
  }

  Future<void> _removeManualSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить подписку?'),
        content: const Text(
          'Импортированная ссылка, тариф и сохранённые данные будут удалены только с этого устройства. Подписка в аккаунте GhostNet останется активной.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить', style: TextStyle(color: GhostColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_manualSubscriptionKey);
    await ManualSubscriptionMeta.clear();
    manualSubscriptionRevision.value++;
    _manualSubscriptionUrl = null;
    _manualSubscriptionController.clear();
    if (mounted) _showSnack(context, 'Импортированная подписка удалена с устройства.');
    await _initialize();
  }

  List<String> _extractShareLinks(String source) {
    final result = <String>[];
    final lines = source
        .replaceAll('\r', '\n')
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('vless://') || lower.startsWith('vmess://') || lower.startsWith('trojan://') || lower.startsWith('ss://')) {
        result.add(line);
      }
    }
    return result;
  }

  String _decodeSubscriptionPayload(String text) {
    final trimmed = text.trim();
    if (trimmed.contains('://')) return trimmed;
    try {
      var normalized = trimmed.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
      final padding = normalized.length % 4;
      if (padding > 0) normalized += List.filled(4 - padding, '=').join();
      return utf8.decode(base64Decode(normalized));
    } catch (_) {
      return trimmed;
    }
  }

  String _normalizeServerName(String value) {
    final clean = value.trim();
    final lower = clean.toLowerCase();
    if (lower.contains('белые') || lower.contains('white') || lower.contains('whitelist')) {
      return '🇨🇿 Прага';
    }
    return clean;
  }

  String _nameFromLink(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return 'Сервер GhostNet';
    if (uri.fragment.isNotEmpty) {
      try {
        final decoded = Uri.decodeComponent(uri.fragment).trim();
        if (decoded.isNotEmpty) return _normalizeServerName(decoded);
      } catch (_) {
        if (uri.fragment.trim().isNotEmpty) return _normalizeServerName(uri.fragment.trim());
      }
    }
    final host = uri.host.trim();
    if (host.isNotEmpty) return _normalizeServerName(host);
    return 'Сервер GhostNet';
  }

  Future<void> _copy(String? value, String message) async {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) {
      _showSnack(context, 'Пока нечего копировать.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: clean));
    if (mounted) _showSnack(context, message);
  }

  String? get _activeSubscriptionUrl {
    final selected = _servers.isNotEmpty ? _servers[_selected].subscriptionUrl : null;
    if (selected != null && selected.trim().isNotEmpty) return selected;
    for (final sub in _subscriptions) {
      final url = sub.subscriptionUrl?.trim();
      if (sub.status == 'active' && url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            title: 'GhostNet VPN',
            subtitle: 'Рабочие ключи доступны здесь. Встроенный VPN переводим на новый core, чтобы не было фейкового подключения.',
          ),
          const SizedBox(height: 16),
          _buildCoreNotice(),
          const SizedBox(height: 16),
          _buildVpnCard(),
          const SizedBox(height: 16),
          _buildServerList(),
        ],
      ),
    );
  }

  Widget _buildCoreNotice() {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          MiniBadge(text: 'VPN CORE'),
          SizedBox(height: 14),
          Text('Встроенный VPN в разработке', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text(
            'Серверы и ключи рабочие. Hiddify, Happ и v2RayTun подключаются с этими ключами. Старый встроенный модуль отключён, потому что он показывал таймер без реального подключения. Следующая версия будет на sing-box / libbox core.',
            style: TextStyle(color: GhostColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildManualSubscriptionCard() {
    final hasImported = _manualSubscriptionUrl != null && _manualSubscriptionUrl!.isNotEmpty;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MiniBadge(text: 'ИМПОРТ GHOSTNET'),
          const SizedBox(height: 12),
          const Text('Добавить ссылку подписки', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Принимаются только проверенные HTTPS-ссылки sub.ghostnetcyber.ru. Сторонние подписки и отдельные VLESS/VMess-ссылки будут отклонены.',
            style: TextStyle(color: GhostColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _manualSubscriptionController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'https://sub.ghostnetcyber.ru/...',
              prefixIcon: const Icon(Icons.link_rounded, color: GhostColors.orange),
              suffixIcon: IconButton(
                tooltip: 'Вставить из буфера',
                onPressed: _importingSubscription ? null : _pasteManualSubscription,
                icon: const Icon(Icons.content_paste_rounded),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(.24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GhostColors.orange)),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final add = PrimaryButton(
                text: _importingSubscription ? 'Проверяем...' : (hasImported ? 'Обновить ссылку' : 'Добавить подписку'),
                icon: Icons.add_link_rounded,
                onPressed: _importingSubscription ? null : _saveManualSubscription,
              );
              final remove = SecondaryButton(
                text: 'Удалить подписку',
                icon: Icons.delete_outline_rounded,
                danger: true,
                onPressed: _importingSubscription || !hasImported ? null : _removeManualSubscription,
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Center(child: add), if (hasImported) ...[const SizedBox(height: 10), Center(child: remove)]],
                );
              }
              return Wrap(spacing: 10, runSpacing: 10, children: [add, if (hasImported) remove]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVpnCard() {
    if (_loading) {
      return const PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MiniBadge(text: 'КЛЮЧИ'),
            SizedBox(height: 14),
            Text('Загружаем серверы...', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 14),
            LinearProgressIndicator(minHeight: 3),
          ],
        ),
      );
    }

    if (_error != null) {
      return PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MiniBadge(text: 'КЛЮЧИ'),
            const SizedBox(height: 14),
            const Text('Не удалось загрузить ключи', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: GhostColors.gold, height: 1.45)),
            const SizedBox(height: 16),
            PrimaryButton(text: 'Обновить', icon: Icons.refresh_rounded, onPressed: _initialize),
          ],
        ),
      );
    }

    final hasServers = _servers.isNotEmpty;
    final selectedServer = hasServers ? _servers[_selected] : null;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MiniBadge(text: 'ПОДКЛЮЧЕНИЕ'),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [GhostColors.orange, GhostColors.gold]),
                  boxShadow: [BoxShadow(color: GhostColors.orange.withOpacity(.35), blurRadius: 24)],
                ),
                child: const Icon(Icons.vpn_key_rounded, color: Colors.black, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Подключение через внешний клиент', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      selectedServer == null ? 'Получите подписку, чтобы появились ключи.' : 'Выбран сервер: ${selectedServer.name}',
                      style: const TextStyle(color: GhostColors.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasServers) ...[
            const Text('После оплаты или пробного доступа серверы появятся здесь автоматически.', style: TextStyle(color: GhostColors.muted, height: 1.45)),
            const SizedBox(height: 16),
            PrimaryButton(text: 'Приобрести подписку', icon: Icons.shopping_cart_rounded, onPressed: widget.onOpenTariffs),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 520;
                final copyServer = PrimaryButton(
                  text: 'Скопировать сервер',
                  icon: Icons.copy_rounded,
                  onPressed: () => _copy(selectedServer!.link, 'VLESS-сервер скопирован.'),
                );
                final copySub = SecondaryButton(
                  text: 'Скопировать подписку',
                  icon: Icons.link_rounded,
                  onPressed: () => _copy(_activeSubscriptionUrl, 'Ссылка подписки скопирована.'),
                );
                final refresh = SecondaryButton(text: 'Обновить', icon: Icons.refresh_rounded, onPressed: _initialize);
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: copyServer),
                      const SizedBox(height: 10),
                      Center(child: copySub),
                      const SizedBox(height: 10),
                      Center(child: refresh),
                    ],
                  );
                }
                return Wrap(spacing: 10, runSpacing: 10, children: [copyServer, copySub, refresh]);
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'Скопируйте подписку и добавьте её в Happ, Hiddify или v2RayTun. Эти клиенты уже подключаются к вашим серверам и показывают клиента онлайн в 3x-ui.',
              style: TextStyle(color: GhostColors.muted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServerList() {
    if (_loading || _servers.isEmpty) return const SizedBox.shrink();
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MiniBadge(text: 'СЕРВЕРЫ'),
          const SizedBox(height: 14),
          ...List.generate(_servers.length, (i) {
            final server = _servers[i];
            final active = i == _selected;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selected = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: active ? GhostColors.orange.withOpacity(.16) : Colors.black.withOpacity(.2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: active ? GhostColors.orange.withOpacity(.8) : Colors.white.withOpacity(.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: active ? GhostColors.orange : GhostColors.muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(server.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                      IconButton(
                        tooltip: 'Скопировать сервер',
                        onPressed: () => _copy(server.link, 'VLESS-сервер скопирован.'),
                        icon: const Icon(Icons.copy_rounded),
                        color: active ? GhostColors.orange : GhostColors.muted,
                      ),
                      if (active) const Icon(Icons.check_circle_rounded, color: GhostColors.success),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class TariffsPage extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onOpenAccount;

  const TariffsPage({super.key, required this.profile, required this.onOpenAccount});

  @override
  State<TariffsPage> createState() => _TariffsPageState();
}

class _TariffsPageState extends State<TariffsPage> {
  final _promo = TextEditingController(text: 'WELCOME');
  String? _appliedPromo = 'WELCOME';
  String? _promoMessage = 'WELCOME будет применён при оплате.';
  List<Tariff> _plans = tariffs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await GhostApi.plans();
      if (!mounted) return;
      setState(() {
        if (plans.isNotEmpty) _plans = plans;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить тарифы. Показываем сохранённые.';
      });
    }
  }


  Future<void> _applyPromo() async {
    final code = _promo.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _appliedPromo = null;
        _promoMessage = 'Промокод очищен.';
      });
      return;
    }
    try {
      final result = await GhostApi.checkPromocode(token: widget.profile.token, code: code, planCode: 'ghost_net');
      if (!mounted) return;
      setState(() {
        _appliedPromo = result.valid ? code : null;
        _promoMessage = result.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedPromo = null;
        _promoMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _buy(Tariff tariff) async {
    final promo = (_appliedPromo ?? '').trim().isEmpty ? null : _appliedPromo!.trim().toUpperCase();
    try {
      final payment = await GhostApi.createPayment(token: widget.profile.token, planCode: tariff.code, promocode: promo);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_pendingPaymentKey, payment.paymentId);
      await openExternal(payment.confirmationUrl);
      if (!mounted) return;
      final result = await showPaymentStatusDialog(context, widget.profile.token, payment.paymentId);
      await prefs.remove(_pendingPaymentKey);
      if (result == true && mounted) {
        widget.onOpenAccount();
      }
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(title: 'Тарифы GhostNet', subtitle: 'Покупка проходит через ЮKassa. После успешной оплаты подписка появится в кабинете.'),
          const SizedBox(height: 16),
          PromoPanel(controller: _promo, appliedCode: _appliedPromo, message: _promoMessage, onApply: _applyPromo, onClear: () {
            setState(() {
              _promo.clear();
              _appliedPromo = null;
              _promoMessage = 'Промокод очищен.';
            });
          }),
          if (_loading) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: GhostColors.gold, fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final grid = constraints.maxWidth >= 760;
              if (!grid) {
                return Column(
                  children: _plans.map((tariff) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TariffCard(tariff: tariff, onBuy: () => _buy(tariff)),
                  )).toList(),
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _plans.map((tariff) {
                  return SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: TariffCard(tariff: tariff, onBuy: () => _buy(tariff)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onLogout;
  final VoidCallback onOpenTariffs;
  final VoidCallback onOpenSupport;

  const AccountPage({super.key, required this.profile, required this.onLogout, required this.onOpenTariffs, required this.onOpenSupport});

  Future<void> _openNotifications(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => NotificationsDialog(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(title: 'Личный кабинет', subtitle: 'Профиль, подписка, ключи и быстрые действия.'),
          const SizedBox(height: 16),
          AccountHero(profile: profile),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 720;
              final status = SubscriptionStatusCard(profile: profile, onOpenTariffs: onOpenTariffs);
              final actions = AccountActions(onLogout: onLogout, onOpenTariffs: onOpenTariffs, onOpenSupport: onOpenSupport, onOpenNotifications: () => _openNotifications(context));
              if (!wide) return Column(children: [status, const SizedBox(height: 16), actions]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SubscriptionStatusCard(profile: profile, onOpenTariffs: onOpenTariffs)),
                  const SizedBox(width: 16),
                  Expanded(child: AccountActions(onLogout: onLogout, onOpenTariffs: onOpenTariffs, onOpenSupport: onOpenSupport, onOpenNotifications: () => _openNotifications(context))),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ManualSubscriptionImportCard(profile: profile),
          const SizedBox(height: 16),
          ReferralProgramCard(profile: profile),
        ],
      ),
    );
  }
}


class ManualSubscriptionImportCard extends StatefulWidget {
  final UserProfile profile;

  const ManualSubscriptionImportCard({super.key, required this.profile});

  @override
  State<ManualSubscriptionImportCard> createState() => _ManualSubscriptionImportCardState();
}

class _ManualSubscriptionImportCardState extends State<ManualSubscriptionImportCard> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _savedUrl;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_manualSubscriptionKey)?.trim();
    if (!mounted) return;
    setState(() {
      _savedUrl = value != null && value.isNotEmpty ? value : null;
      _controller.text = _savedUrl ?? '';
      _loading = false;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (value.isEmpty) {
      if (mounted) _showSnack(context, 'В буфере обмена нет ссылки.');
      return;
    }
    _controller.text = value;
    setState(() {
      _message = null;
      _success = false;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (!isGhostNetSubscriptionUrl(value)) {
      setState(() {
        _message = 'Вставьте ссылку вида https://sub.ghostnetcyber.ru/...';
        _success = false;
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = 'Проверяем ссылку и серверы GhostNet...';
      _success = false;
    });
    try {
      final verification = await _verifyGhostNetSubscriptionUrl(value);
      SubscriptionInfo? matched;
      try {
        final subscriptions = await GhostApi.mySubscriptions(widget.profile.token);
        matched = _findSubscriptionByUrl(subscriptions, value);
      } catch (_) {}
      final meta = matched != null
          ? ManualSubscriptionMeta.fromSubscription(matched, serverCount: verification.serverCount)
          : ManualSubscriptionMeta.fromVerification(verification);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_manualSubscriptionKey, value);
      await ManualSubscriptionMeta.save(meta);
      manualSubscriptionRevision.value++;
      if (!mounted) return;
      setState(() {
        _savedUrl = value;
        _message = 'Подписка сохранена. Тариф: ${meta.planName}. Серверов: ${meta.serverCount}.';
        _success = true;
      });
      _showSnack(context, 'Тариф ${meta.planName} добавлен в кабинет.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.toString().replaceFirst('FormatException: ', '').replaceFirst('Exception: ', '');
        _success = false;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить вставленную подписку?'),
        content: const Text(
          'Ссылка, определённый тариф и локальный кэш будут удалены с этого устройства. Реальная подписка в аккаунте GhostNet не удаляется и не отменяется.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить', style: TextStyle(color: GhostColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_manualSubscriptionKey);
      await ManualSubscriptionMeta.clear();
      manualSubscriptionRevision.value++;
      if (!mounted) return;
      setState(() {
        _savedUrl = null;
        _controller.clear();
        _message = 'Вставленная подписка удалена с этого устройства.';
        _success = true;
      });
      _showSnack(context, 'Вставленная подписка удалена.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSaved = _savedUrl != null && _savedUrl!.isNotEmpty;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MiniBadge(text: 'МОИ КЛЮЧИ'),
          const SizedBox(height: 12),
          const Text('Добавить подписку GhostNet', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
            'Можно вставить только ссылку подписки с домена sub.ghostnetcyber.ru. Ссылка будет проверена перед сохранением.',
            style: TextStyle(color: GhostColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            enabled: !_loading && !_saving,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: 'https://sub.ghostnetcyber.ru/...',
              prefixIcon: const Icon(Icons.link_rounded, color: GhostColors.orange),
              suffixIcon: IconButton(
                tooltip: 'Вставить из буфера',
                onPressed: _loading || _saving ? null : _paste,
                icon: const Icon(Icons.content_paste_rounded),
              ),
              filled: true,
              fillColor: Colors.black.withOpacity(.24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(.08))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(.08))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GhostColors.orange)),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: TextStyle(color: _success ? GhostColors.success : GhostColors.gold, height: 1.35, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final save = PrimaryButton(
                text: _saving ? 'Проверяем...' : (hasSaved ? 'Обновить ссылку' : 'Добавить подписку'),
                icon: Icons.add_link_rounded,
                onPressed: _loading || _saving ? null : _save,
              );
              final remove = SecondaryButton(
                text: 'Удалить подписку',
                icon: Icons.delete_outline_rounded,
                danger: true,
                onPressed: _loading || _saving || !hasSaved ? null : _remove,
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [save, if (hasSaved) ...[const SizedBox(height: 10), remove]],
                );
              }
              return Wrap(spacing: 10, runSpacing: 10, children: [save, if (hasSaved) remove]);
            },
          ),
        ],
      ),
    );
  }
}

class ReferralProgramCard extends StatefulWidget {
  final UserProfile profile;

  const ReferralProgramCard({super.key, required this.profile});

  @override
  State<ReferralProgramCard> createState() => _ReferralProgramCardState();
}

class _ReferralProgramCardState extends State<ReferralProgramCard> {
  final _code = TextEditingController();
  ReferralInfo? _info;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await GhostApi.referralMe(widget.profile.token);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showSnack(context, message);
  }

  Future<void> _apply() async {
    final code = _code.text.trim().toUpperCase();
    if (code.length < 3) {
      _showSnack(context, 'Введите реферальный код.');
      return;
    }
    setState(() => _saving = true);
    try {
      final message = await GhostApi.applyReferralCode(token: widget.profile.token, code: code);
      _code.clear();
      await _load();
      if (mounted) _showSnack(context, message);
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    return PremiumCard(
      highlighted: true,
      padding: const EdgeInsets.all(12),
      child: _loading
          ? const LinearProgressIndicator(minHeight: 3)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CircleIcon(icon: Icons.group_add_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Реферальная система', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1.1)),
                          SizedBox(height: 3),
                          Text('Приглашай друзей — получай +7 дней.', style: TextStyle(color: GhostColors.muted, fontSize: 12, height: 1.25)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (info != null) ...[
                  const SizedBox(height: 11),
                  _ReferralValueRow(
                    label: 'ТВОЙ КОД',
                    value: info.code,
                    accent: true,
                    icon: Icons.copy_rounded,
                    tooltip: 'Скопировать код',
                    onPressed: () => _copy(info.code, 'Реферальный код скопирован.'),
                  ),
                  const SizedBox(height: 7),
                  _ReferralValueRow(
                    label: 'ССЫЛКА',
                    value: info.shareUrl,
                    icon: Icons.link_rounded,
                    tooltip: 'Скопировать ссылку',
                    onPressed: () => _copy(info.shareUrl, 'Реферальная ссылка скопирована.'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _ReferralCompactStat(icon: Icons.person_add_alt_1_rounded, value: '${info.invitedTotal}', label: 'Приглашено')),
                      const SizedBox(width: 6),
                      Expanded(child: _ReferralCompactStat(icon: Icons.payments_rounded, value: '${info.paidTotal}', label: 'Оплатили')),
                      const SizedBox(width: 6),
                      Expanded(child: _ReferralCompactStat(icon: Icons.card_giftcard_rounded, value: '+${info.bonusDaysTotal}', label: 'Дней')),
                    ],
                  ),
                  if ((info.referredByCode ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ReferralStatusBox(
                      icon: Icons.verified_rounded,
                      text: 'Применён код ${info.referredByCode}${(info.referredByEmail ?? '').isNotEmpty ? ' · ${info.referredByEmail}' : ''}',
                    ),
                  ] else if (info.canApplyCode) ...[
                    const SizedBox(height: 9),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final horizontal = constraints.maxWidth >= 380;
                        final field = GhostTextField(
                          controller: _code,
                          label: 'Код друга',
                          icon: Icons.confirmation_number_rounded,
                        );
                        final button = PrimaryButton(
                          text: _saving ? '...' : 'Применить',
                          icon: Icons.check_rounded,
                          onPressed: _saving ? null : _apply,
                        );
                        if (horizontal) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: field),
                              const SizedBox(width: 8),
                              button,
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            field,
                            const SizedBox(height: 8),
                            Center(child: button),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _ReferralValueRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool accent;

  const _ReferralValueRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(11, 7, 5, 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ? GhostColors.orange.withOpacity(.25) : Colors.white.withOpacity(.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(color: GhostColors.muted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    color: accent ? GhostColors.orangeSoft : GhostColors.text,
                    fontSize: accent ? 17 : 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: accent ? .8 : 0,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Tooltip(
            message: tooltip,
            child: Material(
              color: GhostColors.orange.withOpacity(.11),
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: onPressed,
                child: SizedBox(width: 36, height: 36, child: Icon(icon, color: GhostColors.orange, size: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralCompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ReferralCompactStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.035),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: GhostColors.orange, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, maxLines: 1, style: const TextStyle(color: GhostColors.orangeSoft, fontSize: 13, fontWeight: FontWeight.w900, height: 1)),
                const SizedBox(height: 3),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GhostColors.muted, fontSize: 8, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralStatusBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReferralStatusBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: GhostColors.success.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GhostColors.success.withOpacity(.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: GhostColors.success, size: 17),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: const TextStyle(color: GhostColors.success, fontSize: 11, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _ReferralMiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ReferralMiniStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(14), border: Border.all(color: GhostColors.orange.withOpacity(.18))),
      child: Row(children: [
        Icon(icon, color: GhostColors.orange, size: 18),
        const SizedBox(width: 7),
        Text(value, style: const TextStyle(color: GhostColors.orangeSoft, fontWeight: FontWeight.w900)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: GhostColors.muted, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
    );
  }
}


class InstructionsPage extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenTariffs;

  const InstructionsPage({super.key, required this.profile, required this.onOpenAccount, required this.onOpenTariffs});

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderBar(profile: profile),
          const SizedBox(height: 18),
          const PageTitle(title: 'Как подключиться', subtitle: 'Скопируйте ссылку подписки из кабинета и добавьте её в удобный VPN-клиент.'),
          const SizedBox(height: 16),
          PremiumCard(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MiniBadge(text: 'БЫСТРЫЙ СТАРТ'),
                const SizedBox(height: 12),
                const Text('Сначала получите ключ в кабинете', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('После покупки или пробного доступа откройте «Мои ключи» и скопируйте ссылку подписки. Она подойдёт для Hiddify, Happ, v2RayTun, V2Box и других клиентов.', style: TextStyle(color: GhostColors.muted, height: 1.45)),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  PrimaryButton(text: 'Мои ключи', icon: Icons.vpn_key_rounded, onPressed: onOpenAccount),
                  SecondaryButton(text: 'Приобрести подписку', icon: Icons.shopping_cart_rounded, onPressed: onOpenTariffs),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 620 ? 2 : 1;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            final cards = const [
              GuidePlatformCard(
                icon: Icons.android_rounded,
                title: 'Android',
                client: 'Hiddify / Happ / v2RayTun',
                steps: ['Скопируйте ссылку подписки', 'Откройте VPN-клиент и нажмите +', 'Выберите импорт из буфера / URL', 'Сохраните профиль и подключитесь'],
              ),
              GuidePlatformCard(
                icon: Icons.desktop_windows_rounded,
                title: 'Windows',
                client: 'Hiddify Desktop',
                steps: ['Скопируйте ссылку подписки', 'Откройте Hiddify', 'Нажмите Новый профиль', 'Вставьте ссылку и подключитесь'],
              ),
              GuidePlatformCard(
                icon: Icons.phone_iphone_rounded,
                title: 'iPhone / iOS',
                client: 'V2Box / Streisand',
                steps: ['Скопируйте ссылку подписки', 'Откройте клиент', 'Добавьте подписку по URL', 'Выберите сервер и включите VPN'],
              ),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards.map((card) => SizedBox(width: width, child: card)).toList(),
            );
          }),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              MiniBadge(text: 'ВАЖНО'),
              SizedBox(height: 12),
              Text('Если серверы не появились', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Обновите подписку в VPN-клиенте вручную: профиль GhostNet → Обновить / Refresh subscription. Старую ссылку удалять не нужно, если она уже добавлена.', style: TextStyle(color: GhostColors.muted, height: 1.45)),
            ]),
          ),
        ],
      ),
    );
  }
}

class GuidePlatformCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String client;
  final List<String> steps;

  const GuidePlatformCard({super.key, required this.icon, required this.title, required this.client, required this.steps});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleIcon(icon: icon),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(client, style: const TextStyle(color: GhostColors.orangeSoft, fontWeight: FontWeight.w800)),
            ])),
          ]),
          const SizedBox(height: 14),
          ...List.generate(steps.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: GhostColors.orange.withOpacity(.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: GhostColors.orange.withOpacity(.28))),
                child: Text('${i + 1}', style: const TextStyle(color: GhostColors.orangeSoft, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(steps[i], style: const TextStyle(color: GhostColors.muted, height: 1.35, fontWeight: FontWeight.w700))),
            ]),
          )),
        ],
      ),
    );
  }
}

class HelpPage extends StatefulWidget {
  final UserProfile profile;

  const HelpPage({super.key, required this.profile});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  static const List<String> _topics = [
    'Проблема с оплатой',
    'Не работает подписка',
    'Не подключается ключ',
    'Продление подписки',
    'Пробный доступ',
    'Промокод',
    'Другая тема',
  ];

  String _selectedTopic = 'Проблема с оплатой';
  final _customSubject = TextEditingController();
  final _message = TextEditingController();
  List<SupportTicketInfo> _tickets = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customSubject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tickets = await GhostApi.supportTickets(widget.profile.token);
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTicket(SupportTicketInfo ticket) async {
    await showDialog<void>(
      context: context,
      builder: (_) => SupportChatDialog(profile: widget.profile, ticket: ticket, onChanged: _load),
    );
    await _load();
  }

  Future<void> _send() async {
    final subject = _selectedTopic == 'Другая тема' ? _customSubject.text.trim() : _selectedTopic;
    final message = _message.text.trim();
    if (subject.length < 3 || message.length < 3) {
      _showSnack(context, 'Напишите тему и сообщение.');
      return;
    }
    setState(() => _sending = true);
    try {
      await GhostApi.createSupportTicket(token: widget.profile.token, subject: subject, message: message);
      _message.clear();
      await _load();
      if (mounted) _showSnack(context, 'Обращение отправлено в поддержку.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(title: 'Поддержка', subtitle: 'Общайтесь внутри приложения или переходите в Telegram.'),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MiniBadge(text: 'ВЫБОР СВЯЗИ'),
                const SizedBox(height: 14),
                const Text('Как удобнее общаться?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Можно написать прямо из приложения или открыть Telegram поддержку.', style: TextStyle(color: GhostColors.muted, height: 1.45)),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 285),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PrimaryButton(text: 'Общаться в приложении', icon: Icons.chat_rounded, onPressed: () => FocusScope.of(context).requestFocus(FocusNode())),
                        const SizedBox(height: 10),
                        PrimaryButton(text: 'Открыть в Telegram', icon: Icons.telegram_rounded, onPressed: () => openExternal(supportUrl)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MiniBadge(text: 'НОВОЕ ОБРАЩЕНИЕ'),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedTopic,
                  dropdownColor: GhostColors.panelLight,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.title_rounded, color: GhostColors.orange),
                    labelText: 'Тема обращения',
                    filled: true,
                    fillColor: Colors.black.withOpacity(.28),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withOpacity(.07))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: GhostColors.orange, width: 1.4)),
                  ),
                  items: _topics.map((topic) => DropdownMenuItem(value: topic, child: Text(topic))).toList(),
                  onChanged: (value) => setState(() => _selectedTopic = value ?? _topics.first),
                ),
                if (_selectedTopic == 'Другая тема') ...[
                  const SizedBox(height: 12),
                  GhostTextField(controller: _customSubject, label: 'Своя тема', icon: Icons.edit_rounded),
                ],
                const SizedBox(height: 12),
                GhostTextField(controller: _message, label: 'Сообщение', icon: Icons.message_rounded, maxLines: 4),
                const SizedBox(height: 14),
                PrimaryButton(text: _sending ? 'Отправляем...' : 'Отправить в поддержку', icon: Icons.send_rounded, onPressed: _sending ? null : _send),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MiniBadge(text: 'МОИ ОБРАЩЕНИЯ'),
                const SizedBox(height: 14),
                if (_loading) const LinearProgressIndicator(minHeight: 3),
                if (!_loading && _tickets.isEmpty) const Text('Пока обращений нет.', style: TextStyle(color: GhostColors.muted)),
                ..._tickets.map((ticket) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openTicket(ticket),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text('#${ticket.id} ${ticket.subject}', style: const TextStyle(fontWeight: FontWeight.w900))), MiniBadge(text: ticket.status.toUpperCase())]),
                        const SizedBox(height: 8),
                        ...ticket.messages.take(3).map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(m.isStaff ? 'Поддержка GhostNet: ${m.message}' : '${widget.profile.name} (${widget.profile.email}): ${m.message}', style: TextStyle(color: m.isStaff ? GhostColors.orangeSoft : GhostColors.muted, height: 1.35)),
                        )),
                        const SizedBox(height: 8),
                        SecondaryButton(text: 'Открыть чат', icon: Icons.chat_rounded, onPressed: () => _openTicket(ticket)),
                      ]),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




class NotificationsDialog extends StatefulWidget {
  final UserProfile profile;

  const NotificationsDialog({super.key, required this.profile});

  @override
  State<NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<NotificationsDialog> {
  List<NotificationInfo> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await GhostApi.notifications(widget.profile.token);
      if (!mounted) return;
      setState(() { _items = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _readAll() async {
    try {
      await GhostApi.notificationsReadAll(widget.profile.token);
      await _load();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GhostColors.panel,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: GhostColors.orange.withOpacity(.25))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: GhostColors.orange.withOpacity(.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: GhostColors.orange.withOpacity(.25)),
                ),
                child: const Icon(Icons.notifications_rounded, color: GhostColors.orange, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Уведомления',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.05),
                ),
              ),
              Tooltip(
                message: 'Отметить всё прочитанным',
                child: IconButton(
                  onPressed: _readAll,
                  icon: const Icon(Icons.done_all_rounded, color: GhostColors.orange),
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 14),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: _items.isEmpty && !_loading
                  ? const Center(child: Text('Уведомлений пока нет.', style: TextStyle(color: GhostColors.muted)))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final n = _items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: n.isRead ? Colors.white.withOpacity(.025) : GhostColors.orange.withOpacity(.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: n.isRead ? Colors.white.withOpacity(.06) : GhostColors.orange.withOpacity(.25)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(n.type.contains('expired') ? Icons.warning_rounded : Icons.notifications_active_rounded, color: GhostColors.orange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w900))),
                              if (!n.isRead) const MiniBadge(text: 'НОВОЕ'),
                            ]),
                            const SizedBox(height: 8),
                            Text(n.message, style: const TextStyle(color: GhostColors.muted, height: 1.35)),
                            if (n.createdAt != null) ...[
                              const SizedBox(height: 8),
                              Text(formatDate(n.createdAt), style: const TextStyle(color: GhostColors.muted, fontSize: 12)),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class SupportChatDialog extends StatefulWidget {
  final UserProfile profile;
  final SupportTicketInfo ticket;
  final bool staffMode;
  final VoidCallback? onChanged;

  const SupportChatDialog({super.key, required this.profile, required this.ticket, this.staffMode = false, this.onChanged});

  @override
  State<SupportChatDialog> createState() => _SupportChatDialogState();
}

class _SupportChatDialogState extends State<SupportChatDialog> {
  late SupportTicketInfo _ticket;
  final _message = TextEditingController();
  bool _sending = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final updated = widget.staffMode
          ? await GhostApi.adminReplyTicket(token: widget.profile.token, ticketId: _ticket.id, message: text)
          : await GhostApi.supportAddMessage(token: widget.profile.token, ticketId: _ticket.id, message: text);
      _message.clear();
      if (!mounted) return;
      setState(() => _ticket = updated);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeTicket() async {
    if (!widget.staffMode || _closing) return;
    setState(() => _closing = true);
    try {
      await GhostApi.adminCloseTicket(token: widget.profile.token, ticketId: _ticket.id);
      if (!mounted) return;
      setState(() => _ticket = SupportTicketInfo(id: _ticket.id, userName: _ticket.userName, userEmail: _ticket.userEmail, subject: _ticket.subject, status: 'closed', updatedAt: DateTime.now(), messages: _ticket.messages));
      widget.onChanged?.call();
      _showSnack(context, 'Обращение закрыто.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final closed = _ticket.status == 'closed';
    return Dialog(
      backgroundColor: GhostColors.panel,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: GhostColors.orange.withOpacity(.25))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('#${_ticket.id} ${_ticket.subject}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Статус: ${_ticket.status}', style: const TextStyle(color: GhostColors.muted)),
                ])),
                if (widget.staffMode && !closed) SecondaryButton(text: _closing ? 'Закрываем...' : 'Закрыть', icon: Icons.lock_rounded, onPressed: _closing ? null : _closeTicket),
                const SizedBox(width: 8),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(.22), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.06))),
                  child: ListView.builder(
                    itemCount: _ticket.messages.length,
                    itemBuilder: (context, index) {
                      final m = _ticket.messages[index];
                      final align = m.isStaff ? CrossAxisAlignment.start : CrossAxisAlignment.end;
                      final color = m.isStaff ? GhostColors.panelLight : GhostColors.orange.withOpacity(.18);
                      return Column(
                        crossAxisAlignment: align,
                        children: [
                          Container(
                            constraints: const BoxConstraints(maxWidth: 560),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.06))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.isStaff ? 'Поддержка GhostNet' : (widget.staffMode ? '${_ticket.userName} (${_ticket.userEmail})' : '${widget.profile.name} (${widget.profile.email})'), style: TextStyle(color: m.isStaff ? GhostColors.orangeSoft : GhostColors.text, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Text(m.message, style: const TextStyle(height: 1.35)),
                              if (m.createdAt != null) ...[
                                const SizedBox(height: 6),
                                Text(formatDate(m.createdAt), style: const TextStyle(color: GhostColors.muted, fontSize: 12)),
                              ],
                            ]),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (closed)
                const Text('Обращение закрыто. Ответить нельзя.', style: TextStyle(color: GhostColors.gold, fontWeight: FontWeight.w800))
              else
                Row(children: [
                  Expanded(child: GhostTextField(controller: _message, label: 'Сообщение', icon: Icons.message_rounded, maxLines: 2)),
                  const SizedBox(width: 12),
                  PrimaryButton(text: _sending ? 'Отправляем...' : 'Отправить', icon: Icons.send_rounded, onPressed: _sending ? null : _send),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class KeyManagementDialog extends StatefulWidget {
  final UserProfile profile;
  final AdminUserInfo user;
  final VoidCallback? onChanged;

  const KeyManagementDialog({super.key, required this.profile, required this.user, this.onChanged});

  @override
  State<KeyManagementDialog> createState() => _KeyManagementDialogState();
}

class _KeyManagementDialogState extends State<KeyManagementDialog> {
  final _plan = TextEditingController(text: 'ghost_net');
  final _days = TextEditingController(text: '30');
  final _devices = TextEditingController(text: '3');
  List<SubscriptionInfo> _subs = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _plan.dispose();
    _days.dispose();
    _devices.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final subs = await GhostApi.adminUserSubscriptions(token: widget.profile.token, userId: widget.user.id);
      if (!mounted) return;
      setState(() { _subs = subs; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _showSnack(context, e.toString().replaceFirst('Exception: ', '')); }
    }
  }

  Future<void> _grant() async {
    final plan = _plan.text.trim();
    final days = int.tryParse(_days.text.trim()) ?? 0;
    final devices = int.tryParse(_devices.text.trim()) ?? 3;
    if (plan.isEmpty || days <= 0) { _showSnack(context, 'Укажи тариф и количество дней.'); return; }
    setState(() => _busy = true);
    try {
      await GhostApi.adminGrantSubscription(token: widget.profile.token, userId: widget.user.id, planCode: plan, days: days, deviceLimit: devices);
      await _load();
      widget.onChanged?.call();
      if (mounted) _showSnack(context, 'Ключ добавлен / продлён.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extend(SubscriptionInfo sub, int days) async {
    setState(() => _busy = true);
    try {
      await GhostApi.adminExtendSubscription(token: widget.profile.token, subscriptionId: sub.id, days: days);
      await _load();
      widget.onChanged?.call();
      if (mounted) _showSnack(context, 'Ключ продлён на $days дней.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(SubscriptionInfo sub) async {
    setState(() => _busy = true);
    try {
      await GhostApi.adminDeleteSubscription(token: widget.profile.token, subscriptionId: sub.id);
      await _load();
      widget.onChanged?.call();
      if (mounted) _showSnack(context, 'Ключ удалён.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GhostColors.panel,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: GhostColors.orange.withOpacity(.25))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Ключи пользователя ${widget.user.email}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 14),
            PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MiniBadge(text: 'ДОБАВИТЬ / ПРОДЛИТЬ'),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 680;
                final planField = GhostTextField(controller: _plan, label: 'Код тарифа', icon: Icons.sell_rounded);
                final fields = [
                  wide ? Expanded(child: planField) : planField,
                  const SizedBox(width: 10, height: 10),
                  SizedBox(width: wide ? 130 : double.infinity, child: GhostTextField(controller: _days, label: 'Дней', icon: Icons.calendar_month_rounded)),
                  const SizedBox(width: 10, height: 10),
                  SizedBox(width: wide ? 150 : double.infinity, child: GhostTextField(controller: _devices, label: 'Устройств', icon: Icons.devices_rounded)),
                  const SizedBox(width: 10, height: 10),
                  PrimaryButton(text: _busy ? 'Ждём...' : 'Выдать', icon: Icons.vpn_key_rounded, onPressed: _busy ? null : _grant),
                ];
                return wide ? Row(children: fields) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
              }),
            ])),
            const SizedBox(height: 14),
            Expanded(child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    if (_subs.isEmpty) const Text('Ключей нет.', style: TextStyle(color: GhostColors.muted)),
                    ..._subs.map((sub) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('#${sub.id} ${sub.planName}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('До: ${formatDate(sub.expiresAt)} | Устройств: ${sub.deviceLimit} | ${sub.status}', style: const TextStyle(color: GhostColors.muted)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          SecondaryButton(text: '+30 дней', icon: Icons.add_rounded, onPressed: _busy ? null : () => _extend(sub, 30)),
                          SecondaryButton(text: '+90 дней', icon: Icons.add_rounded, onPressed: _busy ? null : () => _extend(sub, 90)),
                          SecondaryButton(text: 'Удалить ключ', icon: Icons.delete_forever_rounded, onPressed: _busy ? null : () => _delete(sub)),
                        ]),
                      ]),
                    )),
                  ])),
          ]),
        ),
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  final UserProfile profile;

  const AdminPage({super.key, required this.profile});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  AdminOverview? _overview;
  List<AdminUserInfo> _users = [];
  List<AdminPlanInfo> _plans = [];
  List<AdminPromocodeInfo> _promos = [];
  AdminReferralStats? _referralStats;
  List<SupportTicketInfo> _tickets = [];
  bool _loading = true;
  final _planCode = TextEditingController();
  final _planName = TextEditingController();
  final _planPrice = TextEditingController();
  final _planDays = TextEditingController();
  final _planDescription = TextEditingController();
  final _promoCode = TextEditingController();
  final _promoDiscount = TextEditingController(text: '10');
  final _userSearch = TextEditingController();
  final _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _planCode.dispose();
    _planName.dispose();
    _planPrice.dispose();
    _planDays.dispose();
    _planDescription.dispose();
    _promoCode.dispose();
    _promoDiscount.dispose();
    _userSearch.dispose();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final overview = widget.profile.isAdmin ? await GhostApi.adminOverview(widget.profile.token) : null;
      final users = widget.profile.isAdmin ? await GhostApi.adminUsers(widget.profile.token, query: _userSearch.text) : <AdminUserInfo>[];
      final plans = widget.profile.isAdmin ? await GhostApi.adminPlans(widget.profile.token) : <AdminPlanInfo>[];
      final promos = widget.profile.isAdmin ? await GhostApi.adminPromocodes(widget.profile.token) : <AdminPromocodeInfo>[];
      final referralStats = widget.profile.isAdmin ? await GhostApi.adminReferrals(widget.profile.token) : null;
      final tickets = await GhostApi.adminSupportTickets(widget.profile.token);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _users = users;
        _plans = plans;
        _promos = promos;
        _referralStats = referralStats;
        _tickets = tickets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _setRole(AdminUserInfo user, String role, bool enabled) async {
    try {
      await GhostApi.adminSetRole(token: widget.profile.token, userId: user.id, role: role, enabled: enabled);
      await _load();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _savePlan() async {
    final code = _planCode.text.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    final name = _planName.text.trim();
    final price = int.tryParse(_planPrice.text.trim()) ?? -1;
    final days = int.tryParse(_planDays.text.trim()) ?? 0;
    if (code.isEmpty || name.isEmpty || price < 0 || days <= 0) {
      _showSnack(context, 'Заполни код, название, цену и дни тарифа.');
      return;
    }
    try {
      await GhostApi.adminCreatePlan(
        token: widget.profile.token,
        code: code,
        name: name,
        priceRub: price,
        durationDays: days,
        description: _planDescription.text,
      );
      _clearPlanFields(showMessage: false);
      await _load();
      if (mounted) _showSnack(context, 'Тариф сохранён.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _clearPlanFields({bool showMessage = true}) {
    _planCode.clear();
    _planName.clear();
    _planPrice.clear();
    _planDays.clear();
    _planDescription.clear();
    if (showMessage) _showSnack(context, 'Поля тарифа очищены.');
  }

  Future<void> _togglePlan(AdminPlanInfo plan) async {
    try {
      await GhostApi.adminSetPlanActive(token: widget.profile.token, code: plan.code, enabled: !plan.isActive);
      await _load();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deletePlan(AdminPlanInfo plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GhostColors.panel,
        title: const Text('Удалить тариф?'),
        content: Text('Тариф ${plan.name} будет удалён из магазина. Старые подписки пользователей не пропадут.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GhostApi.adminDeletePlan(token: widget.profile.token, code: plan.code);
      await _load();
      if (mounted) _showSnack(context, 'Тариф удалён.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _editPlan(AdminPlanInfo plan) async {
    final name = TextEditingController(text: plan.name);
    final price = TextEditingController(text: plan.priceRub.toString());
    final days = TextEditingController(text: plan.durationDays.toString());
    final description = TextEditingController(text: plan.description);
    bool active = plan.isActive;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: GhostColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: GhostColors.orange.withOpacity(.25))),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Icon(Icons.sell_rounded, color: GhostColors.orange),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Редактировать тариф ${plan.code}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close_rounded)),
                  ]),
                  const SizedBox(height: 14),
                  GhostTextField(controller: name, label: 'Название', icon: Icons.badge_rounded),
                  const SizedBox(height: 12),
                  GhostTextField(controller: price, label: 'Цена ₽', icon: Icons.payments_rounded),
                  const SizedBox(height: 12),
                  GhostTextField(controller: days, label: 'Дней', icon: Icons.calendar_month_rounded),
                  const SizedBox(height: 12),
                  GhostTextField(controller: description, label: 'Описание', icon: Icons.description_rounded, maxLines: 2),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    activeColor: GhostColors.orange,
                    title: const Text('Тариф включён'),
                    subtitle: const Text('Выключенный тариф не показывается пользователям.', style: TextStyle(color: GhostColors.muted)),
                    onChanged: (v) => setModalState(() => active = v),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: SecondaryButton(text: 'Отмена', icon: Icons.close_rounded, onPressed: () => Navigator.pop(context, false))),
                    const SizedBox(width: 12),
                    Expanded(child: PrimaryButton(text: 'Сохранить', icon: Icons.save_rounded, onPressed: () => Navigator.pop(context, true))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    final parsedPrice = int.tryParse(price.text.trim()) ?? -1;
    final parsedDays = int.tryParse(days.text.trim()) ?? 0;
    if (name.text.trim().isEmpty || parsedPrice < 0 || parsedDays <= 0) {
      if (mounted) _showSnack(context, 'Проверь название, цену и дни тарифа.');
      return;
    }
    try {
      await GhostApi.adminUpdatePlan(
        token: widget.profile.token,
        code: plan.code,
        name: name.text.trim(),
        priceRub: parsedPrice,
        durationDays: parsedDays,
        description: description.text,
        isActive: active,
      );
      await _load();
      if (mounted) _showSnack(context, 'Тариф обновлён.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _createPromo() async {
    final code = _promoCode.text.trim().toUpperCase();
    final discount = int.tryParse(_promoDiscount.text.trim()) ?? 0;
    if (code.isEmpty || discount <= 0 || discount >= 100) {
      _showSnack(context, 'Введите код и скидку от 1 до 99.');
      return;
    }
    try {
      await GhostApi.adminCreatePromocode(token: widget.profile.token, code: code, discountPercent: discount);
      _promoCode.clear();
      await _load();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deletePromo(String code) async {
    try {
      await GhostApi.adminDeletePromocode(token: widget.profile.token, code: code);
      await _load();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _togglePromo(AdminPromocodeInfo promo) async {
    try {
      await GhostApi.adminSetPromocodeActive(token: widget.profile.token, code: promo.code, enabled: !promo.isActive);
      await _load();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _replyTicket(int ticketId) async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    try {
      await GhostApi.adminReplyTicket(token: widget.profile.token, ticketId: ticketId, message: text);
      _reply.clear();
      await _load();
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openTicket(SupportTicketInfo ticket) async {
    await showDialog<void>(
      context: context,
      builder: (_) => SupportChatDialog(profile: widget.profile, ticket: ticket, staffMode: true, onChanged: _load),
    );
    await _load();
  }

  Future<void> _closeTicket(int ticketId) async {
    try {
      await GhostApi.adminCloseTicket(token: widget.profile.token, ticketId: ticketId);
      await _load();
      if (mounted) _showSnack(context, 'Обращение закрыто.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteTicket(SupportTicketInfo ticket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GhostColors.panel,
        title: const Text('Удалить обращение?'),
        content: Text('Обращение #${ticket.id} будет удалено полностью вместе с перепиской.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GhostApi.adminDeleteTicket(token: widget.profile.token, ticketId: ticket.id);
      await _load();
      if (mounted) _showSnack(context, 'Обращение удалено.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteAllTickets() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GhostColors.panel,
        title: const Text('Удалить все обращения?'),
        content: const Text('Будут удалены все обращения поддержки и вся переписка. Действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить все')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GhostApi.adminDeleteAllTickets(token: widget.profile.token);
      await _load();
      if (mounted) _showSnack(context, 'Все обращения удалены.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _clearPaymentsHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GhostColors.panel,
        title: const Text('Очистить историю платежей?'),
        content: const Text('Будет очищена история платежей в админке. Подписки, ключи и использованные промокоды не будут удалены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await GhostApi.adminClearPaymentsHistory(token: widget.profile.token);
      await _load();
      if (mounted) _showSnack(context, 'История платежей очищена.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _runMaintenance() async {
    try {
      final result = await GhostApi.adminRunMaintenance(token: widget.profile.token);
      await _load();
      if (mounted) {
        _showSnack(context, 'Обслуживание выполнено: уведомлений ${result['reminders_created'] ?? 0}, истёкших ${result['expired_marked'] ?? 0}.');
      }
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _openKeys(AdminUserInfo user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => KeyManagementDialog(profile: widget.profile, user: user, onChanged: _load),
    );
    await _load();
  }

  Future<void> _deleteUser(AdminUserInfo user) async {
    try {
      await GhostApi.adminDeleteUser(token: widget.profile.token, userId: user.id);
      await _load();
      if (mounted) _showSnack(context, 'Пользователь полностью удалён.');
    } catch (e) {
      if (mounted) _showSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _clearPromoFields() {
    _promoCode.clear();
    _promoDiscount.text = '10';
    _showSnack(context, 'Поля промокода очищены.');
  }

  @override
  Widget build(BuildContext context) {
    return PageWrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageTitle(title: widget.profile.isAdmin ? 'Админ-панель' : 'Панель поддержки', subtitle: widget.profile.isAdmin ? 'Тарифы, пользователи, роли, промокоды, ключи и поддержка.' : 'Обращения пользователей и ответы в чате.'),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          if (!_loading && _overview != null) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AdminCompactStatsLine(overview: _overview!),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: CompactButton(text: 'Очистить платежи', icon: Icons.cleaning_services_rounded, onPressed: _clearPaymentsHistory)),
              const SizedBox(width: 10),
              Expanded(child: CompactButton(text: 'Проверить подписки', icon: Icons.auto_delete_rounded, onPressed: _runMaintenance)),
            ]),
          ]),
          if (widget.profile.isAdmin) ...[
            if (_referralStats != null) ...[
              const SizedBox(height: 16),
              AdminReferralPanel(stats: _referralStats!),
            ],
            const SizedBox(height: 16),
            PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MiniBadge(text: 'ТАРИФЫ'),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
                final fields = [
                  wide ? Expanded(child: GhostTextField(controller: _planCode, label: 'Код, например ghost_net', icon: Icons.code_rounded)) : GhostTextField(controller: _planCode, label: 'Код, например ghost_net', icon: Icons.code_rounded),
                  const SizedBox(width: 12, height: 12),
                  wide ? Expanded(child: GhostTextField(controller: _planName, label: 'Название', icon: Icons.badge_rounded)) : GhostTextField(controller: _planName, label: 'Название', icon: Icons.badge_rounded),
                  const SizedBox(width: 12, height: 12),
                  SizedBox(width: wide ? 130 : double.infinity, child: GhostTextField(controller: _planPrice, label: 'Цена ₽', icon: Icons.payments_rounded)),
                  const SizedBox(width: 12, height: 12),
                  SizedBox(width: wide ? 120 : double.infinity, child: GhostTextField(controller: _planDays, label: 'Дней', icon: Icons.calendar_month_rounded)),
                ];
                return wide ? Row(children: fields) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
              }),
              const SizedBox(height: 12),
              GhostTextField(controller: _planDescription, label: 'Описание тарифа', icon: Icons.description_rounded, maxLines: 2),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                PrimaryButton(text: 'Добавить / сохранить тариф', icon: Icons.add_rounded, onPressed: _savePlan),
                SecondaryButton(text: 'Очистить', icon: Icons.clear_rounded, onPressed: _clearPlanFields),
              ]),
              const SizedBox(height: 14),
              if (_plans.isEmpty) const Text('Тарифов пока нет.', style: TextStyle(color: GhostColors.muted)),
              ..._plans.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.07))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${p.name} — ${p.priceRub} ₽ / ${p.durationDays} дн.', style: const TextStyle(fontWeight: FontWeight.w900))),
                      MiniBadge(text: p.isActive ? 'ВКЛЮЧЁН' : 'ВЫКЛЮЧЕН'),
                    ]),
                    const SizedBox(height: 6),
                    Text('${p.code}${p.description.isNotEmpty ? ' • ${p.description}' : ''}', style: const TextStyle(color: GhostColors.muted, height: 1.35)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      MiniActionButton(label: 'Изменить тариф', icon: Icons.edit_rounded, onTap: () => _editPlan(p)),
                      MiniActionButton(label: p.isActive ? 'Выключить тариф' : 'Включить тариф', icon: p.isActive ? Icons.toggle_off_rounded : Icons.toggle_on_rounded, onTap: () => _togglePlan(p)),
                      MiniActionButton(label: 'Удалить тариф', icon: Icons.delete_rounded, danger: true, onTap: () => _deletePlan(p)),
                    ]),
                  ]),
                ),
              )),
            ])),
            const SizedBox(height: 16),
            PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MiniBadge(text: 'ПРОМОКОДЫ'),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 720;
                final codeField = GhostTextField(controller: _promoCode, label: 'Код', icon: Icons.confirmation_number_rounded);
                final discountField = GhostTextField(controller: _promoDiscount, label: 'Скидка %', icon: Icons.percent_rounded);
                final buttons = Row(children: [
                  Expanded(child: CompactButton(text: 'Создать', icon: Icons.add_rounded, filled: true, onPressed: _createPromo)),
                  const SizedBox(width: 10),
                  Expanded(child: CompactButton(text: 'Очистить', icon: Icons.clear_rounded, onPressed: _clearPromoFields)),
                ]);
                if (wide) {
                  return Row(children: [
                    Expanded(child: codeField),
                    const SizedBox(width: 12),
                    SizedBox(width: 150, child: discountField),
                    const SizedBox(width: 12),
                    SizedBox(width: 250, child: buttons),
                  ]);
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  codeField,
                  const SizedBox(height: 10),
                  discountField,
                  const SizedBox(height: 10),
                  buttons,
                ]);
              }),
              const SizedBox(height: 14),
              ..._promos.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text('${p.code} — ${p.discountPercent}% ${p.isActive ? '(включён)' : '(выключен)'}')),
                  SecondaryButton(text: p.isActive ? 'Выключить' : 'Включить', icon: p.isActive ? Icons.toggle_off_rounded : Icons.toggle_on_rounded, onPressed: () => _togglePromo(p)),
                  const SizedBox(width: 8),
                  SecondaryButton(text: 'Удалить', icon: Icons.delete_rounded, onPressed: () => _deletePromo(p.code)),
                ]),
              ))
            ])),
            const SizedBox(height: 16),
            PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MiniBadge(text: 'ПОЛЬЗОВАТЕЛИ И РОЛИ'),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 620;
                final search = GhostTextField(controller: _userSearch, label: 'Поиск по email / Telegram / ID', icon: Icons.search_rounded);
                final buttons = Row(children: [
                  Expanded(child: CompactButton(text: 'Найти', icon: Icons.search_rounded, onPressed: _load)),
                  const SizedBox(width: 10),
                  Expanded(child: CompactButton(text: 'Сброс', icon: Icons.clear_rounded, onPressed: () { _userSearch.clear(); _load(); })),
                ]);
                return wide
                    ? Row(children: [Expanded(child: search), const SizedBox(width: 10), SizedBox(width: 210, child: buttons)])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [search, const SizedBox(height: 10), buttons]);
              }),
              const SizedBox(height: 14),
              ..._users.take(80).map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.07)),
                  ),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 560;
                    final info = Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GhostColors.orange.withOpacity(.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: GhostColors.orange.withOpacity(.22)),
                        ),
                        child: Text('#${u.id}', style: const TextStyle(color: GhostColors.orangeSoft, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(u.telegram.isEmpty ? 'Telegram не указан' : u.telegram, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GhostColors.muted, fontSize: 12, height: 1.2)),
                      ])),
                    ]);
                    final roles = Wrap(spacing: 6, runSpacing: 6, children: [
                      CompactStatusPill(text: u.isActive ? 'активен' : 'заблокирован', active: u.isActive),
                      if (u.isAdmin) const CompactStatusPill(text: 'admin', active: true),
                      if (u.isSupport) const CompactStatusPill(text: 'support', active: true),
                    ]);
                    final actions = Wrap(spacing: 7, runSpacing: 7, children: [
                      MiniActionButton(label: u.isAdmin ? 'Убрать админа' : 'Сделать админом', icon: Icons.admin_panel_settings_rounded, onTap: () => _setRole(u, 'admin', !u.isAdmin)),
                      MiniActionButton(label: u.isSupport ? 'Убрать поддержку' : 'Сделать поддержкой', icon: Icons.support_agent_rounded, onTap: () => _setRole(u, 'support', !u.isSupport)),
                      MiniActionButton(label: u.isActive ? 'Заблокировать' : 'Разблокировать', icon: u.isActive ? Icons.block_rounded : Icons.lock_open_rounded, onTap: () => _setRole(u, 'active', !u.isActive)),
                      MiniActionButton(label: 'Ключи', icon: Icons.vpn_key_rounded, onTap: () => _openKeys(u)),
                      MiniActionButton(label: 'Удалить пользователя', icon: Icons.delete_forever_rounded, danger: true, onTap: () => _deleteUser(u)),
                    ]);
                    if (wide) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(flex: 4, child: info),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: roles),
                        const SizedBox(width: 10),
                        actions,
                      ]);
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      info,
                      const SizedBox(height: 7),
                      roles,
                      const SizedBox(height: 7),
                      actions,
                    ]);
                  }),
                ),
              )),
            ])),
          ],
          const SizedBox(height: 16),
          PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: MiniBadge(text: 'ОБРАЩЕНИЯ ПОДДЕРЖКИ')),
              if (widget.profile.isAdmin && _tickets.isNotEmpty)
                SecondaryButton(text: 'Удалить все обращения', icon: Icons.delete_sweep_rounded, onPressed: _deleteAllTickets),
            ]),
            const SizedBox(height: 14),
            if (_tickets.isEmpty) const Text('Нет обращений.', style: TextStyle(color: GhostColors.muted)),
            ..._tickets.take(50).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('#${t.id} ${t.subject}', style: const TextStyle(fontWeight: FontWeight.w900))), MiniBadge(text: t.status.toUpperCase())]),
                  const SizedBox(height: 8),
                  ...t.messages.take(5).map((m) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(m.isStaff ? 'Поддержка GhostNet: ${m.message}' : '${t.userName} (${t.userEmail}): ${m.message}', style: TextStyle(color: m.isStaff ? GhostColors.orangeSoft : GhostColors.muted, height: 1.35)))),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    PrimaryButton(text: 'Открыть чат', icon: Icons.chat_rounded, onPressed: () => _openTicket(t)),
                    if (t.status != 'closed') SecondaryButton(text: 'Закрыть', icon: Icons.lock_rounded, onPressed: () => _closeTicket(t.id)),
                    if (widget.profile.isAdmin) SecondaryButton(text: 'Удалить обращение', icon: Icons.delete_rounded, onPressed: () => _deleteTicket(t)),
                  ]),
                ]),
              ),
            )),
          ])),
        ],
      ),
    );
  }
}



Future<void> showNewsDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: GhostColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: GhostColors.orange.withOpacity(.25))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.newspaper_rounded, color: GhostColors.orange),
                const SizedBox(width: 10),
                const Expanded(child: Text('Новости GhostNet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 12),
              const Text('Здесь будут отображаться обновления сервиса, новости приложения и важные уведомления для пользователей.', style: TextStyle(color: GhostColors.muted, height: 1.45)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.07))),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('GhostNet обновлён', style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text('Добавлены поддержка в приложении, ЮKassa, промокоды и управление ключами.', style: TextStyle(color: GhostColors.muted, height: 1.35)),
                ]),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CyberBackground extends StatefulWidget {
  final Widget child;

  const CyberBackground({super.key, required this.child});

  @override
  State<CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<CyberBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.65, -0.95),
          radius: 1.35,
          colors: [Color(0xFF4A1B00), Color(0xFF130B05), GhostColors.black],
          stops: [0.0, .42, 1],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: CyberGridPainter(_controller.value))),
              Positioned(
                top: -120,
                right: -90,
                child: IgnorePointer(child: GlowBlob(size: 260, opacity: .10 + .04 * math.sin(_controller.value * math.pi * 2))),
              ),
              Positioned(
                bottom: -160,
                left: -110,
                child: IgnorePointer(child: GlowBlob(size: 320, opacity: .07 + .03 * math.cos(_controller.value * math.pi * 2))),
              ),
              SafeArea(child: widget.child),
            ],
          );
        },
      ),
    );
  }
}

class CyberGridPainter extends CustomPainter {
  final double progress;

  CyberGridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = GhostColors.orange.withOpacity(.045)
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = GhostColors.orange.withOpacity(.12);
    final shift = progress * 44;

    for (double x = -120; x < size.width + 140; x += 42) {
      canvas.drawLine(Offset(x + shift, 0), Offset(x + 90 + shift, size.height), gridPaint);
    }
    for (double y = -44; y < size.height + 44; y += 44) {
      canvas.drawLine(Offset(0, y + shift), Offset(size.width, y + shift), gridPaint);
    }

    for (int i = 0; i < 42; i++) {
      final x = (i * 97 + progress * 140) % size.width;
      final y = (i * 53 + math.sin(progress * math.pi * 2 + i) * 18 + progress * 80) % size.height;
      final r = 1.0 + (i % 3) * .55;
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CyberGridPainter oldDelegate) => oldDelegate.progress != progress;
}

class GlowBlob extends StatelessWidget {
  final double size;
  final double opacity;

  const GlowBlob({super.key, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [GhostColors.orange.withOpacity(opacity), Colors.transparent]),
      ),
    );
  }
}


class PageWrap extends StatelessWidget {
  final Widget child;

  const PageWrap({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final horizontal = constraints.maxWidth > 720 ? 34.0 : compact ? 14.0 : 18.0;
        final top = compact ? 14.0 : 20.0;
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, compact ? 18 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class HeaderBar extends StatefulWidget {
  final UserProfile profile;

  const HeaderBar({super.key, required this.profile});

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  int _unreadCount = 0;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _loadUnreadCount());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await GhostApi.notifications(widget.profile.token);
      final count = data.where((n) => !n.isRead).length;
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {
      // Молча пропускаем, чтобы верхнее меню не мешало работе приложения.
    } finally {
      _loading = false;
    }
  }

  Future<void> _openNotifications() async {
    await showDialog(
      context: context,
      builder: (_) => NotificationsDialog(profile: widget.profile),
    );
    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: LogoHeader(compact: true)),
        const SizedBox(width: 10),
        BadgeIconButton(
          icon: Icons.notifications_rounded,
          badgeCount: _unreadCount,
          onTap: _openNotifications,
        ),
        const SizedBox(width: 8),
        GhostIconButton(icon: Icons.newspaper_rounded, onTap: () => openExternal(newsUrl)),
      ],
    );
  }
}

class LogoHeader extends StatelessWidget {
  final bool compact;

  const LogoHeader({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final smallPhone = width < 370;
    final logoSize = compact ? (smallPhone ? 54.0 : 62.0) : 96.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoOrb(size: logoSize),
        SizedBox(width: smallPhone ? 10 : 14),
        Expanded(child: LogoTitleBlock(compact: compact || smallPhone)),
      ],
    );
  }
}

class LogoTitleBlock extends StatelessWidget {
  final bool compact;

  const LogoTitleBlock({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ghostSize = compact ? (width < 370 ? 24.0 : 27.0) : 38.0;
    final cyberSize = compact ? (width < 370 ? 11.5 : 13.0) : 17.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('GhostNet', style: TextStyle(fontSize: ghostSize, fontWeight: FontWeight.w900, letterSpacing: .3)),
        ),
        Text('CYBER VPN', style: TextStyle(color: GhostColors.orange, fontSize: cyberSize, fontWeight: FontWeight.w900, letterSpacing: 2.4)),
      ],
    );
  }
}

class LogoOrb extends StatelessWidget {
  final double size;

  const LogoOrb({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * .22),
        border: Border.all(color: GhostColors.orange.withOpacity(.28)),
        boxShadow: [
          BoxShadow(color: GhostColors.orange.withOpacity(.28), blurRadius: size * .30),
          BoxShadow(color: Colors.black.withOpacity(.44), blurRadius: size * .16, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: SizedBox.expand(
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;

  const PremiumCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highlighted
              ? [const Color(0xFF251003).withOpacity(.94), GhostColors.glass]
              : [Colors.white.withOpacity(.035), GhostColors.glass],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? GhostColors.orange.withOpacity(.36) : Colors.white.withOpacity(.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.38), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: GhostColors.orange.withOpacity(highlighted ? .16 : .06), blurRadius: 18),
        ],
      ),
      child: child,
    );
  }
}

class MiniBadge extends StatelessWidget {
  final String text;

  const MiniBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: GhostColors.orange.withOpacity(.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GhostColors.orange.withOpacity(.24)),
      ),
      child: Text(text, style: const TextStyle(color: GhostColors.orangeSoft, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
    );
  }
}

class CompactStatusPill extends StatelessWidget {
  final String text;
  final bool active;

  const CompactStatusPill({super.key, required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? GhostColors.orange : GhostColors.danger).withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (active ? GhostColors.orange : GhostColors.danger).withOpacity(.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? GhostColors.orangeSoft : GhostColors.danger,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class MiniActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const MiniActionButton({super.key, required this.label, required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? GhostColors.danger : GhostColors.orange;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(.25)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class HomeHeroCard extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onOpenTariffs;
  final VoidCallback onOpenAccount;

  const HomeHeroCard({super.key, required this.profile, required this.onOpenTariffs, required this.onOpenAccount});

  @override
  State<HomeHeroCard> createState() => _HomeHeroCardState();
}

class _HomeHeroCardState extends State<HomeHeroCard> {
  bool _trialLoading = false;
  bool _loading = true;
  String? _error;
  List<SubscriptionInfo> _subscriptions = const [];
  String? _manualUrl;
  ManualSubscriptionMeta? _manualMeta;

  @override
  void initState() {
    super.initState();
    manualSubscriptionRevision.addListener(_handleManualSubscriptionChanged);
    _loadDashboard();
  }

  @override
  void dispose() {
    manualSubscriptionRevision.removeListener(_handleManualSubscriptionChanged);
    super.dispose();
  }

  void _handleManualSubscriptionChanged() {
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    List<SubscriptionInfo> subs = const [];
    String? loadError;
    try {
      subs = await GhostApi.mySubscriptions(widget.profile.token);
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
    }
    final manualUrl = await _loadManualSubscriptionUrl();
    var manualMeta = await ManualSubscriptionMeta.load();
    final matched = _findSubscriptionByUrl(subs, manualUrl);
    if (matched != null) {
      final refreshedMeta = ManualSubscriptionMeta.fromSubscription(matched, serverCount: manualMeta?.serverCount ?? 0);
      manualMeta = refreshedMeta;
      await ManualSubscriptionMeta.save(refreshedMeta);
    }
    if (!mounted) return;
    setState(() {
      _subscriptions = subs;
      _manualUrl = manualUrl;
      _manualMeta = manualMeta;
      _error = loadError;
      _loading = false;
    });
  }

  Future<void> _claimTrial() async {
    if (_trialLoading) return;
    setState(() => _trialLoading = true);
    try {
      await GhostApi.claimTrial(widget.profile.token);
      if (!mounted) return;
      await showGhostDialog(
        context,
        title: 'Пробный доступ активирован',
        message: 'Подписка на 24 часа выдана. Лимит устройств: 3. Трафик: безлимит.',
        icon: Icons.check_circle_rounded,
        success: true,
      );
      await _loadDashboard();
      widget.onOpenAccount();
    } catch (e) {
      if (mounted) {
        showGhostDialog(
          context,
          title: 'Пробный доступ недоступен',
          message: e.toString().replaceFirst('Exception: ', ''),
          icon: Icons.info_rounded,
          success: false,
        );
      }
    } finally {
      if (mounted) setState(() => _trialLoading = false);
    }
  }

  SubscriptionInfo? get _activeSubscription {
    final matched = _findSubscriptionByUrl(_subscriptions, _manualUrl);
    if (matched != null) return matched;
    if (_manualUrl != null && _manualMeta != null) return _manualMeta!.toSubscription(_manualUrl!);
    for (final sub in _subscriptions) {
      if (sub.status.toLowerCase() == 'active') return sub;
    }
    return _subscriptions.isEmpty ? null : _subscriptions.first;
  }

  int? _daysLeft(DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(DateTime.now());
    if (diff.inSeconds <= 0) return 0;
    return diff.inDays + 1;
  }

  String _serversText(SubscriptionInfo? sub) {
    final raw = sub?.vpnKey ?? '';
    final count = raw.split('\n').where((e) => e.trim().isNotEmpty).length;
    if (count >= 4) return '4 сервера';
    if (count > 0) return '$count серв.';
    return 'Лондон / Амстердам / Хельсинки / Прага';
  }

  Color _statusColor(SubscriptionInfo? sub) {
    if (sub == null) return GhostColors.gold;
    if (sub.status.toLowerCase() != 'active') return GhostColors.danger;
    final days = _daysLeft(sub.expiresAt);
    if (days != null && days <= 3) return GhostColors.gold;
    return GhostColors.success;
  }

  String _statusText(SubscriptionInfo? sub) {
    if (_loading) return 'Загрузка';
    if (_error != null) return 'Ошибка';
    if (sub == null) return 'Нет подписки';
    if (sub.status.toLowerCase() == 'active') return 'Активна';
    return sub.status;
  }

  @override
  Widget build(BuildContext context) {
    final sub = _activeSubscription;
    final active = sub != null && sub.status.toLowerCase() == 'active';
    final days = _daysLeft(sub?.expiresAt);
    final statusColor = _statusColor(sub);
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 370 ? 24.0 : width < 520 ? 28.0 : 34.0;

    return PremiumCard(
      highlighted: true,
      padding: const EdgeInsets.all(22),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 820;
          final metrics = [
            DashboardMetric(icon: Icons.shield_rounded, title: 'Статус', value: _statusText(sub), color: statusColor),
            DashboardMetric(icon: Icons.schedule_rounded, title: 'Осталось', value: active ? (days == null ? '—' : '$days дн.') : '—', color: active && days != null && days <= 3 ? GhostColors.gold : GhostColors.orangeSoft),
            DashboardMetric(icon: Icons.workspace_premium_rounded, title: 'Тариф', value: active ? (sub?.planName ?? 'Подписка') : 'Выберите', color: GhostColors.orangeSoft),
            DashboardMetric(icon: Icons.devices_rounded, title: 'Устройства', value: active ? 'до ${sub?.deviceLimit ?? 3}' : 'до 3', color: GhostColors.orangeSoft),
          ];

          final dashboard = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MiniBadge(text: 'GHOSTNET DASHBOARD'),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Обновить',
                    onPressed: _loading ? null : _loadDashboard,
                    icon: const Icon(Icons.refresh_rounded, color: GhostColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Привет, ${widget.profile.name}', style: TextStyle(fontSize: titleSize, height: 1.06, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                active
                    ? 'Подписка активна до ${formatDate(sub?.expiresAt)}. Управляй ключами, продлением и поддержкой из одного кабинета.'
                    : 'Оформи подписку или активируй пробный доступ, чтобы получить ключи GhostNet.',
                style: const TextStyle(color: GhostColors.muted, height: 1.45, fontSize: 14.5),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: GhostColors.gold, height: 1.35, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, metricConstraints) {
                  final columns = metricConstraints.maxWidth > 680 ? 4 : metricConstraints.maxWidth > 430 ? 2 : 1;
                  final itemWidth = (metricConstraints.maxWidth - 10 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics.map((e) => SizedBox(width: itemWidth, child: e)).toList(),
                  );
                },
              ),
              const SizedBox(height: 18),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrimaryButton(text: active ? 'Продлить подписку' : 'Приобрести подписку', icon: Icons.shopping_cart_rounded, onPressed: widget.onOpenTariffs),
                      const SizedBox(height: 10),
                      PrimaryButton(text: 'Мои ключи', icon: Icons.vpn_key_rounded, onPressed: widget.onOpenAccount),
                      if (!active) ...[
                        const SizedBox(height: 10),
                        SecondaryButton(text: _trialLoading ? 'Активируем...' : 'Пробный доступ', icon: Icons.card_giftcard_rounded, onPressed: _trialLoading ? null : _claimTrial),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );

          final side = PremiumDashboardSideCard(
            status: _statusText(sub),
            statusColor: statusColor,
            plan: active ? (sub?.planName ?? 'Подписка') : 'Нет подписки',
            expires: active ? formatDate(sub?.expiresAt) : '—',
            servers: _serversText(sub),
          );

          if (!wide) return dashboard;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: dashboard),
              const SizedBox(width: 22),
              SizedBox(width: 300, child: side),
            ],
          );
        },
      ),
    );
  }
}

class DashboardMetric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const DashboardMetric({super.key, required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(.13),
              border: Border.all(color: color.withOpacity(.22)),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: GhostColors.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumDashboardSideCard extends StatelessWidget {
  final String status;
  final Color statusColor;
  final String plan;
  final String expires;
  final String servers;

  const PremiumDashboardSideCard({super.key, required this.status, required this.statusColor, required this.plan, required this.expires, required this.servers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GhostColors.orange.withOpacity(.24)),
        boxShadow: [BoxShadow(color: GhostColors.orange.withOpacity(.10), blurRadius: 22)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(children: [LogoOrb(size: 54), SizedBox(width: 12), Expanded(child: Text('GHOSTNET STATUS', style: TextStyle(fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 18),
          StatusLine(label: 'Статус', value: status, color: statusColor),
          const SizedBox(height: 10),
          StatusLine(label: 'Тариф', value: plan),
          const SizedBox(height: 10),
          StatusLine(label: 'До', value: expires),

        ],
      ),
    );
  }
}

class HeroPreviewCard extends StatelessWidget {
  const HeroPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: GhostColors.orange.withOpacity(.24)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [LogoOrb(size: 54), SizedBox(width: 12), Expanded(child: Text('GHOSTNET KEY', style: TextStyle(fontWeight: FontWeight.w900)))]),
          SizedBox(height: 18),
          StatusLine(label: 'Статус', value: 'Готов к покупке', color: GhostColors.success),
          SizedBox(height: 10),
          StatusLine(label: 'Устройства', value: 'до 3'),
          SizedBox(height: 10),
          StatusLine(label: 'Трафик', value: 'безлимит'),
        ],
      ),
    );
  }
}

class StatusLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatusLine({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: GhostColors.muted))),
        Text(value, style: TextStyle(color: color ?? GhostColors.text, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class QuickActionsGrid extends StatelessWidget {
  final VoidCallback onOpenTariffs;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenGuide;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenNews;

  const QuickActionsGrid({super.key, required this.onOpenTariffs, required this.onOpenAccount, required this.onOpenGuide, required this.onOpenSupport, required this.onOpenNews});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          ActionCard(icon: Icons.vpn_key_rounded, title: 'Мои ключи', text: 'Скопировать подписку', onTap: onOpenAccount),
          ActionCard(icon: Icons.local_offer_rounded, title: 'Тарифы', text: 'Оплата и промокод', onTap: onOpenTariffs),
          ActionCard(icon: Icons.menu_book_rounded, title: 'Гайд', text: 'Как подключиться', onTap: onOpenGuide),
          ActionCard(icon: Icons.newspaper_rounded, title: 'Новости', text: 'Канал GhostNet', onTap: onOpenNews),
          ActionCard(icon: Icons.support_agent_rounded, title: 'Поддержка', text: 'Чат в приложении', onTap: onOpenSupport),
        ];
        final columns = constraints.maxWidth > 1100 ? 5 : constraints.maxWidth > 820 ? 3 : constraints.maxWidth > 520 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((e) => SizedBox(width: (constraints.maxWidth - 12 * (columns - 1)) / columns, child: e)).toList(),
        );
      },
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  const ActionCard({super.key, required this.icon, required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: PremiumCard(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CircleIcon(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(text, style: const TextStyle(color: GhostColors.muted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: GhostColors.orange),
          ],
        ),
      ),
    );
  }
}

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final children = const [
          StatCard(title: '24 часа', subtitle: 'пробный период', icon: Icons.card_giftcard_rounded),
          StatCard(title: '1 Гбит', subtitle: 'скорость канала', icon: Icons.speed_rounded),
          StatCard(title: '3 устройства', subtitle: 'одновременно', icon: Icons.devices_rounded),
          StatCard(title: '∞', subtitle: 'безлимитный трафик', icon: Icons.all_inclusive_rounded),
        ];
        final columns = constraints.maxWidth > 850 ? 4 : constraints.maxWidth > 520 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children.map((e) => SizedBox(width: (constraints.maxWidth - 12 * (columns - 1)) / columns, child: e)).toList(),
        );
      },
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const StatCard({super.key, required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: GhostColors.orangeSoft)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: GhostColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class AdminReferralPanel extends StatelessWidget {
  final AdminReferralStats stats;

  const AdminReferralPanel({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: const [
        CircleIcon(icon: Icons.group_add_rounded),
        SizedBox(width: 10),
        Expanded(child: Text('Реферальная система', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      ]),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _ReferralMiniStat(icon: Icons.person_add_alt_1_rounded, value: '${stats.invitedTotal}', label: 'приглашено'),
          _ReferralMiniStat(icon: Icons.payments_rounded, value: '${stats.paidTotal}', label: 'оплатили'),
          _ReferralMiniStat(icon: Icons.card_giftcard_rounded, value: '${stats.rewardedTotal}', label: 'бонусов'),
          _ReferralMiniStat(icon: Icons.calendar_month_rounded, value: '+${stats.bonusDaysTotal}', label: 'дней'),
        ]),
      ),
      const SizedBox(height: 12),
      if (stats.items.isEmpty)
        const Text('Пока нет рефералов.', style: TextStyle(color: GhostColors.muted))
      else
        ...stats.items.take(8).map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(.07))),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: GhostColors.orange.withOpacity(.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: GhostColors.orange.withOpacity(.22))),
                child: const Icon(Icons.group_rounded, color: GhostColors.orange, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.referrerEmail} → ${r.referredEmail}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                const SizedBox(height: 3),
                Text('${r.referralCode} • ${r.status} • +${r.rewardDays} дн.', style: const TextStyle(color: GhostColors.muted, fontSize: 12)),
              ])),
              if (r.paymentId != null) MiniBadge(text: 'PAY #${r.paymentId}'),
            ]),
          ),
        )),
    ]));
  }
}

class AdminCompactStatsLine extends StatelessWidget {
  final AdminOverview overview;

  const AdminCompactStatsLine({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    final items = [
      _AdminStatItem(Icons.people_rounded, '${overview.users}', 'Пользователи'),
      _AdminStatItem(Icons.vpn_key_rounded, '${overview.activeSubscriptions}', 'Активные ключи'),
      _AdminStatItem(Icons.payment_rounded, '${overview.payments}', 'Платежи'),
      _AdminStatItem(Icons.local_activity_rounded, '${overview.ticketsOpen}', 'Поддержка'),
      _AdminStatItem(Icons.confirmation_number_rounded, '${overview.promocodesActive}', 'Промокоды'),
    ];
    return PremiumCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 920 ? 5 : constraints.maxWidth > 620 ? 3 : 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((item) => SizedBox(
            width: (constraints.maxWidth - 10 * (columns - 1)) / columns,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GhostColors.orange.withOpacity(.20)),
              ),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: GhostColors.orange.withOpacity(.13), borderRadius: BorderRadius.circular(12)),
                  child: Icon(item.icon, color: GhostColors.orange, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GhostColors.orangeSoft, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 1),
                  Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GhostColors.muted, fontWeight: FontWeight.w800, fontSize: 11)),
                ])),
              ]),
            ),
          )).toList(),
        );
      }),
    );
  }
}

class _AdminStatItem {
  final IconData icon;
  final String value;
  final String label;
  const _AdminStatItem(this.icon, this.value, this.label);
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: GhostColors.muted)),
      ],
    );
  }
}

class AdvantageGrid extends StatelessWidget {
  const AdvantageGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      AdvantageTile(icon: Icons.lock_rounded, title: 'Защита', text: 'Приватное подключение для ежедневного использования.'),
      AdvantageTile(icon: Icons.flash_on_rounded, title: 'Скорость', text: 'Подключение без лишних сложностей.'),
      AdvantageTile(icon: Icons.phone_android_rounded, title: 'Устройства', text: 'Телефон, ПК, планшет и другие устройства.'),
      AdvantageTile(icon: Icons.telegram_rounded, title: 'Управление', text: 'Покупка, продление и помощь внутри приложения.'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 720 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((e) => SizedBox(width: (constraints.maxWidth - 12 * (columns - 1)) / columns, child: e)).toList(),
        );
      },
    );
  }
}

class AdvantageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const AdvantageTile({super.key, required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 5),
                Text(text, style: const TextStyle(color: GhostColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PromoPanel extends StatelessWidget {
  final TextEditingController controller;
  final String? appliedCode;
  final String? message;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const PromoPanel({super.key, required this.controller, required this.appliedCode, required this.message, required this.onApply, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      highlighted: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 620;
          final input = GhostTextField(controller: controller, label: 'Промокод', icon: Icons.confirmation_number_rounded);
          final apply = SecondaryButton(
            text: 'Применить',
            icon: Icons.check_rounded,
            onPressed: onApply,
          );
          final clear = SecondaryButton(
            text: 'Очистить',
            icon: Icons.clear_rounded,
            onPressed: onClear,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MiniBadge(text: 'ПЕРВАЯ ПОКУПКА'),
              const SizedBox(height: 14),
              const Text('Введите промокод перед покупкой', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('Доступный промокод: WELCOME. Нажмите «Применить», и скидка будет учтена при оплате.', style: TextStyle(color: GhostColors.muted, height: 1.4)),
              const SizedBox(height: 16),
              if (wide)
                Row(children: [Expanded(child: input), const SizedBox(width: 12), apply, const SizedBox(width: 12), clear])
              else
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  input,
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: apply),
                    const SizedBox(width: 10),
                    Expanded(child: clear),
                  ]),
                ]),
              if ((message ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(message!, style: TextStyle(color: appliedCode == null ? GhostColors.gold : GhostColors.success, fontWeight: FontWeight.w800)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class TariffCard extends StatelessWidget {
  final Tariff tariff;
  final VoidCallback onBuy;

  const TariffCard({super.key, required this.tariff, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final features = _tariffFeatures(tariff.code);
    final ribbon = _tariffRibbon(tariff);
    return PremiumCard(
      highlighted: tariff.highlighted,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [GhostColors.orange.withOpacity(.18), GhostColors.gold.withOpacity(.10)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: GhostColors.orange.withOpacity(.28)),
                boxShadow: [BoxShadow(color: GhostColors.orange.withOpacity(.12), blurRadius: 20)],
              ),
              child: Icon(_tariffIconData(tariff.code), color: GhostColors.orangeSoft, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(tariff.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                if (ribbon != null) MiniBadge(text: ribbon),
              ]),
              const SizedBox(height: 3),
              Text(tariff.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GhostColors.muted, height: 1.25, fontSize: 12.5)),
            ])),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(color: Colors.black.withOpacity(.22), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(.06))),
            child: Row(children: [
              Expanded(child: RichText(text: TextSpan(children: [
                TextSpan(text: '${tariff.price} ₽', style: const TextStyle(fontSize: 25, color: GhostColors.orangeSoft, fontWeight: FontWeight.w900)),
                TextSpan(text: ' / ${tariff.period}', style: const TextStyle(color: GhostColors.muted, fontWeight: FontWeight.w800, fontSize: 12)),
              ]))),
              SizedBox(width: 104, child: PrimaryButton(text: 'Купить', icon: Icons.payment_rounded, onPressed: onBuy)),
            ]),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: features.map((feature) => TariffFeaturePill(icon: feature.icon, text: feature.text)).toList(),
          ),
        ],
      ),
    );
  }
}


class TariffFeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const TariffFeaturePill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GhostColors.orange.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: GhostColors.orange),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TariffFeature {
  final IconData icon;
  final String text;
  const _TariffFeature(this.icon, this.text);
}

List<_TariffFeature> _tariffFeatures(String code) {
  final base = <_TariffFeature>[
    const _TariffFeature(Icons.devices_rounded, '3 устройства'),
    const _TariffFeature(Icons.all_inclusive_rounded, 'Безлимит'),
  ];
  if (code == 'ghost_start') return [...base, const _TariffFeature(Icons.bolt_rounded, 'Быстрый старт')];
  if (code == 'ghost_net') return [...base, const _TariffFeature(Icons.star_rounded, 'Популярный')];
  if (code == 'ghost_plus') return [...base, const _TariffFeature(Icons.savings_rounded, 'Выгодно')];
  if (code == 'ghost_premium') return [...base, const _TariffFeature(Icons.workspace_premium_rounded, 'Премиум')];
  if (code == 'ghost_ultimate') return [...base, const _TariffFeature(Icons.diamond_rounded, 'Максимум')];
  return base;
}

String? _tariffRibbon(Tariff tariff) {
  if (tariff.badge != null) return tariff.badge;
  if (tariff.code == 'ghost_plus') return 'ВЫГОДНО';
  if (tariff.code == 'ghost_premium') return 'ПРЕМИУМ';
  return null;
}

class AccountHero extends StatelessWidget {
  final UserProfile profile;

  const AccountHero({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      highlighted: true,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          const LogoOrb(size: 76),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MiniBadge(text: 'АККАУНТ'),
                const SizedBox(height: 8),
                Text(profile.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(profile.telegram, style: const TextStyle(color: GhostColors.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubscriptionStatusCard extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback onOpenTariffs;

  const SubscriptionStatusCard({super.key, required this.profile, required this.onOpenTariffs});

  @override
  State<SubscriptionStatusCard> createState() => _SubscriptionStatusCardState();
}

class _SubscriptionStatusCardState extends State<SubscriptionStatusCard> {
  bool _loading = true;
  String? _error;
  List<SubscriptionInfo> _subscriptions = const [];
  String? _manualUrl;
  ManualSubscriptionMeta? _manualMeta;

  @override
  void initState() {
    super.initState();
    manualSubscriptionRevision.addListener(_handleManualSubscriptionChanged);
    _load();
  }

  @override
  void dispose() {
    manualSubscriptionRevision.removeListener(_handleManualSubscriptionChanged);
    super.dispose();
  }

  void _handleManualSubscriptionChanged() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    List<SubscriptionInfo> subs = const [];
    String? loadError;
    try {
      subs = await GhostApi.mySubscriptions(widget.profile.token);
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
    }
    final manualUrl = await _loadManualSubscriptionUrl();
    var manualMeta = await ManualSubscriptionMeta.load();
    final matched = _findSubscriptionByUrl(subs, manualUrl);
    if (matched != null) {
      final refreshedMeta = ManualSubscriptionMeta.fromSubscription(matched, serverCount: manualMeta?.serverCount ?? 0);
      manualMeta = refreshedMeta;
      await ManualSubscriptionMeta.save(refreshedMeta);
    }
    if (!mounted) return;
    setState(() {
      _subscriptions = subs;
      _manualUrl = manualUrl;
      _manualMeta = manualMeta;
      _error = loadError;
      _loading = false;
    });
  }

  SubscriptionInfo? get _displaySubscription {
    final matched = _findSubscriptionByUrl(_subscriptions, _manualUrl);
    if (matched != null) return matched;
    if (_manualUrl != null && _manualMeta != null) return _manualMeta!.toSubscription(_manualUrl!);
    for (final sub in _subscriptions) {
      if (sub.status.toLowerCase() == 'active') return sub;
    }
    return _subscriptions.isEmpty ? null : _subscriptions.first;
  }

  Future<void> _copy(String? text, String message) async {
    final value = text?.trim();
    if (value == null || value.isEmpty) {
      _showSnack(context, 'Пока нечего копировать.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MiniBadge(text: 'ПОДПИСКА'),
            SizedBox(height: 14),
            Text('Загружаем подписки...', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            SizedBox(height: 14),
            LinearProgressIndicator(minHeight: 3),
          ],
        ),
      );
    }

    if (_error != null && _displaySubscription == null) {
      return PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MiniBadge(text: 'ПОДПИСКА'),
            const SizedBox(height: 14),
            const Text('Не удалось загрузить подписки', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: GhostColors.gold, height: 1.45)),
            const SizedBox(height: 16),
            SecondaryButton(text: 'Обновить', icon: Icons.refresh_rounded, onPressed: _load),
          ],
        ),
      );
    }

    final sub = _displaySubscription;
    if (sub == null) {
      return PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MiniBadge(text: 'ПОДПИСКА'),
            const SizedBox(height: 14),
            const Text('Активных ключей пока нет', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('После оплаты или ручной выдачи через API подписка появится здесь автоматически.', style: TextStyle(color: GhostColors.muted, height: 1.45)),
            const SizedBox(height: 18),
            PrimaryButton(text: 'Приобрести подписку', icon: Icons.shopping_cart_rounded, onPressed: widget.onOpenTariffs),
          ],
        ),
      );
    }

    final active = sub.status.toLowerCase() == 'active';
    final keyCountFromKey = (sub.vpnKey ?? '').split('\n').where((e) => e.trim().isNotEmpty).length;
    final keyCount = keyCountFromKey > 0 ? keyCountFromKey : (_manualMeta?.serverCount ?? 0);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MiniBadge(text: 'МОЯ ПОДПИСКА'),
          const SizedBox(height: 14),
          Text(sub.planName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(sub.vpnKeyName, style: const TextStyle(color: GhostColors.muted, height: 1.45)),
          const SizedBox(height: 18),
          StatusLine(label: 'Статус', value: active ? 'Активна' : sub.status, color: active ? GhostColors.success : GhostColors.gold),
          const SizedBox(height: 10),
          StatusLine(label: 'Активна до', value: formatDate(sub.expiresAt)),
          const SizedBox(height: 10),
          StatusLine(label: 'Устройств', value: 'до ${sub.deviceLimit}'),
          const SizedBox(height: 10),
          StatusLine(label: 'Серверов', value: keyCount > 0 ? '$keyCount' : 'подписка'),
          const SizedBox(height: 18),
          PrimaryButton(text: 'Скопировать подписку', icon: Icons.copy_rounded, onPressed: () => _copy(sub.subscriptionUrl, 'Ссылка подписки скопирована.')),
          const SizedBox(height: 12),
          SecondaryButton(text: 'Скопировать VLESS-ключи', icon: Icons.vpn_key_rounded, onPressed: () => _copy(sub.vpnKey, 'VLESS-ключи скопированы.')),
          const SizedBox(height: 12),
          SecondaryButton(text: 'Обновить', icon: Icons.refresh_rounded, onPressed: _load),
        ],
      ),
    );
  }
}

class AccountActions extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onOpenTariffs;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenNotifications;

  const AccountActions({super.key, required this.onLogout, required this.onOpenTariffs, required this.onOpenSupport, required this.onOpenNotifications});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MiniBadge(text: 'БЫСТРЫЕ ДЕЙСТВИЯ'),
          const SizedBox(height: 14),
          PrimaryButton(text: 'Купить / продлить', icon: Icons.update_rounded, onPressed: onOpenTariffs),
          const SizedBox(height: 12),
          SecondaryButton(
            text: 'Проверить обновления',
            icon: Icons.system_update_alt_rounded,
            onPressed: () => AppUpdateService.check(context, manual: true),
          ),
          const SizedBox(height: 12),
          SecondaryButton(text: 'Поддержка', icon: Icons.support_agent_rounded, onPressed: onOpenSupport),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withOpacity(.07)),
          const SizedBox(height: 10),
          TextButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout_rounded), label: const Text('Выйти из профиля')),
        ],
      ),
    );
  }
}

class HelpStep extends StatelessWidget {
  final String number;
  final String title;
  final String text;

  const HelpStep({super.key, required this.number, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [GhostColors.orange, GhostColors.gold]),
              boxShadow: [BoxShadow(color: GhostColors.orange.withOpacity(.32), blurRadius: 18)],
            ),
            child: Text(number, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(color: GhostColors.muted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GhostBottomNav extends StatelessWidget {
  final int index;
  final bool showAdmin;
  final ValueChanged<int> onSelect;

  const GhostBottomNav({super.key, required this.index, required this.showAdmin, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: index,
      height: 70,
      backgroundColor: const Color(0xF20C0C0C),
      indicatorColor: GhostColors.orange.withOpacity(.16),
      onDestinationSelected: onSelect,
      destinations: [
        const NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Главная'),
        const NavigationDestination(icon: Icon(Icons.local_offer_rounded), label: 'Тарифы'),
        const NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Кабинет'),
        const NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'Гайд'),
        const NavigationDestination(icon: Icon(Icons.help_rounded), label: 'Помощь'),
        if (showAdmin) const NavigationDestination(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Админ'),
      ],
    );
  }
}

class GhostSideBar extends StatelessWidget {
  final int index;
  final bool showAdmin;
  final ValueChanged<int> onSelect;

  const GhostSideBar({super.key, required this.index, required this.showAdmin, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _MenuItem(Icons.home_rounded, 'Главная'),
      const _MenuItem(Icons.local_offer_rounded, 'Тарифы'),
      const _MenuItem(Icons.person_rounded, 'Кабинет'),
      const _MenuItem(Icons.menu_book_rounded, 'Гайд'),
      const _MenuItem(Icons.help_rounded, 'Помощь'),
      if (showAdmin) const _MenuItem(Icons.admin_panel_settings_rounded, 'Админ'),
    ];
    return Container(
      width: 246,
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xCC101010),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.32), blurRadius: 26)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LogoHeader(compact: true),
          const SizedBox(height: 28),
          ...List.generate(items.length, (i) {
            final item = items[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SideNavTile(icon: item.icon, label: item.label, selected: index == i, onTap: () => onSelect(i)),
            );
          }),
          const Spacer(),
          const MiniBadge(text: 'GHOSTNET'),
          const SizedBox(height: 10),
          const Text('Быстро. Стабильно. Безлимитно.', style: TextStyle(color: GhostColors.muted, height: 1.35)),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;

  const _MenuItem(this.icon, this.label);
}

class SideNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SideNavTile({super.key, required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? GhostColors.orange.withOpacity(.16) : Colors.transparent,
          border: Border.all(color: selected ? GhostColors.orange.withOpacity(.34) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? GhostColors.orangeSoft : GhostColors.muted),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: selected ? GhostColors.text : GhostColors.muted)),
          ],
        ),
      ),
    );
  }
}


class PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const PageTitle({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 370 ? 24.0 : width < 520 ? 27.0 : 31.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, height: 1.08)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: GhostColors.muted, height: 1.4)),
      ],
    );
  }
}

class GhostTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscureText;
  final int maxLines;

  const GhostTextField({super.key, required this.controller, required this.label, this.icon, this.obscureText = false, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      enableSuggestions: !obscureText,
      autocorrect: !obscureText,
      style: const TextStyle(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        prefixIcon: icon == null ? null : Icon(icon, color: GhostColors.orange),
        labelText: label,
        filled: true,
        fillColor: Colors.black.withOpacity(.28),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withOpacity(.07))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: GhostColors.orange, width: 1.4)),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const PrimaryButton({super.key, required this.text, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7A00), Color(0xFFFF8C00), Color(0xFFFFA033)],
          stops: [.0, .55, 1.0],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(color: GhostColors.orange.withOpacity(.34), blurRadius: 18, spreadRadius: .5, offset: const Offset(0, 7)),
          BoxShadow(color: Colors.black.withOpacity(.32), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon ?? Icons.arrow_forward_rounded, color: Colors.black, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
    if (onPressed == null) return Opacity(opacity: .6, child: child);
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onPressed, child: child);
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  const SecondaryButton({super.key, required this.text, required this.onPressed, this.icon, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final accent = danger ? GhostColors.danger : GhostColors.orange;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? const Color(0xFFFF9A9A) : GhostColors.text,
        backgroundColor: danger ? GhostColors.danger.withOpacity(.07) : null,
        side: BorderSide(color: accent.withOpacity(.42)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.open_in_new_rounded, color: accent),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}


class CompactButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;

  const CompactButton({super.key, required this.text, required this.icon, required this.onPressed, this.filled = false, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final accent = danger ? GhostColors.danger : GhostColors.orange;
    final child = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: filled && !danger
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF7A00), Color(0xFFFF8C00), Color(0xFFFFA033)],
                stops: [.0, .58, 1.0],
              )
            : null,
        color: filled && danger ? GhostColors.danger : Colors.black.withOpacity(.18),
        borderRadius: BorderRadius.circular(16),
        border: filled
            ? Border.all(color: Colors.white.withOpacity(.34), width: 1.2)
            : Border.all(color: accent.withOpacity(.42)),
        boxShadow: filled
            ? [
                BoxShadow(color: GhostColors.orange.withOpacity(.42), blurRadius: 18, spreadRadius: .5, offset: const Offset(0, 7)),
                BoxShadow(color: Colors.black.withOpacity(.34), blurRadius: 8, offset: const Offset(0, 4)),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: filled ? Colors.black : accent, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: filled ? Colors.black : GhostColors.text,
                fontWeight: FontWeight.w900,
                fontSize: 13.2,
                letterSpacing: .05,
              ),
            ),
          ),
        ],
      ),
    );
    if (onPressed == null) return Opacity(opacity: .62, child: child);
    return InkWell(borderRadius: BorderRadius.circular(15), onTap: onPressed, child: child);
  }
}

class GhostIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GhostIconButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GhostColors.orange.withOpacity(.26)),
          boxShadow: [BoxShadow(color: GhostColors.orange.withOpacity(.08), blurRadius: 18)],
        ),
        child: Icon(icon, color: GhostColors.orange),
      ),
    );
  }
}


class BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  const BadgeIconButton({super.key, required this.icon, required this.badgeCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;
    final label = badgeCount > 99 ? '99+' : badgeCount.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GhostIconButton(icon: icon, onTap: onTap),
        if (hasBadge)
          Positioned(
            right: 5,
            top: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [GhostColors.orange, GhostColors.gold]),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GhostColors.black, width: 2),
                boxShadow: [BoxShadow(color: GhostColors.orange.withOpacity(.35), blurRadius: 12)],
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900, height: 1),
              ),
            ),
          ),
      ],
    );
  }
}

class FeaturePill extends StatelessWidget {
  final IconData icon;
  final String text;

  const FeaturePill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GhostColors.orange.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16, color: GhostColors.orange), const SizedBox(width: 7), Text(text, style: const TextStyle(fontWeight: FontWeight.w800))],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  final IconData icon;

  const CircleIcon({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GhostColors.orange.withOpacity(.13),
        border: Border.all(color: GhostColors.orange.withOpacity(.24)),
      ),
      child: Icon(icon, color: GhostColors.orange, size: 20),
    );
  }
}


Future<void> showGhostDialog(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
  required bool success,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: GhostColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: (success ? GhostColors.success : GhostColors.orange).withOpacity(.35))),
        title: Row(
          children: [
            Icon(icon, color: success ? GhostColors.success : GhostColors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
          ],
        ),
        content: Text(message, style: const TextStyle(color: GhostColors.muted, height: 1.45)),
        actions: [
          PrimaryButton(text: 'ОК', icon: Icons.check_rounded, onPressed: () => Navigator.pop(context)),
        ],
      );
    },
  );
}

Future<bool?> showPaymentStatusDialog(BuildContext context, String token, int paymentId) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PaymentStatusDialog(token: token, paymentId: paymentId),
  );
}

class PaymentStatusDialog extends StatefulWidget {
  final String token;
  final int paymentId;

  const PaymentStatusDialog({super.key, required this.token, required this.paymentId});

  @override
  State<PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<PaymentStatusDialog> {
  Timer? _timer;
  bool _checking = true;
  bool _done = false;
  bool _success = false;
  String _title = 'Ожидаем оплату';
  String _message = 'Завершите оплату в ЮKassa. После успешной оплаты подписка появится в кабинете автоматически.';

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_done) return;
    try {
      final status = await GhostApi.paymentStatus(token: widget.token, paymentId: widget.paymentId);
      if (!mounted) return;
      if (status.isSuccess) {
        _timer?.cancel();
        setState(() {
          _checking = false;
          _done = true;
          _success = true;
          _title = 'Успешно оплачено';
          _message = 'Оплата прошла успешно. Подписка создана и уже доступна в разделе «Мои ключи».';
        });
      } else if (status.isCanceled) {
        _timer?.cancel();
        setState(() {
          _checking = false;
          _done = true;
          _success = false;
          _title = 'Оплата отменена';
          _message = 'Платёж был отменён. Подписка не создана, деньги не списаны.';
        });
      } else {
        setState(() {
          _checking = false;
          _title = 'Ожидаем оплату';
          _message = 'Пока платёж не завершён. Вернитесь на страницу оплаты или нажмите «Проверить» после оплаты.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _done ? (_success ? GhostColors.success : GhostColors.danger) : GhostColors.orange;
    final icon = _done ? (_success ? Icons.check_circle_rounded : Icons.cancel_rounded) : Icons.payment_rounded;

    return AlertDialog(
      backgroundColor: GhostColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: color.withOpacity(.35))),
      title: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(_title, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_message, style: const TextStyle(color: GhostColors.muted, height: 1.45)),
          if (_checking || !_done) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 3),
          ],
        ],
      ),
      actions: [
        if (!_done) SecondaryButton(text: 'Проверить', icon: Icons.refresh_rounded, onPressed: _check),
        if (!_done) TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Закрыть')),
        if (_done) PrimaryButton(text: _success ? 'Открыть кабинет' : 'Понятно', icon: _success ? Icons.vpn_key_rounded : Icons.close_rounded, onPressed: () => Navigator.pop(context, _success)),
      ],
    );
  }
}

Future<void> openExternal(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw Exception('Не удалось открыть ссылку: $url');
  }
}

void _showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
