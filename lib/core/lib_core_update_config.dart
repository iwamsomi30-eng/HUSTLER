/// Repo ya GitHub ya app hii ("mmiliki/jina-la-repo").
/// Inawekwa AUTOMATIC na GitHub Actions wakati wa build
/// (--dart-define=GITHUB_REPO=${{ github.repository }}), huhitaji kuiandika.
class UpdateConfig {
  static const repo = String.fromEnvironment('GITHUB_REPO');
  static bool get enabled => repo.contains('/');
}
