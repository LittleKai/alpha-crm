class LocalDbSchema {
  static const int version = 3;

  // Snapshot of a scheduled (pending) bulk campaign so it survives navigation
  // and app restart. Recipients are stored as a JSON array of {id,name}.
  static const String _scheduledCampaignsTable = '''
    CREATE TABLE IF NOT EXISTS scheduled_campaigns (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL DEFAULT '',
      message TEXT NOT NULL DEFAULT '',
      isGroupMessage INTEGER NOT NULL DEFAULT 0,
      recipientsJson TEXT NOT NULL DEFAULT '[]',
      accountId TEXT,
      minDelay INTEGER NOT NULL DEFAULT 30,
      maxDelay INTEGER NOT NULL DEFAULT 60,
      requireHumanApproval INTEGER NOT NULL DEFAULT 0,
      scheduledAt INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      createdAt INTEGER NOT NULL
    )
    ''';

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
      clientMessageId TEXT,
      senderId TEXT,
      senderName TEXT,
      direction TEXT,
      messageType TEXT,
      content TEXT,
      status TEXT,
      errorText TEXT,
      quoteJson TEXT,
      mentionsJson TEXT,
      stylesJson TEXT,
      metadataJson TEXT,
      recalledContent TEXT,
      attachments TEXT,
      createdAt INTEGER NOT NULL
    )
    ''',

    '''
    CREATE TABLE live_chat_drafts (
      accountId TEXT NOT NULL,
      threadId TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '',
      updatedAt INTEGER NOT NULL,
      PRIMARY KEY (accountId, threadId)
    )
    ''',

    '''
    CREATE TABLE live_chat_receipts (
      messageId TEXT NOT NULL,
      userId TEXT NOT NULL,
      status TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      PRIMARY KEY (messageId, userId, status)
    )
    ''',

    '''
    CREATE TABLE live_chat_reactions (
      messageId TEXT NOT NULL,
      userId TEXT NOT NULL,
      reaction TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      PRIMARY KEY (messageId, userId)
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

    _scheduledCampaignsTable,
  ];

  static const List<String> version2Scripts = [
    "ALTER TABLE live_chat_messages ADD COLUMN clientMessageId TEXT",
    "ALTER TABLE live_chat_messages ADD COLUMN errorText TEXT",
    "ALTER TABLE live_chat_messages ADD COLUMN quoteJson TEXT",
    "ALTER TABLE live_chat_messages ADD COLUMN mentionsJson TEXT",
    "ALTER TABLE live_chat_messages ADD COLUMN stylesJson TEXT",
    "ALTER TABLE live_chat_messages ADD COLUMN metadataJson TEXT",
    "ALTER TABLE live_chat_messages ADD COLUMN recalledContent TEXT",
    '''
    CREATE TABLE IF NOT EXISTS live_chat_drafts (
      accountId TEXT NOT NULL,
      threadId TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '',
      updatedAt INTEGER NOT NULL,
      PRIMARY KEY (accountId, threadId)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS live_chat_receipts (
      messageId TEXT NOT NULL,
      userId TEXT NOT NULL,
      status TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      PRIMARY KEY (messageId, userId, status)
    )
    ''',
    '''
    CREATE TABLE IF NOT EXISTS live_chat_reactions (
      messageId TEXT NOT NULL,
      userId TEXT NOT NULL,
      reaction TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      PRIMARY KEY (messageId, userId)
    )
    ''',
  ];

  static const List<String> version3Scripts = [_scheduledCampaignsTable];
}
