import type common from '@ohos.app.ability.common';
import type { Article } from '../model/Article';
import { Prefs } from './Prefs';

interface HistoryItem extends Article {
  viewedAt?: number;
}

export class HistoryStore {
  private static key(): string {
    return 'history.articles';
  }

  static async loadHistory(ctx: common.UIAbilityContext): Promise<HistoryItem[]> {
    const raw = await Prefs.getString(ctx, HistoryStore.key(), '[]');
    try {
      const list = JSON.parse(raw) as HistoryItem[];
      return list;
    } catch {
      return [];
    }
  }

  static async addVisit(ctx: common.UIAbilityContext, article: Article): Promise<void> {
    const raw = await Prefs.getString(ctx, HistoryStore.key(), '[]');
    let list: HistoryItem[] = [];
    try {
      list = JSON.parse(raw) as HistoryItem[];
    } catch {}

    const filtered = list.filter(item => item.id !== article.id);
    filtered.unshift({ ...article, viewedAt: Date.now() });

    const trimmed = filtered.slice(0, 50);
    await Prefs.putString(ctx, HistoryStore.key(), JSON.stringify(trimmed));
  }

  static async clear(ctx: common.UIAbilityContext): Promise<void> {
    await Prefs.putString(ctx, HistoryStore.key(), '[]');
  }
}