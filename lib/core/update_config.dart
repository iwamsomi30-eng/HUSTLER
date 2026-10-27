/// Mipangilio ya masasisho (updates).
///
/// 1) Firestore (chanzo kikuu): Firebase project ya TAG. App inasoma hati
///    `app_updates/android` na `app_updates/windows` kupitia REST (hakuna
///    firebase_core wala plugin yoyote ya ziada).
/// 2) GitHub Releases (akiba): inatumika Firestore ikiwa haina hati bado.
///    Repo inawekwa AUTOMATIC na GitHub Actions (--dart-define=GITHUB_REPO=...).
class UpdateConfig {
  static const repo = String.fromEnvironment('GITHUB_REPO');

  /// Project ID ya Firebase (si siri). Inaweza kubadilishwa kwa
  /// --dart-define=FIREBASE_PROJECT_ID=... ikihitajika.
  static const firebaseProjectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'tag-750a0');

  /// Web API Key ya Firebase (hiari - si siri, ni kitambulisho cha project tu).
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');

  static bool get firestoreEnabled => firebaseProjectId.trim().isNotEmpty;
  static bool get githubEnabled => repo.contains('/');
  static bool get enabled => firestoreEnabled || githubEnabled;
}
