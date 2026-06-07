/**
 * Type declarations for zca-js — Unofficial Zalo API.
 * These match the public API surface from zca-js/src/index.ts.
 * 
 * NOTE: This file exists because the local zca-js package may not have
 * been built yet (no dist/ folder). Once zca-js is built, this file
 * can be removed and types will come from the package itself.
 */

declare module 'zca-js' {
  // --- Core types ---
  export interface Cookie {
    domain: string;
    expirationDate: number;
    hostOnly: boolean;
    httpOnly: boolean;
    name: string;
    path: string;
    sameSite: string;
    secure: boolean;
    session: boolean;
    storeId: string;
    value: string;
  }

  export interface Credentials {
    imei: string;
    cookie: Cookie[] | { url: string; cookies: Cookie[] };
    userAgent: string;
    language?: string;
  }

  export interface Options {
    selfListen?: boolean;
    logging?: boolean;
    apiType?: number;
    apiVersion?: string;
    agent?: import('http').Agent;
    imageMetadataGetter?: (
      filePath: string,
    ) => Promise<{ width: number; height: number; size: number }>;
  }

  export enum ThreadType {
    User = 0,
    Group = 1,
  }

  export enum FriendEventType {
    ADD = 0,
    REMOVE = 1,
    REQUEST = 2,
    UNDO_REQUEST = 3,
    REJECT_REQUEST = 4,
    SEEN_FRIEND_REQUEST = 5,
    BLOCK = 6,
    UNBLOCK = 7,
    BLOCK_CALL = 8,
    UNBLOCK_CALL = 9,
    PIN_UNPIN = 10,
    PIN_CREATE = 11,
    UNKNOWN = 12,
  }

  export interface SendMessageResult {
    msgId?: string;
  }

  export interface Listener {
    start(): void;
    stop(): void;
    on(event: string, listener: (...args: any[]) => void): this;
    removeAllListeners(event?: string): this;
  }

  export interface MessageContent {
    msg: string;
    attachments?: string | string[];
    mentions?: any[];
    quote?: any;
    ttl?: number;
    styles?: any[];
    urgency?: any;
  }

  export interface UndoMessageData {
    msgId: string;
    cliMsgId: string;
    msgType: number;
    uidFrom: string;
    idTo: string;
  }

  export interface UndoPayload {
    msgId: string;
    cliMsgId: string;
  }

  export interface DeleteMessageDestination {
    data: {
      cliMsgId: string;
      msgId: string;
      uidFrom: string;
    };
    threadId: string;
    type?: ThreadType;
  }

  export interface AddReactionDestination {
    data: {
      msgId: string;
      cliMsgId: string;
    };
    threadId: string;
    type: ThreadType;
  }

  export class API {
    sendMessage(
      content: MessageContent | string,
      threadId: string,
      type?: ThreadType,
    ): Promise<any>;
    undoMessage(
      data: UndoMessageData,
      threadId: string,
      type?: ThreadType,
    ): Promise<any>;
    undo(payload: UndoPayload, threadId: string, type?: ThreadType): Promise<any>;
    deleteMessage(
      destination: DeleteMessageDestination,
      onlyMe?: boolean,
    ): Promise<any>;
    addReaction(
      reaction: string,
      destination: AddReactionDestination,
    ): Promise<any>;
    sendLink(options: any, threadId: string, type?: ThreadType): Promise<any>;
    sendSticker(sticker: any, threadId: string, type?: ThreadType): Promise<any>;
    sendVideo(options: any, threadId: string, type?: ThreadType): Promise<any>;
    sendVoice(options: any, threadId: string, type?: ThreadType): Promise<any>;
    listener: Listener;
    acceptFriendRequest(senderId: string): Promise<any>;
    leaveGroup(groupId: string, silent?: boolean): Promise<any>;
    getAllGroups(): Promise<any>;
    getGroupInfo(groupIds: string | string[]): Promise<any>;
    getAllFriends(count?: number, page?: number, avatarSize?: any): Promise<any[]>;
    getGroupMembersInfo(memberIds: string | string[]): Promise<any>;
    getGroupLinkInfo(payload: { link: string; memberPage?: number }): Promise<any>;
    getOwnId(): string;
    getContext(): any;
    fetchAccountInfo(): Promise<any>;
    createGroup(options: { name?: string; members: string[]; avatarPath?: string }): Promise<any>;
    joinGroupLink(link: string): Promise<any>;
    inviteUserToGroups(userId: string, groupId: string | string[]): Promise<any>;
    addUserToGroup(memberId: string | string[], groupId: string): Promise<any>;
    findUser(phoneNumber: string): Promise<any>;
    sendFriendRequest(message: string, userId: string): Promise<any>;
    getUserInfo(userId: string | string[], avatarSize?: any): Promise<any>;
  }

  export enum LoginQRCallbackEventType {
    QRCodeGenerated = 0,
    QRCodeExpired = 1,
    QRCodeScanned = 2,
    QRCodeDeclined = 3,
    GotLoginInfo = 4,
  }

  export interface LoginQRCallbackEvent {
    type: LoginQRCallbackEventType;
    data?: any;
    actions?: {
      saveToFile: (qrPath?: string) => Promise<unknown>;
      retry: () => unknown;
      abort: () => unknown;
    } | null;
  }

  export type LoginQRCallback = (event: LoginQRCallbackEvent) => void;

  export class Zalo {
    constructor(options?: Partial<Options>);
    login(credentials: Credentials): Promise<API>;
    loginQR(
      options?: { userAgent?: string; language?: string; qrPath?: string },
      callback?: LoginQRCallback,
    ): Promise<API>;
  }
}
