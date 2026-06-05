class LocalDbSchema {
  static const int version = 1;

  static const List<String> initialScripts = [
    // Generic cache table
    '''
    CREATE TABLE cache_entries (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      expiresAt INTEGER NOT NULL
    )
    ''',

    // Cloud conversation metadata cache
    '''
    CREATE TABLE live_chat_conversations (
      threadId TEXT NOT NULL,
      accountId TEXT NOT NULL,
      threadType TEXT NOT NULL,
      displayName TEXT,
      avatarUrl TEXT,
      lastMessagePreview TEXT,
      lastMessageAt INTEGER,
      unreadCount INTEGER DEFAULT 0,
      deviceId TEXT,
      updatedAt INTEGER NOT NULL,
      PRIMARY KEY (threadId, accountId)
    )
    ''',

    // Local message cache
    '''
    CREATE TABLE live_chat_messages (
      id TEXT PRIMARY KEY,
      conversationId TEXT NOT NULL,
      providerMessageId TEXT,
      senderId TEXT,
      senderName TEXT,
      direction TEXT,
      messageType TEXT,
      content TEXT,
      status TEXT,
      attachments TEXT,
      createdAt INTEGER NOT NULL
    )
    ''',

    // Media cache
    '''
    CREATE TABLE media_cache (
      url TEXT PRIMARY KEY,
      localPath TEXT NOT NULL,
      mimeType TEXT,
      size INTEGER,
      lastAccessedAt INTEGER NOT NULL,
      expiresAt INTEGER NOT NULL
    )
    ''',
  ];
}
