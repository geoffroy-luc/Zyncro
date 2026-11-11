/// Stockage distant de fichiers (Firebase Storage en production).
abstract interface class FileStorage {
  /// Envoie [localPath] vers [storagePath] et renvoie l'URL de téléchargement.
  Future<String> upload(
    String localPath,
    String storagePath, {
    required String contentType,
  });

  /// Supprime [storagePath]. Lève une exception si le fichier n'existe pas.
  Future<void> delete(String storagePath);
}
