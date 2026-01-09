/*
 * DownloadStore.ts - 离线下载数据存储管理
 *
 * 功能说明：
 * - 管理用户离线下载文章列表
 * - 支持新增、删除、清空与读取
 * - 按用户ID隔离下载数据
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { Article } from '../model/Article';

export interface DownloadedArticle extends Article {
  downloadedAt: number;
}

export class DownloadStore {
  private static key(uid: string): string {
    return `download.${uid}.articles`;
  }

  static async getUid(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, 'session.userId', '0');
  }

  static async loadDownloads(ctx: common.UIAbilityContext, uid: string): Promise<DownloadedArticle[]> {
    const raw = await Prefs.getString(ctx, DownloadStore.key(uid), '[]');
    try {
      const list = JSON.parse(raw) as DownloadedArticle[];
      return Array.isArray(list) ? list : [];
    } catch {
      return [];
    }
  }

  static async saveDownloads(
    ctx: common.UIAbilityContext,
    uid: string,
    list: DownloadedArticle[]
  ): Promise<void> {
    await Prefs.putString(ctx, DownloadStore.key(uid), JSON.stringify(list));
  }

  static async addDownload(
    ctx: common.UIAbilityContext,
    uid: string,
    article: Article,
    content: string
  ): Promise<void> {
    const list = await DownloadStore.loadDownloads(ctx, uid);
    const filtered = list.filter(item => item.id !== article.id);
    filtered.unshift({
      ...article,
      content,
      downloadedAt: Date.now(),
    });
    const trimmed = filtered.slice(0, 80);
    await DownloadStore.saveDownloads(ctx, uid, trimmed);
  }

  static async removeDownload(ctx: common.UIAbilityContext, uid: string, id: number): Promise<void> {
    const list = await DownloadStore.loadDownloads(ctx, uid);
    const filtered = list.filter(item => item.id !== id);
    await DownloadStore.saveDownloads(ctx, uid, filtered);
  }

  static async clearDownloads(ctx: common.UIAbilityContext, uid: string): Promise<void> {
    await Prefs.putString(ctx, DownloadStore.key(uid), '[]');
  }
}