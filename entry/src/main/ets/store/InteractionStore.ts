/*
 * InteractionStore.ts - 用户交互数据存储管理
 * 
 * 功能说明：
 * - 管理文章和评论的点赞状态
 * - 处理评论数据的存储和加载
 * - 提供用户交互状态的持久化存储
 * - 支持点赞状态的切换和统计
 * 
 * 数据模型：
 * - LikeState: 点赞状态接口（是否点赞、点赞数量）
 * - Comment: 评论数据模型
 * 
 * 存储结构：
 * - 文章评论：按文章ID分组存储
 * - 文章点赞：按文章ID存储用户ID集合
 * - 评论点赞：按文章ID和评论ID存储用户ID集合
 */

import type common from '@ohos.app.ability.common';

import { Prefs } from './Prefs';
import type { Comment } from '../model/Comment';

/**
 * 点赞状态接口
 * 记录用户对文章或评论的点赞状态
 */
export interface LikeState {
  /**
   * 当前用户是否已点赞
   */
  liked: boolean;
  
  /**
   * 总点赞数量
   */
  count: number;
}

/**
 * 用户交互数据存储管理类
 * 
 * 提供用户交互相关数据的持久化存储和管理功能
 * 包括评论管理、点赞状态管理等
 */
export class InteractionStore {
  // ========== 存储键名生成方法 ==========
  
  /**
   * 生成文章评论存储键名
   * 
   * @param articleId 文章ID
   * @returns 评论存储键名
   */
  private static commentKey(articleId: number): string {
    return `comments.${articleId}`;
  }

  /**
   * 生成文章点赞用户集合存储键名
   * 
   * @param articleId 文章ID
   * @returns 点赞存储键名
   */
  private static likeKey(articleId: number): string {
    return `likes.${articleId}.users`;
  }

  /**
   * 生成评论点赞用户集合存储键名
   * 
   * @param articleId 文章ID
   * @param commentId 评论ID
   * @returns 评论点赞存储键名
   */
  private static commentLikeKey(articleId: number, commentId: string): string {
    return `comment.likes.${articleId}.${commentId}`;
  }

  // ========== 评论管理方法 ==========
  
  /**
   * 加载文章评论列表
   * 
   * @param ctx UIAbility上下文
   * @param articleId 文章ID
   * @returns 按时间倒序排列的评论列表
   */
  static async loadComments(ctx: common.UIAbilityContext, articleId: number): Promise<Comment[]> {
    const key = InteractionStore.commentKey(articleId);
    // 从本地存储读取评论数据
    const raw = await Prefs.getString(ctx, key, '[]');
    
    try {
      // 解析JSON数据
      const list = JSON.parse(raw) as Comment[];
      
      // 验证数据类型
      if (!Array.isArray(list)) {
        return [];
      }
      
      // 按创建时间倒序排列（最新的在前）
      return [...list].sort((a, b) => b.createdAt - a.createdAt);
    } catch {
      // 解析失败时返回空数组
      return [];
    }
  }

  /**
   * 添加评论
   * 
   * @param ctx UIAbility上下文
   * @param articleId 文章ID
   * @param comment 评论对象
   * @returns 更新后的评论列表
   */
  static async addComment(
    ctx: common.UIAbilityContext,
    articleId: number,
    comment: Comment
  ): Promise<Comment[]> {
    // 加载现有评论
    const existing = await InteractionStore.loadComments(ctx, articleId);
    
    // 合并评论列表（去重处理）
    const merged = [comment, ...existing.filter(item => item.id !== comment.id)];
    
    // 保存更新后的评论列表
    const key = InteractionStore.commentKey(articleId);
    await Prefs.putString(ctx, key, JSON.stringify(merged));
    
    return merged;
  }

  // ========== 文章点赞管理方法 ==========
  
  /**
   * 加载文章点赞状态
   * 
   * @param ctx UIAbility上下文
   * @param articleId 文章ID
   * @param uid 用户ID
   * @returns 点赞状态信息
   */
  static async loadLikeState(
    ctx: common.UIAbilityContext,
    articleId: number,
    uid: string
  ): Promise<LikeState> {
    const raw = await Prefs.getString(ctx, InteractionStore.likeKey(articleId), '[]');
    
    try {
      // 解析点赞用户ID数组
      const arr = JSON.parse(raw) as string[];
      
      // 过滤有效用户ID并转换为Set
      const set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
      
      // 返回点赞状态（匿名用户不记录点赞）
      return { 
        liked: uid !== '0' && set.has(uid), 
        count: set.size 
      };
    } catch {
      // 解析失败时返回默认状态
      return { liked: false, count: 0 };
    }
  }

  /**
   * 切换文章点赞状态
   * 
   * @param ctx UIAbility上下文
   * @param articleId 文章ID
   * @param uid 用户ID
   * @returns 更新后的点赞状态
   */
  static async toggleLike(
    ctx: common.UIAbilityContext,
    articleId: number,
    uid: string
  ): Promise<LikeState> {
    // 加载现有点赞数据
    const raw = await Prefs.getString(ctx, InteractionStore.likeKey(articleId), '[]');
    let set = new Set<string>();
    
    try {
      const arr = JSON.parse(raw) as string[];
      set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
    } catch {
      // 解析失败时使用空Set
    }

    // 切换点赞状态
    if (set.has(uid)) {
      set.delete(uid);  // 取消点赞
    } else {
      set.add(uid);     // 添加点赞
    }

    // 保存更新后的点赞数据
    await Prefs.putString(ctx, InteractionStore.likeKey(articleId), JSON.stringify(Array.from(set)));
    
    return { liked: set.has(uid), count: set.size };
  }

  // ========== 评论点赞管理方法 ==========
  
  /**
   * 加载评论点赞状态
   * 
   * @param ctx UIAbility上下文
   * @param articleId 文章ID
   * @param commentId 评论ID
   * @param uid 用户ID
   * @returns 评论点赞状态信息
   */
  static async loadCommentLikeState(
    ctx: common.UIAbilityContext,
    articleId: number,
    commentId: string,
    uid: string
  ): Promise<LikeState> {
    const raw = await Prefs.getString(ctx, InteractionStore.commentLikeKey(articleId, commentId), '[]');
    
    try {
      // 解析点赞用户ID数组
      const arr = JSON.parse(raw) as string[];
      
      // 过滤有效用户ID并转换为Set
      const set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
      
      // 返回点赞状态（匿名用户不记录点赞）
      return { 
        liked: uid !== '0' && set.has(uid), 
        count: set.size 
      };
    } catch {
      // 解析失败时返回默认状态
      return { liked: false, count: 0 };
    }
  }

  /**
   * 切换评论点赞状态
   * 
   * @param ctx UIAbility上下文
   * @param articleId 文章ID
   * @param commentId 评论ID
   * @param uid 用户ID
   * @returns 更新后的评论点赞状态
   */
  static async toggleCommentLike(
    ctx: common.UIAbilityContext,
    articleId: number,
    commentId: string,
    uid: string
  ): Promise<LikeState> {
    // 加载现有点赞数据
    const raw = await Prefs.getString(ctx, InteractionStore.commentLikeKey(articleId, commentId), '[]');
    let set = new Set<string>();
    
    try {
      const arr = JSON.parse(raw) as string[];
      set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
    } catch {
      // 解析失败时使用空Set
    }

    // 切换点赞状态
    if (set.has(uid)) {
      set.delete(uid);  // 取消点赞
    } else {
      set.add(uid);     // 添加点赞
    }

    // 保存更新后的点赞数据
    await Prefs.putString(
      ctx,
      InteractionStore.commentLikeKey(articleId, commentId),
      JSON.stringify(Array.from(set))
    );
    
    return { liked: set.has(uid), count: set.size };
  }
}