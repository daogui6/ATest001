import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';

export class FavoriteStore {
  private static key(uid: string): string {
    return `fav.${uid}.ids`;
  }

  static async getUid(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, 'session.userId', '0');
  }

  static async loadFavSet(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    const raw = await Prefs.getString(ctx, FavoriteStore.key(uid), '[]');
    try {
      const arr = JSON.parse(raw) as number[];
      return new Set(arr);
    } catch {
      return new Set<number>();
    }
  }

  static async saveFavSet(ctx: common.UIAbilityContext, uid: string, set: Set<number>): Promise<void> {
    const arr = Array.from(set);
    await Prefs.putString(ctx, FavoriteStore.key(uid), JSON.stringify(arr));
  }
}
