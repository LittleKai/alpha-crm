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
  }

  export enum ThreadType {
    User = 0,
    Group = 1,
  }

  export interface SendMessageResult {
    msgId?: string;
  }

  export interface Listener {
    start(): void;
    stop(): void;
  }

  export class API {
    sendMessage(
      content: { msg: string },
      threadId: string,
      type?: ThreadType,
    ): Promise<SendMessageResult>;
    listener: Listener;
  }

  export enum LoginQRCallbackEventType {
    GotQRCode = 'gotQRCode',
    GotLoginInfo = 'gotLoginInfo',
  }

  export interface LoginQRCallbackEvent {
    type: LoginQRCallbackEventType;
    data?: Credentials | null;
    actions: unknown;
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
