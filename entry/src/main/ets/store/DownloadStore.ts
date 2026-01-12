/*
 * DownloadStore.ts - 离线下载数据存储管理
 *
 * 功能说明：
 * - 管理用户离线下载文章列表
 * - 支持新增、删除、清空与读取
 * - 按用户ID隔离下载数据
 * - 限制下载数量防止存储溢出
 * - 自动维护下载时间戳
 *
 * 数据模型：
 * - DownloadedArticle: 扩展文章模型，包含下载时间戳
 *
 * 存储策略：
 * - 最大存储80篇文章，自动清理旧数据
 * - JSON序列化存储，支持复杂数据结构
 * - 用户数据隔离，确保多用户安全性
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { Article } from '../model/Article';

/**
 * 下载文章数据模型
 * 扩展基础文章模型，添加下载时间信息
 */
export interface DownloadedArticle extends Article {
  /**
   * 下载时间戳（毫秒）
   * 用于排序和清理策略
   */
  downloadedAt: number;
}

/**
 * 离线下载数据存储管理类
 *
 * 提供用户离线下载文章的管理功能
 * 包括下载记录存储、数量限制、用户隔离等
 */
export class DownloadStore {
  /**
   * 生成下载存储键名
   * 按用户ID隔离存储空间
   *
   * @param uid 用户ID
   * @returns 存储键名
   */
  private static key(uid: string): string {
    return `download.${uid}.articles`;
  }

  /**
   * 获取当前用户ID
   *
   * @param ctx UIAbility上下文
   * @returns 用户ID字符串
   */
  static async getUid(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, 'session.userId', '0');
  }

  /**
   * 加载用户下载的文章列表
   *
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @returns 下载文章列表（按下载时间倒序）
   */
  static async loadDownloads(ctx: common.UIAbilityContext, uid: string): Promise<DownloadedArticle[]> {
    const raw = await Prefs.getString(ctx, DownloadStore.key(uid), '[]');
    try {
      const list = JSON.parse(raw) as DownloadedArticle[];
      return Array.isArray(list) ? list : [];
    } catch {
      // JSON解析失败时返回空数组
      return [];
    }
  }

  /**
   * 保存下载文章列表
   *
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param list 下载文章列表
   */
  static async saveDownloads(
    ctx: common.UIAbilityContext,
    uid: string,
    list: DownloadedArticle[]
  ): Promise<void> {
    await Prefs.putString(ctx, DownloadStore.key(uid), JSON.stringify(list));
  }

  /**
   * 添加下载文章
   * 自动去重并维护下载时间顺序
   *
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param article 文章对象
   * @param content 文章内容（用于离线阅读）
   */
  static async addDownload(
    ctx: common.UIAbilityContext,
    uid: string,
    article: Article,
    content: string
  ): Promise<void> {
    // 加载现有下载列表
    const list = await DownloadStore.loadDownloads(ctx, uid);

    // 去重处理：移除同ID的旧记录
    const filtered = list.filter(item => item.id !== article.id);

    // 添加新记录到列表开头（最新下载在前）
    filtered.unshift({
      ...article,
      content,
      downloadedAt: Date.now(),
    });

    // 限制存储数量，保留最近80条记录
    const trimmed = filtered.slice(0, 80);

    // 保存更新后的列表
    await DownloadStore.saveDownloads(ctx, uid, trimmed);
  }

  /**
   * 移除指定下载文章
   *
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param id 要移除的文章ID
   */
  static async removeDownload(ctx: common.UIAbilityContext, uid: string, id: number): Promise<void> {
    const list = await DownloadStore.loadDownloads(ctx, uid);
    const filtered = list.filter(item => item.id !== id);
    await DownloadStore.saveDownloads(ctx, uid, filtered);
  }

  /**
   * 清空用户所有下载记录
   *
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   */
  static async clearDownloads(ctx: common.UIAbilityContext, uid: string): Promise<void> {
    await Prefs.putString(ctx, DownloadStore.key(uid), '[]');
  }
}