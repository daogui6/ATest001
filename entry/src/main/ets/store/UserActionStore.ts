/*
 * UserActionStore.ts - 用户行为数据存储管理
 * 
 * 功能说明：
 * - 管理用户点赞和评论行为的数据存储
 * - 支持用户行为记录的增删改查
 * - 提供文章详情缓存用于快速展示
 * - 按用户ID隔离行为数据
 * 
 * 存储设计：
 * - 点赞数据：按用户ID存储文章ID集合
 * - 评论数据：按用户ID存储文章ID集合
 * - 文章缓存：全局缓存点赞和评论的文章详情
 * - 数据分离：行为记录与文章内容分开存储
 *
 * 性能优化：
 * - Set数据结构提供O(1)查找性能
 * - 缓存限制防止存储溢出
 * - 异步操作避免UI阻塞
 * - 数据验证确保存储安全
 */
import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { Article } from '../model/Article';

export class UserActionStore {
  // ========== 存储键名生成方法 ==========
  
  /**
   * 生成用户点赞文章ID集合存储键名
   * 
   * @param uid 用户ID
   * @returns 点赞集合存储键名
   */
  private static likedKey(uid: string): string {
    return `liked.${uid}.ids`;
  }

  /**
   * 生成用户评论文章ID集合存储键名
   * 
   * @param uid 用户ID
   * @returns 评论集合存储键名
   */
  private static commentedKey(uid: string): string {
    return `commented.${uid}.ids`;
  }

  /**
   * 生成点赞文章详情缓存存储键名
   * 
   * @returns 点赞文章缓存存储键名
   */
  private static likedArticleKey(): string {
    return 'liked.cache.articles';
  }

  /**
   * 生成评论文章详情缓存存储键名
   * 
   * @returns 评论文章缓存存储键名
   */
  private static commentedArticleKey(): string {
    return 'commented.cache.articles';
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

  // ========== 通用存储操作方法 ==========
  
  /**
   * 加载ID集合
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @returns 数字ID的Set集合
   */
  private static async loadIdSet(ctx: common.UIAbilityContext, key: string): Promise<Set<number>> {
    // 从本地存储读取ID集合数据
    const raw = await Prefs.getString(ctx, key, '[]');
    
    try {
      // 解析JSON数据为数字数组
      const arr = JSON.parse(raw) as number[];
      
      // 过滤有效数字并转换为Set集合
      return new Set(arr.filter(item => typeof item === 'number'));
    } catch {
      // 解析失败时返回空Set
      return new Set<number>();
    }
  }

  /**
   * 保存ID集合
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @param set ID的Set集合
   */
  private static async saveIdSet(ctx: common.UIAbilityContext, key: string, set: Set<number>): Promise<void> {
    // 将Set转换为数组并保存
    await Prefs.putString(ctx, key, JSON.stringify(Array.from(set)));
  }

  /**
   * 加载缓存的文章列表
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @returns 文章对象数组
   */
  private static async loadCachedArticles(ctx: common.UIAbilityContext, key: string): Promise<Article[]> {
    // 从本地存储读取缓存文章数据
    const raw = await Prefs.getString(ctx, key, '[]');
    
    try {
      // 解析JSON数据
      const list = JSON.parse(raw) as Article[];
      
      // 验证数据类型并返回
      return Array.isArray(list) ? list : [];
    } catch {
      // 解析失败时返回空数组
      return [];
    }
  }

  /**
   * 保存文章详情快照
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @param article 文章对象
   */
  private static async saveArticleSnapshot(
    ctx: common.UIAbilityContext,
    key: string,
    article: Article
  ): Promise<void> {
    // 加载现有缓存文章列表
    const list = await UserActionStore.loadCachedArticles(ctx, key);
    
    // 去重处理：移除同ID的旧数据
    const filtered = list.filter(item => item.id !== article.id);
    
    // 将新文章添加到列表开头
    filtered.unshift(article);
    
    // 限制缓存数量为50条
    const trimmed = filtered.slice(0, 50);
    
    // 保存更新后的缓存数据
    await Prefs.putString(ctx, key, JSON.stringify(trimmed));
  }

  /**
   * 移除文章详情快照
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @param id 文章ID
   */
  private static async removeArticleSnapshot(ctx: common.UIAbilityContext, key: string, id: number): Promise<void> {
    // 加载现有缓存文章列表
    const list = await UserActionStore.loadCachedArticles(ctx, key);
    
    // 过滤掉指定ID的文章
    const filtered = list.filter(item => item.id !== id);
    
    // 保存更新后的缓存数据
    await Prefs.putString(ctx, key, JSON.stringify(filtered));
  }

  // ========== 公开业务方法 ==========
  
  /**
   * 加载用户点赞的文章ID集合
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @returns 点赞文章ID的Set集合
   */
  static async loadLikedSet(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    return await UserActionStore.loadIdSet(ctx, UserActionStore.likedKey(uid));
  }

  /**
   * 加载用户评论的文章ID集合
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @returns 评论文章ID的Set集合
   */
  static async loadCommentedSet(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    return await UserActionStore.loadIdSet(ctx, UserActionStore.commentedKey(uid));
  }

  /**
   * 从点赞缓存中提取指定ID的文章详情
   * 
   * @param ctx UIAbility上下文
   * @param ids 文章ID集合
   * @returns 匹配的文章对象数组
   */
  static async pickCachedLikedArticles(ctx: common.UIAbilityContext, ids: Set<number>): Promise<Article[]> {
    // 加载点赞文章缓存
    const list = await UserActionStore.loadCachedArticles(ctx, UserActionStore.likedArticleKey());
    
    // 过滤出在指定ID集合中的文章
    return list.filter(item => ids.has(item.id));
  }

  /**
   * 从评论缓存中提取指定ID的文章详情
   * 
   * @param ctx UIAbility上下文
   * @param ids 文章ID集合
   * @returns 匹配的文章对象数组
   */
  static async pickCachedCommentedArticles(ctx: common.UIAbilityContext, ids: Set<number>): Promise<Article[]> {
    // 加载评论文章缓存
    const list = await UserActionStore.loadCachedArticles(ctx, UserActionStore.commentedArticleKey());
    
    // 过滤出在指定ID集合中的文章
    return list.filter(item => ids.has(item.id));
  }

  /**
   * 更新用户点赞状态
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param article 文章对象
   * @param liked 是否点赞
   */
  static async updateLiked(
    ctx: common.UIAbilityContext,
    uid: string,
    article: Article,
    liked: boolean
  ): Promise<void> {
    // 验证用户ID有效性
    if (!uid || uid === '0') {
      return;
    }
    
    // 获取点赞集合存储键名
    const key = UserActionStore.likedKey(uid);
    
    // 加载现有点赞集合
    const set = await UserActionStore.loadIdSet(ctx, key);
    
    if (liked) {
      // 添加点赞：将文章ID加入集合
      set.add(article.id);
      
      // 保存文章详情到缓存
      await UserActionStore.saveArticleSnapshot(ctx, UserActionStore.likedArticleKey(), article);
    } else {
      // 取消点赞：从集合中移除文章ID
      set.delete(article.id);
      
      // 从缓存中移除文章详情
      await UserActionStore.removeArticleSnapshot(ctx, UserActionStore.likedArticleKey(), article.id);
    }
    
    // 保存更新后的点赞集合
    await UserActionStore.saveIdSet(ctx, key, set);
  }

  /**
   * 记录用户评论行为
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param article 被评论的文章
   */
  static async addCommented(ctx: common.UIAbilityContext, uid: string, article: Article): Promise<void> {
    // 验证用户ID有效性
    if (!uid || uid === '0') {
      return;
    }
    
    // 获取评论集合存储键名
    const key = UserActionStore.commentedKey(uid);
    
    // 加载现有评论集合
    const set = await UserActionStore.loadIdSet(ctx, key);
    
    // 添加文章ID到评论集合
    set.add(article.id);
    
    // 保存更新后的评论集合
    await UserActionStore.saveIdSet(ctx, key, set);
    
    // 保存文章详情到评论缓存
    await UserActionStore.saveArticleSnapshot(ctx, UserActionStore.commentedArticleKey(), article);
  }
}