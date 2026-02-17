import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  String _language = 'tk';
  bool _isDarkMode = true;

  String get language => _language;
  bool get isDarkMode => _isDarkMode;

  AppState() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _language = p.getString('lang') ?? 'tk';
    _isDarkMode = p.getBool('dark') ?? true;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString('lang', lang);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark', _isDarkMode);
    notifyListeners();
  }

  String t(String key) =>
      _tr[_language]?[key] ?? _tr['en']?[key] ?? key;

  static const Map<String, Map<String, String>> _tr = {
    'tk': {
      'appName': 'SecureShare',
      'tagline': 'Howpsuz Faýl Paýlaşmak',
      'send': 'IBERMEK',
      'receive': 'ALMAK',
      'sendSub': 'Faýl paýlaş, hotspot aç',
      'receiveSub': 'Faýl al, QR skan et',
      'online': 'Onlaýn',
      'offline': 'Oflaýn',
      'connecting': 'Birikdirilýär...',
      'step1': '1-nji ÄDIM — Hotspot Aç',
      'step1desc': 'Aşakdaky düwmä bas, telefonyň hotspot sazlamalaryny açar. Sen hotspotyny özüň açarsyň.',
      'openHotspotSettings': 'Hotspot Sazlamalaryny Aç',
      'hotspotOpened': 'Hotspot Açdym ✓',
      'step2': '2-nji ÄDIM — Faýl Saýla',
      'selectFile': 'Faýl Saýla we Paýlaş',
      'password': 'Parol (hökmany däl)',
      'maxDownloads': 'Iň köp ýüklemek',
      'expiry': 'Möhlet (minut)',
      'unlimited': 'Çäksiz',
      'shareCode': 'Paýlaşma kody',
      'waitingDesc': 'Beýleki telefon "AL" düwmesine basyp, bu kody ýa-da QR kody ulanmaly',
      'newShare': 'Täze Faýl',
      'back': 'Yza',
      'receiveTitle': 'Faýl Al',
      'receiveStep1': '1-nji ÄDIM — WiFi Bağlan',
      'receiveStep1desc': 'Iberijiniň hotspot adyna WiFi sazlamalaryndan bağlan.',
      'openWifiSettings': 'WiFi Sazlamalaryny Aç',
      'wifiConnected': 'WiFi Bağlandym ✓',
      'receiveStep2': '2-nji ÄDIM — Kod Giriziň ýa-da QR Skan Et',
      'enterCode': 'Kody giriziň',
      'scanQR': 'QR Kody Skan Et',
      'findFile': 'Faýly Tap',
      'download': 'Faýly Ýükle',
      'downloading': 'Ýüklenilýär...',
      'downloaded': 'Ýüklendi! ✅',
      'fileProtected': 'Parol bilen goralan',
      'enterPassword': 'Paroly giriziň',
      'wrongPassword': 'Nädogry parol!',
      'limitReached': 'Ýüklemek çägi doldy!',
      'expired': 'Möhleti doldy!',
      'fileNotFound': 'Faýl tapylmady!',
      'senderIP': 'Iberijiniň IP',
      'dark': 'Garaňky',
      'light': 'Ýagty',
      'language': 'Dil',
      'settings': 'Sazlamalar',
      'fileInfo': 'Faýl maglumaty',
      'fileSize': 'Ölçegi',
      'downloads': 'Ýüklemeler',
      'timeLeft': 'Galan wagt',
      'tip': 'Maslahat',
      'tipText': 'Iberiji ekranyndaky IP adresini görüp, WiFi bilen bağlansaň, QR kody skan edip, faýly alyp bilersiň.',
    },
    'en': {
      'appName': 'SecureShare',
      'tagline': 'Secure File Sharing',
      'send': 'SEND',
      'receive': 'RECEIVE',
      'sendSub': 'Share files via hotspot',
      'receiveSub': 'Receive files via QR',
      'online': 'Online',
      'offline': 'Offline',
      'connecting': 'Connecting...',
      'step1': 'STEP 1 — Open Hotspot',
      'step1desc': 'Tap below to open hotspot settings. Turn on your hotspot yourself.',
      'openHotspotSettings': 'Open Hotspot Settings',
      'hotspotOpened': 'Hotspot is ON ✓',
      'step2': 'STEP 2 — Select File',
      'selectFile': 'Select File & Share',
      'password': 'Password (optional)',
      'maxDownloads': 'Max Downloads',
      'expiry': 'Expiry (minutes)',
      'unlimited': 'Unlimited',
      'shareCode': 'Share Code',
      'waitingDesc': 'Other phone should tap "RECEIVE" and use this code or scan the QR',
      'newShare': 'New File',
      'back': 'Back',
      'receiveTitle': 'Receive File',
      'receiveStep1': 'STEP 1 — Connect to WiFi',
      'receiveStep1desc': 'Connect to the sender\'s hotspot from WiFi settings.',
      'openWifiSettings': 'Open WiFi Settings',
      'wifiConnected': 'WiFi Connected ✓',
      'receiveStep2': 'STEP 2 — Enter Code or Scan QR',
      'enterCode': 'Enter Code',
      'scanQR': 'Scan QR Code',
      'findFile': 'Find File',
      'download': 'Download File',
      'downloading': 'Downloading...',
      'downloaded': 'Downloaded! ✅',
      'fileProtected': 'Password protected',
      'enterPassword': 'Enter Password',
      'wrongPassword': 'Wrong password!',
      'limitReached': 'Download limit reached!',
      'expired': 'Link expired!',
      'fileNotFound': 'File not found!',
      'senderIP': 'Sender IP',
      'dark': 'Dark',
      'light': 'Light',
      'language': 'Language',
      'settings': 'Settings',
      'fileInfo': 'File Info',
      'fileSize': 'Size',
      'downloads': 'Downloads',
      'timeLeft': 'Time Left',
      'tip': 'Tip',
      'tipText': 'Connect to sender\'s hotspot via WiFi, then scan the QR code to download instantly.',
    },
    'ru': {
      'appName': 'SecureShare',
      'tagline': 'Безопасный обмен файлами',
      'send': 'ОТПРАВИТЬ',
      'receive': 'ПОЛУЧИТЬ',
      'sendSub': 'Отправить файл через хотспот',
      'receiveSub': 'Получить файл по QR',
      'online': 'Онлайн',
      'offline': 'Офлайн',
      'connecting': 'Подключение...',
      'step1': 'ШАГ 1 — Включите хотспот',
      'step1desc': 'Нажмите кнопку ниже, чтобы открыть настройки хотспота. Включите хотспот самостоятельно.',
      'openHotspotSettings': 'Открыть настройки хотспота',
      'hotspotOpened': 'Хотспот включён ✓',
      'step2': 'ШАГ 2 — Выберите файл',
      'selectFile': 'Выбрать файл и поделиться',
      'password': 'Пароль (необязательно)',
      'maxDownloads': 'Макс. загрузок',
      'expiry': 'Срок (минуты)',
      'unlimited': 'Без ограничений',
      'shareCode': 'Код доступа',
      'waitingDesc': 'Другой телефон должен нажать «ПОЛУЧИТЬ» и ввести этот код или отсканировать QR',
      'newShare': 'Новый файл',
      'back': 'Назад',
      'receiveTitle': 'Получить файл',
      'receiveStep1': 'ШАГ 1 — Подключитесь к WiFi',
      'receiveStep1desc': 'Подключитесь к хотспоту отправителя через настройки WiFi.',
      'openWifiSettings': 'Открыть настройки WiFi',
      'wifiConnected': 'WiFi подключён ✓',
      'receiveStep2': 'ШАГ 2 — Введите код или отсканируйте QR',
      'enterCode': 'Введите код',
      'scanQR': 'Сканировать QR',
      'findFile': 'Найти файл',
      'download': 'Скачать файл',
      'downloading': 'Скачивание...',
      'downloaded': 'Скачано! ✅',
      'fileProtected': 'Защищено паролем',
      'enterPassword': 'Введите пароль',
      'wrongPassword': 'Неверный пароль!',
      'limitReached': 'Лимит загрузок исчерпан!',
      'expired': 'Срок действия истёк!',
      'fileNotFound': 'Файл не найден!',
      'senderIP': 'IP отправителя',
      'dark': 'Тёмная',
      'light': 'Светлая',
      'language': 'Язык',
      'settings': 'Настройки',
      'fileInfo': 'Информация о файле',
      'fileSize': 'Размер',
      'downloads': 'Загрузок',
      'timeLeft': 'Осталось',
      'tip': 'Совет',
      'tipText': 'Подключитесь к хотспоту отправителя через WiFi, затем отсканируйте QR-код для мгновенного скачивания.',
    },
  };
}
