/// Extension du fichier envoyé dans Storage.
///
/// BUG M1 corrigé : `split('.').last` sur le chemin complet donnait
/// « app/cache/abc » pour un fichier sans extension dans un dossier pointé
/// (`com.app/cache/abc`) : chemin Storage invalide, envoi refusé. On prend
/// l'extension du **nom** de fichier, sinon celle du type MIME.
String uploadExtension(String filePath, String mimeType) {
  final name = filePath.split('/').last;
  final dot = name.lastIndexOf('.');
  if (dot > 0 && dot < name.length - 1) {
    final ext = name.substring(dot + 1).toLowerCase();
    if (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext)) return ext;
  }
  return switch (mimeType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/heic' => 'heic',
    'video/quicktime' => 'mov',
    _ when mimeType.startsWith('video/') => 'mp4',
    _ => 'jpg',
  };
}
