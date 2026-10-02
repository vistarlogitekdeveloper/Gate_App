enum Environment { dev, stage, prod }

class Env {
  static Environment current = Environment.dev;

  static String get baseUrl {
    switch (current) {
      case Environment.dev:
        return 'https://api.vistarlogitek.com/api/v1/gate';
      //return 'https://uat-api.vistarlogitek.com/api/v1/gate';

      case Environment.stage:
        //return 'https://api.vistarlogitek.com/api/v1/gate';
        return 'https://uat-api.vistarlogitek.com/api/v1/gate';

      case Environment.prod:
        return 'https://api.vistarlogitek.com/api/v1/gate';
      // return 'https://uat-api.vistarlogitek.com/api/v1/gate';
    }
  }

  /// Admin-only backdated gate entries.
  ///
  /// OFF until the business asks for it. Flip to true and rebuild to show the
  /// "Gate Entry Date & Time" control on the create form.
  ///
  /// The server has its own switch — GATE_ALLOW_BACKDATED_ENTRY — and BOTH
  /// must be on. This one only hides the field; the server is what actually
  /// refuses a backdated timestamp, so turning this on alone changes nothing.
  static const bool enableBackdatedGateEntry = true;

  static bool get isDebug => current == Environment.dev;
}
