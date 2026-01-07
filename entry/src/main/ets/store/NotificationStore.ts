import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { NotificationItem } from '../model/Notification';

export class NotificationStore {
  private static key(uid: string): string {
    return `notifications.${uid}`;
  }

  static async load(ctx: common.UIAbilityContext, uid: string): Promise<NotificationItem[]> {
    if (!uid || uid === '0') {
      return [];
    }
    const raw = await Prefs.getString(ctx, NotificationStore.key(uid), '[]');
    try {
      const list = JSON.parse(raw) as NotificationItem[];
      if (!Array.isArray(list)) {
        return [];
      }
      return [...list].sort((a, b) => b.createdAt - a.createdAt);
    } catch {
      return [];
    }
  }

  static async add(ctx: common.UIAbilityContext, uid: string, item: NotificationItem): Promise<void> {
    if (!uid || uid === '0') {
      return;
    }
    const list = await NotificationStore.load(ctx, uid);
    const merged = [item, ...list.filter(existing => existing.id !== item.id)];
    const trimmed = merged.slice(0, 100);
    await Prefs.putString(ctx, NotificationStore.key(uid), JSON.stringify(trimmed));
  }

  static async markAllRead(ctx: common.UIAbilityContext, uid: string): Promise<void> {
    if (!uid || uid === '0') {
      return;
    }
    const list = await NotificationStore.load(ctx, uid);
    const next = list.map(item => ({ ...item, read: true }));
    await Prefs.putString(ctx, NotificationStore.key(uid), JSON.stringify(next));
  }

  static async unreadCount(ctx: common.UIAbilityContext, uid: string): Promise<number> {
    const list = await NotificationStore.load(ctx, uid);
    return list.filter(item => !item.read).length;
  }
}