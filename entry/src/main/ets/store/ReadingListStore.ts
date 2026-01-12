/*
 * ReadingListStore.ts - 待读清单数据存储管理
 *
 * 功能说明：
 * - 管理用户待读文章ID集合
 * - 支持增删改查操作
 * - 按用户ID隔离待读数据
 * - 提供待读列表的持久化存储
 *
 * 存储设计：
 * - 使用Set数据结构存储文章ID集合
 * - 按用户ID隔离存储空间
 * - JSON序列化存储，支持复杂数据结构
 * - 自动数据验证和类型过滤
 *
 * 使用场景：
 * - 用户标记感兴趣的文章
 * - 跨会话保存阅读进度
 * - 个性化文章推荐基础数据
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';

/**
 * 待读清单数据存储管理类
 *
 * 提供用户待读文章列表的管理功能
 * 包括待读文章的添加、移除、查询等操作
 */
export class ReadingListStore {
  /**
   * 生成待读清单存储键名
   * 按用户ID隔离存储空间
   *
   * @param uid 用户ID
   * @returns 存储键名
   */
  private static key(uid: string): string {
    return `reading.${uid}.ids`;
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
   * 加载用户待读文章ID集合
   *
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @returns 文章ID的Set集合
   */
  static async loadList(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    // 从本地存储读取待读列表数据
    const raw = await Prefs.getString(ctx, ReadingListStore.key(uid), '[]');

    try {
      // 解析JSON数据为数字数组
      const arr = JSON.parse(raw) as number[];

      // 过滤有效数字并转换为Set（自动去重）
      return new Set(arr.filter(item => typeof item === 'number'));
    } catch {
      // JSON解析失败时返回空Set
      return new Set<number>();
    }
  }

  /**
   * 保存用户待读文章ID集合
   *
   * @param ctx UIAbility上下文
   * @param uid 用户ID
   * @param list 文章ID的Set集合
   */
  static async saveList(ctx: common.UIAbilityContext, uid: string, list: Set<number>): Promise<void> {
    // 将Set转换为数组并保存到本地存储
    await Prefs.putString(ctx, ReadingListStore.key(uid), JSON.stringify(Array.from(list)));
  }
}