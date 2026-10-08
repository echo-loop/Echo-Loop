import 'package:echo_loop/config/auth_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'China users select the China URL while global users keep the global URL',
    () {
      expect(
        supabaseUrlForRegion(
          isChinaUser: true,
          globalUrl: 'https://global.example',
          chinaUrl: 'https://china.example',
        ),
        'https://china.example',
      );
      expect(
        supabaseUrlForRegion(
          isChinaUser: false,
          globalUrl: 'https://global.example',
          chinaUrl: 'https://china.example',
        ),
        'https://global.example',
      );
    },
  );

  test('missing China URL does not fall back to the global URL', () {
    expect(
      supabaseUrlForRegion(
        isChinaUser: true,
        globalUrl: 'https://global.example',
        chinaUrl: '  ',
      ),
      isNull,
    );
  });

  test('Supabase log endpoint excludes credentials, path, and query', () {
    expect(
      supabaseEndpointLabelForLog(
        'https://user:password@auth.example:8443/project?token=secret#section',
      ),
      'https://auth.example:8443',
    );
  });

  test('Supabase log endpoint labels missing or invalid URLs', () {
    expect(supabaseEndpointLabelForLog(null), 'unconfigured');
    expect(supabaseEndpointLabelForLog('not-a-url'), 'invalid');
  });

  test('auth requires both selected URL and publishable key', () {
    expect(
      isAuthConfiguredForUrl(
        'https://china.example',
        publishableKey: 'public-key',
      ),
      isTrue,
    );
    expect(isAuthConfiguredForUrl(null, publishableKey: 'public-key'), isFalse);
    expect(
      isAuthConfiguredForUrl('https://china.example', publishableKey: ' '),
      isFalse,
    );
  });
}
