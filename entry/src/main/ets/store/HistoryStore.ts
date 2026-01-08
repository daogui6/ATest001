/*
 * HistoryStore.ts - 浏览历史记录存储管理
 * 
 * 功能说明：
 * - 管理用户浏览文章的历史记录
 * - 提供历史记录的添加、加载和清理功能
 * - 实现历史记录的自动去重和时间排序
 * - 限制历史记录数量以防止存储溢出
 * 
 * 数据存储：
 * - 使用Preferences进行本地持久化存储
 * - 存储格式为JSON数组
 * - 每条记录包含文章信息和浏览时间戳
 * 
 * 业务逻辑：
 * - 新记录添加到列表开头
 * - 自动去除重复记录（基于文章ID）
 * - 限制最大记录数量（50条）
 * - 按浏览时间倒序排列
 */

import type common from '@ohos.app.ability.common';
import type { Article } from '../model/Article';
import { Prefs } from './Prefs';

/**
 * 历史记录项接口
 * 扩展文章模型，增加浏览时间字段
 */
interface HistoryItem extends Article {
  /**
   * 浏览时间戳（毫秒）
   * 用于记录用户查看文章的时间
   */
  viewedAt?: number;
}

/**
 * 历史记录存储管理类
 * 
 * 提供浏览历史记录的持久化存储和管理功能
 * 采用静态方法设计，便于全局调用
 */
export class HistoryStore {
  // ========== 存储键名管理 ==========
  
  /**
   * 获取历史记录存储键名
   * 
   * @returns 历史记录存储键名
   */
  private static key(): string {
    return 'history.articles';
  }

  // ========== 公共业务方法 ==========
  
  /**
   * 加载浏览历史记录
   * 从本地存储读取历史记录列表
   * 
   * @param ctx UIAbility上下文
   * @returns 历史记录数组（按浏览时间倒序排列）
   */
  static async loadHistory(ctx: common.UIAbilityContext): Promise<HistoryItem[]> {
    // 从本地存储读取历史记录数据
    const raw = await Prefs.getString(ctx, HistoryStore.key(), '[]');
    
    try {
      // 解析JSON数据
      const list = JSON.parse(raw) as HistoryItem[];
      return list;
    } catch {
      // 解析失败时返回空数组
      return [];
    }
  }

  /**
   * 添加浏览记录
   * 将文章添加到历史记录列表，并自动处理去重和排序
   * 
   * @param ctx UIAbility上下文
   * @param article 要添加的文章对象
   */
  static async addVisit(ctx: common.UIAbilityContext, article: Article): Promise<void> {
    // 读取现有历史记录
    const raw = await Prefs.getString(ctx, HistoryStore.key(), '[]');
    let list: HistoryItem[] = [];
    
    try {
      // 解析现有历史记录
      list = JSON.parse(raw) as HistoryItem[];
    } catch {
      // 解析失败时使用空数组
    }

    // 去除重复记录（基于文章ID）
    const filtered = list.filter(item => item.id !== article.id);
    
    // 将新记录添加到列表开头
    // 添加浏览时间戳
    filtered.unshift({ ...article, viewedAt: Date.now() });

    // 限制记录数量，保留最新的50条
    const trimmed = filtered.slice(0, 50);
    
    // 保存更新后的历史记录
    await Prefs.putString(ctx, HistoryStore.key(), JSON.stringify(trimmed));
  }

  /**
   * 清空所有历史记录
   * 清除本地存储中的所有浏览历史
   * 
   * @param ctx UIAbility上下文
   */
  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    // 将历史记录设置为空数组
    await Prefs.putString(ctx, HistoryStore.key(), '[]');
  }
}