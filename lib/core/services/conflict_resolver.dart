enum ConflictStrategy { lastWriteWins, serverWins, clientWins }

class ConflictResolver {
  static Future<Map<String, dynamic>> resolve(
    Map<String, dynamic> localPayload,
    Map<String, dynamic> serverPayload,
    ConflictStrategy strategy,
  ) async {
    switch (strategy) {
      case ConflictStrategy.serverWins:
        return serverPayload;
      case ConflictStrategy.clientWins:
        return localPayload;
      case ConflictStrategy.lastWriteWins:
        final localTimestamp =
            DateTime.tryParse(localPayload['updatedAt'] ?? '') ?? DateTime(0);
        final serverTimestamp =
            DateTime.tryParse(serverPayload['updatedAt'] ?? '') ?? DateTime(0);
        return localTimestamp.isAfter(serverTimestamp)
            ? localPayload
            : serverPayload;
    }
  }
}
