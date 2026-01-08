/*
 * NotificationStore.ts - 通知数据存储管理
 * 
 * 功能说明：
 * - 管理用户通知数据的存储和读取
 * - 支持通知的添加、标记已读、统计未读数量
 * - 按用户ID隔离通知数据
 * - 限制通知数量防止存储溢出
 * 
 * 存储设计：
 * - 按用户ID存储通知列表
 * - 通知按时间倒序排列（最新的在前）
 * - 限制每个用户最多100条通知
 * - 支持匿名用户过滤
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { NotificationItem } from '../model/Notification';

export class NotificationStore {
  /**
   * 标准化用户ID
   * 处理空值和空白字符
   * 
   * @param uid 原始用户ID
   * @returns 标准化后的用户ID
   */
  private static normalizeUid(uid: string): string {
    return String(uid ?? '').trim();
  }

  /**
   * 生成通知存储键名
   * 
   * @param uid 用户ID
   * @returns 通知存储键名
   */
  private static key(uid: string): string {
    return `notifications.${NotificationStore.normalizeUid(uid)}`;
  }

  /**
   * 加载用户通知列表
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @returns 按时间倒序排列的通知列表
   */
  static async load(ctx: common.UIAbilityContext, uid: string): Promise<NotificationItem[]> {
    // 标准化用户ID并验证有效性
    const safeUid = NotificationStore.normalizeUid(uid);
    if (!safeUid || safeUid === '0') {
      return [];
    }
    
    // 从本地存储读取通知数据
    const raw = await Prefs.getString(ctx, NotificationStore.key(safeUid), '[]');
    
    try {
      // 解析JSON数据
      const list = JSON.parse(raw) as NotificationItem[];
      
      // 验证数据类型
      if (!Array.isArray(list)) {
        return [];
      }
      
      // 按时间倒序排列（最新的在前）
      return [...list].sort((a, b) => b.createdAt - a.createdAt);
    } catch {
      // 解析失败时返回空数组
      return [];
    }
  }

  /**
   * 添加新通知
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param item 通知项
   */
  static async add(ctx: common.UIAbilityContext, uid: string, item: NotificationItem): Promise<void> {
    // 验证用户ID有效性
    const safeUid = NotificationStore.normalizeUid(uid);
    if (!safeUid || safeUid === '0') {
      return;
    }
    
    // 加载现有通知列表
    const list = await NotificationStore.load(ctx, safeUid);
    
    // 合并新通知（去重处理）
    const merged = [item, ...list.filter(existing => existing.id !== item.id)];
    
    // 限制通知数量为100条
    const trimmed = merged.slice(0, 100);
    
    // 保存更新后的通知列表
    await Prefs.putString(ctx, NotificationStore.key(safeUid), JSON.stringify(trimmed));
  }

  /**
   * 标记所有通知为已读
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   */
  static async markAllRead(ctx: common.UIAbilityContext, uid: string): Promise<void> {
    // 验证用户ID有效性
    const safeUid = NotificationStore.normalizeUid(uid);
    if (!safeUid || safeUid === '0') {
      return;
    }
    
    // 加载现有通知列表
    const list = await NotificationStore.load(ctx, safeUid);
    
    // 将所有通知标记为已读
    const next = list.map(item => ({ ...item, read: true }));
    
    // 保存更新后的通知列表
    await Prefs.putString(ctx, NotificationStore.key(safeUid), JSON.stringify(next));
  }

  /**
   * 标记单个通知为已读
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param id 通知ID
   */
  static async markRead(ctx: common.UIAbilityContext, uid: string, id: string): Promise<void> {
    // 验证用户ID有效性
    const safeUid = NotificationStore.normalizeUid(uid);
    if (!safeUid || safeUid === '0') {
      return;
    }
    
    // 加载现有通知列表
    const list = await NotificationStore.load(ctx, safeUid);
    
    // 标记指定通知为已读
    const next = list.map(item => (item.id === id ? { ...item, read: true } : item));
    
    // 保存更新后的通知列表
    await Prefs.putString(ctx, NotificationStore.key(safeUid), JSON.stringify(next));
  }

  /**
   * 获取未读通知数量
   * 
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @returns 未读通知数量
   */
  static async unreadCount(ctx: common.UIAbilityContext, uid: string): Promise<number> {
    // 加载通知列表
    const list = await NotificationStore.load(ctx, NotificationStore.normalizeUid(uid));
    
    // 统计未读通知数量
    return list.filter(item => !item.read).length;
  }
}