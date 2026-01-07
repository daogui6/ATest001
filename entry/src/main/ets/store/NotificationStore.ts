import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { NotificationItem } from '../model/Notification';

export class NotificationStore {
  private static normalizeUid(uid: string): string {
    return String(uid ?? '').trim();
  }

  private static key(uid: string): string {
    return `notifications.${NotificationStore.normalizeUid(uid)}`;
  }

  static async load(ctx: common.UIAbilityContext, uid: string): Promise<NotificationItem[]> {
    const safeUid = NotificationStore.normalizeUid(uid);
    if (!safeUid || safeUid === '0') {
      return [];
    }
    const raw = await Prefs.getString(ctx, NotificationStore.key(safeUid), '[]');
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
    const safeUid = NotificationStore.normalizeUid(uid);
    if (!safeUid || safeUid === '0') {
      return;
    }
    const list = await NotificationStore.load(ctx, safeUid);
    const merged = [item, ...list.filter(existing => existing.id !== item.id)];
    const trimmed = merged.slice(0, 100);
    await Prefs.putString(ctx, NotificationStore.key(safeUid), JSON.stringify(trimmed));
  }

  static async markAllRead(ctx: common.UIAbilityContext, uid: string): Promise<void> {
    const safeUid = NotificationStore.normalizeUid(uid);
    if (!safeUid || safeUid === '0') {
      return;
    }
    const list = await NotificationStore.load(ctx, safeUid);
    const next = list.map(item => ({ ...item, read: true }));
    await Prefs.putString(ctx, NotificationStore.key(safeUid), JSON.stringify(next));
  }

  static async unreadCount(ctx: common.UIAbilityContext, uid: string): Promise<number> {
    const list = await NotificationStore.load(ctx, NotificationStore.normalizeUid(uid));
    return list.filter(item => !item.read).length;
  }
}