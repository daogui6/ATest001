import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';

export class SearchHistoryStore {
  private static key(): string {
    return 'history.search_keywords';
  }

  static async load(ctx: common.UIAbilityContext): Promise<string[]> {
    const raw = await Prefs.getString(ctx, SearchHistoryStore.key(), '[]');
    try {
      const list = JSON.parse(raw) as string[];
      return Array.isArray(list) ? list : [];
    } catch {
      return [];
    }
  }

  static async addKeyword(ctx: common.UIAbilityContext, keyword: string): Promise<void> {
    const raw = await Prefs.getString(ctx, SearchHistoryStore.key(), '[]');
    let list: string[] = [];
    try {
      list = JSON.parse(raw) as string[];
    } catch {}

    const normalized = keyword.trim();
    if (!normalized) {
      return;
    }

    const filtered = list.filter(item => item !== normalized);
    filtered.unshift(normalized);
    const trimmed = filtered.slice(0, 20);
    await Prefs.putString(ctx, SearchHistoryStore.key(), JSON.stringify(trimmed));
  }

  static async removeKeyword(ctx: common.UIAbilityContext, keyword: string): Promise<void> {
    const raw = await Prefs.getString(ctx, SearchHistoryStore.key(), '[]');
    let list: string[] = [];
    try {
      list = JSON.parse(raw) as string[];
    } catch {}

    const filtered = list.filter(item => item !== keyword);
    await Prefs.putString(ctx, SearchHistoryStore.key(), JSON.stringify(filtered));
  }

  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    await Prefs.putString(ctx, SearchHistoryStore.key(), '[]');
  }
}