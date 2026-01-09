/*
 * ReadingListStore.ts - 待读清单数据存储管理
 *
 * 功能说明：
 * - 管理用户待读文章ID集合
 * - 支持增删改查操作
 * - 按用户ID隔离待读数据
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';

export class ReadingListStore {
  private static key(uid: string): string {
    return `reading.${uid}.ids`;
  }

  static async getUid(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, 'session.userId', '0');
  }

  static async loadList(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    const raw = await Prefs.getString(ctx, ReadingListStore.key(uid), '[]');
    try {
      const arr = JSON.parse(raw) as number[];
      return new Set(arr.filter(item => typeof item === 'number'));
    } catch {
      return new Set<number>();
    }
  }

  static async saveList(ctx: common.UIAbilityContext, uid: string, list: Set<number>): Promise<void> {
    await Prefs.putString(ctx, ReadingListStore.key(uid), JSON.stringify(Array.from(list)));
  }
}