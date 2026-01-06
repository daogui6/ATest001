import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import type { Article } from '../model/Article';

export class FavoriteStore {
  private static key(uid: string): string {
    return `fav.${uid}.ids`;
  }

  private static articleKey(): string {
    // 不区分账号缓存文章内容，用于收藏页展示
    return 'fav.cache.articles';
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

  // 记录最近收藏过的文章详情，便于收藏页展示
  static async saveArticleSnapshot(ctx: common.UIAbilityContext, article: Article): Promise<void> {
    const raw = await Prefs.getString(ctx, FavoriteStore.articleKey(), '[]');
    let list: Article[] = [];
    try {
      list = JSON.parse(raw) as Article[];
    } catch {}

    // 覆盖同 id 数据
    const filtered = list.filter(item => item.id !== article.id);
    filtered.unshift(article);
    // 防止数据过大，只缓存最近 50 条
    const trimmed = filtered.slice(0, 50);
    await Prefs.putString(ctx, FavoriteStore.articleKey(), JSON.stringify(trimmed));
  }

  static async removeArticleSnapshot(ctx: common.UIAbilityContext, id: number): Promise<void> {
    const raw = await Prefs.getString(ctx, FavoriteStore.articleKey(), '[]');
    try {
      const list = JSON.parse(raw) as Article[];
      const filtered = list.filter(item => item.id !== id);
      await Prefs.putString(ctx, FavoriteStore.articleKey(), JSON.stringify(filtered));
    } catch {}
  }

  static async pickCachedArticles(ctx: common.UIAbilityContext, ids: Set<number>): Promise<Article[]> {
    const raw = await Prefs.getString(ctx, FavoriteStore.articleKey(), '[]');
    try {
      const list = JSON.parse(raw) as Article[];
      return list.filter(item => ids.has(item.id));
    } catch {
      return [];
    }
  }
}
