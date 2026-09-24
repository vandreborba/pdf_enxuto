/// Informações centrais do projeto: nome, repositório e links usados no app,
/// no README e nos scripts.
///
/// Manter tudo aqui garante que, ao renomear o repositório, exista um único
/// lugar para ajustar.
class AppInfo {
  AppInfo._();

  static const String appName = 'PDF Enxuto';
  static const String appId = 'pdf-enxuto';
  static const String tagline =
      'Comprima e divida PDFs sem sair do seu computador';
  static const String description =
      'Compressor e divisor de PDF 100% local. Nenhum arquivo sai do seu '
      'computador: tudo é processado na sua máquina, sem conta, sem nuvem e '
      'sem anúncios.';

  /// Repositório no GitHub (código-fonte, releases e issues).
  static const String repoOwner = 'vandreborba';
  static const String repoName = 'pdf_enxuto';
  static const String repo = '$repoOwner/$repoName';

  /// Canal de contato dos apps do Vandre (problemas e sugestões).
  static const String email = 'vandreapps@gmail.com';

  static const String sourceUrl = 'https://github.com/$repo';
  static const String issuesUrl = 'https://github.com/$repo/issues/new/choose';
  static const String issuesListUrl = 'https://github.com/$repo/issues';
  static const String releasesUrl = 'https://github.com/$repo/releases/latest';
  static const String releasesListUrl = 'https://github.com/$repo/releases';
  static const String licenseUrl = 'https://www.gnu.org/licenses/gpl-3.0.html';
  static const String changelogUrl = 'https://github.com/$repo/releases';

  /// Nome do pacote `.deb` e do binário no Linux.
  static const String linuxBinary = 'pdf-enxuto';
  static const String debPackage = 'pdf-enxuto';

  /// Assuntos usados nos e-mails de contato.
  static const String assuntoProblema = 'Problema no PDF Enxuto';
  static const String assuntoRecurso = 'Sugestão de recurso para o PDF Enxuto';

  /// Nome do executável no Windows.
  static const String windowsExecutable = 'pdf_enxuto.exe';
}
