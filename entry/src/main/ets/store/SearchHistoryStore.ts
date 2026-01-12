/*
 * SearchHistoryStore.ts - 搜索历史存储管理
 * 
 * 功能说明：
 * - 管理用户搜索关键词的历史记录
 * - 支持关键词的添加、删除和清空操作
 * - 限制历史记录数量防止存储溢出
 * - 提供搜索历史列表的加载功能
 * 
 * 存储设计：
 * - 按用户ID隔离存储
 * - 关键词按时间倒序排列（最新的在前）
 * - 限制最多保存20条搜索记录
 * - 自动去重和空白字符处理
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import { UserStore } from './UserStore';

export class SearchHistoryStore {
  /**
   * 生成搜索历史存储键名
   * 
   * @returns 搜索历史存储键名
   */
  private static async key(ctx: common.UIAbilityContext): Promise<string> {
    const current = await UserStore.currentUser(ctx);
    if (current && typeof current.id === 'number') {
      return `history.search_keywords.${current.id}`;
    }
    return 'history.search_keywords.guest';
  }

  /**
   * 加载搜索历史列表
   * 
   * @param ctx UIAbility上下文
   * @returns 搜索关键词数组（按时间倒序）
   */
  static async load(ctx: common.UIAbilityContext): Promise<string[]> {
    const key = await SearchHistoryStore.key(ctx);
    // 从本地存储读取搜索历史数据
    const raw = await Prefs.getString(ctx, key, '[]');
    
    try {
      // 解析JSON数据
      const list = JSON.parse(raw) as string[];
      
      // 验证数据类型并返回
      return Array.isArray(list) ? list : [];
    } catch {
      // 解析失败时返回空数组
      return [];
    }
  }

  /**
   * 添加搜索关键词到历史记录
   * 
   * @param ctx UIAbility上下文
   * @param keyword 搜索关键词
   */
  static async addKeyword(ctx: common.UIAbilityContext, keyword: string): Promise<void> {
    const key = await SearchHistoryStore.key(ctx);
    // 加载现有搜索历史
    const raw = await Prefs.getString(ctx, key, '[]');
    let list: string[] = [];
    
    try {
      list = JSON.parse(raw) as string[];
    } catch {
      // 解析失败时使用空数组
    }

    // 标准化关键词（去除空白字符）
    const normalized = keyword.trim();
    
    // 验证关键词有效性
    if (!normalized) {
      return;
    }

    // 去重处理：移除已存在的相同关键词
    const filtered = list.filter(item => item !== normalized);
    
    // 将新关键词添加到列表开头
    filtered.unshift(normalized);
    
    // 限制历史记录数量为20条
    const trimmed = filtered.slice(0, 20);
    
    // 保存更新后的搜索历史
    await Prefs.putString(ctx, key, JSON.stringify(trimmed));
  }

  /**
   * 从历史记录中移除指定关键词
   * 
   * @param ctx UIAbility上下文
   * @param keyword 要移除的关键词
   */
  static async removeKeyword(ctx: common.UIAbilityContext, keyword: string): Promise<void> {
    const key = await SearchHistoryStore.key(ctx);
    // 加载现有搜索历史
    const raw = await Prefs.getString(ctx, key, '[]');
    let list: string[] = [];
    
    try {
      list = JSON.parse(raw) as string[];
    } catch {
      // 解析失败时不执行操作
      return;
    }

    // 过滤掉指定关键词
    const filtered = list.filter(item => item !== keyword);
    
    // 保存更新后的搜索历史
    await Prefs.putString(ctx, key, JSON.stringify(filtered));
  }

  /**
   * 清空所有搜索历史记录
   * 
   * @param ctx UIAbility上下文
   */
  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    const key = await SearchHistoryStore.key(ctx);
    // 清空搜索历史数据
    await Prefs.putString(ctx, key, '[]');
  }
}