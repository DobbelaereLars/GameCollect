import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service voor het veilig opslaan van gevoelige gegevens zoals API-sleutels.
///
/// Maakt gebruik van [FlutterSecureStorage], die op iOS de Keychain gebruikt
/// en op Android de EncryptedSharedPreferences. De RAWG API-sleutel wordt bij
/// de eerste start uit de .env-configuratie gelezen en vervolgens uitsluitend
/// via de veilige opslag geraadpleegd.
class SecureStorageService {
  SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    // iOS: sla op in de Keychain met toegankelijkheid na eerste ontgrendeling.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _rawgKeyName = 'rawg_api_key';

  /// In-memory cache zodat de sleutel na initialisatie synchroon beschikbaar is.
  static String _rawgApiKey = '';

  /// Leesbare getter voor de RAWG API-sleutel (na [initialize]).
  static String get rawgApiKey => _rawgApiKey;

  /// Initialiseert de service.
  ///
  /// Leest de RAWG API-sleutel uit de veilige opslag. Als er nog geen sleutel
  /// aanwezig is (eerste start), wordt de waarde uit [dotenv] gemigreerd en
  /// veilig opgeslagen voor toekomstig gebruik.
  static Future<void> initialize() async {
    try {
      String? stored = await _storage.read(key: _rawgKeyName);
      final fromEnv = dotenv.env['RAWG_API_KEY'] ?? '';

      // Overschrijf de Keychain als .env een waarde heeft die afwijkt
      // (bijv. na een build met een gewijzigde API-sleutel).
      if (fromEnv.isNotEmpty && fromEnv != stored) {
        await _storage.write(key: _rawgKeyName, value: fromEnv);
        stored = fromEnv;
        debugPrint('[SecureStorage] RAWG-sleutel bijgewerkt vanuit .env.');
      } else if (stored == null || stored.isEmpty) {
        debugPrint('[SecureStorage] Geen RAWG-sleutel beschikbaar.');
      }

      _rawgApiKey = stored ?? '';
    } catch (e) {
      // Veilige opslag niet beschikbaar (bijv. emulator zonder encryptie):
      // val terug op .env zodat de app operationeel blijft.
      debugPrint(
        '[SecureStorage] Kon niet initialiseren, terugvallen op .env: $e',
      );
      _rawgApiKey = dotenv.env['RAWG_API_KEY'] ?? '';
    }
  }

  /// Slaat een aangepaste API-sleutel op in de veilige opslag.
  ///
  /// Handig voor toekomstige functionaliteit waarbij de gebruiker een eigen
  /// RAWG API-sleutel kan invoeren.
  static Future<void> setRawgApiKey(String key) async {
    await _storage.write(key: _rawgKeyName, value: key);
    _rawgApiKey = key;
  }
}
