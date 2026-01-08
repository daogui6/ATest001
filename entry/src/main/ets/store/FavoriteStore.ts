/*
 * FavoriteStore.ts - 收藏功能数据存储管理
 * 
 * 功能说明：
 * - 管理用户收藏的文章ID集合
 * - 缓存收藏文章的详细信息用于展示
 * - 提供收藏状态的查询和更新功能
 * - 支持多用户收藏数据隔离
 * 
 * 存储设计：
 * - 用户收藏集合：按用户ID存储文章ID集合
 * - 文章详情缓存：全局缓存收藏文章的详细信息
 * - 数据分离：收藏状态与文章内容分开存储
 * 
 * 性能优化：
 * - 使用Set数据结构提高查询效率
 * - 限制缓存数量防止存储溢出
 * - 按需加载减少内存占用
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { Article } from '../model/Article';

/**
 * 收藏功能数据存储管理类
 * 
 * 提供用户收藏文章的管理功能
 * 包括收藏状态管理、文章缓存、多用户支持等
 */
export class FavoriteStore {
  // ========== 存储键名生成方法 ==========
  
  /**
   * 生成用户收藏集合存储键名
   * 
   * @param uid 用户ID
   * @returns 收藏集合存储键名
   */
  private static key(uid: string): string {
    return `fav.${uid}.ids`;
  }

  /**
   * 生成文章详情缓存存储键名
   * 全局缓存，不区分用户
   * 
   * @returns 文章缓存存储键名
   */
  private static articleKey(): string {
    return 'fav.cache.articles';
  }

  // ========== 用户会话管理 ==========
  
  /**
   * 获取当前用户ID
   * 
   * @param ctx UIAbility上下文
   * @returns 用户ID字符串
   */
  static async getUid(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, 'session.userId', '0');
  }

  // ========== 收藏状态管理方法 ==========
  
  /**
   * 加载用户收藏的文章ID集合
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @returns 文章ID的Set集合
   */
  static async loadFavSet(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    // 从本地存储读取收藏数据
    const raw = await Prefs.getString(ctx, FavoriteStore.key(uid), '[]');
    
    try {
      // 解析JSON数据为数字数组
      const arr = JSON.parse(raw) as number[];
      // 转换为Set集合（自动去重）
      return new Set(arr);
    } catch {
      // 解析失败时返回空Set
      return new Set<number>();
    }
  }

  /**
   * 保存用户收藏的文章ID集合
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param set 文章ID的Set集合
   */
  static async saveFavSet(ctx: common.UIAbilityContext, uid: string, set: Set<number>): Promise<void> {
    // 将Set转换为数组
    const arr = Array.from(set);
    // 保存到本地存储
    await Prefs.putString(ctx, FavoriteStore.key(uid), JSON.stringify(arr));
  }

  // ========== 文章详情缓存管理方法 ==========
  
  /**
   * 保存文章详情快照
   * 用于收藏页面展示文章信息
   * 
   * @param ctx UIAbility上下文
   * @param article 文章对象
   */
  static async saveArticleSnapshot(ctx: common.UIAbilityContext, article: Article): Promise<void> {
    // 加载现有缓存数据
    const raw = await Prefs.getString(ctx, FavoriteStore.articleKey(), '[]');
    let list: Article[] = [];
    
    try {
      list = JSON.parse(raw) as Article[];
    } catch {
      // 解析失败时使用空数组
    }

    // 移除同ID的旧数据（去重）
    const filtered = list.filter(item => item.id !== article.id);
    // 将新文章添加到列表开头（最近收藏的在前）
    filtered.unshift(article);
    
    // 限制缓存数量，只保留最近50条
    const trimmed = filtered.slice(0, 50);
    
    // 保存更新后的缓存数据
    await Prefs.putString(ctx, FavoriteStore.articleKey(), JSON.stringify(trimmed));
  }

  /**
   * 移除文章详情快照
   * 
   * @param ctx UIAbility上下文
   * @param id 文章ID
   */
  static async removeArticleSnapshot(ctx: common.UIAbilityContext, id: number): Promise<void> {
    // 加载现有缓存数据
    const raw = await Prefs.getString(ctx, FavoriteStore.articleKey(), '[]');
    
    try {
      const list = JSON.parse(raw) as Article[];
      // 过滤掉指定ID的文章
      const filtered = list.filter(item => item.id !== id);
      // 保存更新后的缓存数据
      await Prefs.putString(ctx, FavoriteStore.articleKey(), JSON.stringify(filtered));
    } catch {
      // 解析失败时不执行操作
    }
  }

  /**
   * 从缓存中提取指定ID的文章详情
   * 
   * @param ctx UIAbility上下文
   * @param ids 文章ID集合
   * @returns 匹配的文章对象数组
   */
  static async pickCachedArticles(ctx: common.UIAbilityContext, ids: Set<number>): Promise<Article[]> {
    // 加载缓存数据
    const raw = await Prefs.getString(ctx, FavoriteStore.articleKey(), '[]');
    
    try {
      const list = JSON.parse(raw) as Article[];
      // 过滤出在指定ID集合中的文章
      return list.filter(item => ids.has(item.id));
    } catch {
      // 解析失败时返回空数组
      return [];
    }
  }
}