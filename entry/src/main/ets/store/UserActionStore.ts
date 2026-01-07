import type common from '@ohos.app.ability.common';

import { Prefs } from './Prefs';
import type { Article } from '../model/Article';

export class UserActionStore {
  private static likedKey(uid: string): string {
    return `liked.${uid}.ids`;
  }

  private static commentedKey(uid: string): string {
    return `commented.${uid}.ids`;
  }

  private static likedArticleKey(): string {
    return 'liked.cache.articles';
  }

  private static commentedArticleKey(): string {
    return 'commented.cache.articles';
  }

  static async getUid(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, 'session.userId', '0');
  }

  private static async loadIdSet(ctx: common.UIAbilityContext, key: string): Promise<Set<number>> {
    const raw = await Prefs.getString(ctx, key, '[]');
    try {
      const arr = JSON.parse(raw) as number[];
      return new Set(arr.filter(item => typeof item === 'number'));
    } catch {
      return new Set<number>();
    }
  }

  private static async saveIdSet(ctx: common.UIAbilityContext, key: string, set: Set<number>): Promise<void> {
    await Prefs.putString(ctx, key, JSON.stringify(Array.from(set)));
  }

  private static async loadCachedArticles(ctx: common.UIAbilityContext, key: string): Promise<Article[]> {
    const raw = await Prefs.getString(ctx, key, '[]');
    try {
      const list = JSON.parse(raw) as Article[];
      return Array.isArray(list) ? list : [];
    } catch {
      return [];
    }
  }

  private static async saveArticleSnapshot(
    ctx: common.UIAbilityContext,
    key: string,
    article: Article
  ): Promise<void> {
    const list = await UserActionStore.loadCachedArticles(ctx, key);
    const filtered = list.filter(item => item.id !== article.id);
    filtered.unshift(article);
    const trimmed = filtered.slice(0, 50);
    await Prefs.putString(ctx, key, JSON.stringify(trimmed));
  }

  private static async removeArticleSnapshot(ctx: common.UIAbilityContext, key: string, id: number): Promise<void> {
    const list = await UserActionStore.loadCachedArticles(ctx, key);
    const filtered = list.filter(item => item.id !== id);
    await Prefs.putString(ctx, key, JSON.stringify(filtered));
  }

  static async loadLikedSet(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    return await UserActionStore.loadIdSet(ctx, UserActionStore.likedKey(uid));
  }

  static async loadCommentedSet(ctx: common.UIAbilityContext, uid: string): Promise<Set<number>> {
    return await UserActionStore.loadIdSet(ctx, UserActionStore.commentedKey(uid));
  }

  static async pickCachedLikedArticles(ctx: common.UIAbilityContext, ids: Set<number>): Promise<Article[]> {
    const list = await UserActionStore.loadCachedArticles(ctx, UserActionStore.likedArticleKey());
    return list.filter(item => ids.has(item.id));
  }

  static async pickCachedCommentedArticles(ctx: common.UIAbilityContext, ids: Set<number>): Promise<Article[]> {
    const list = await UserActionStore.loadCachedArticles(ctx, UserActionStore.commentedArticleKey());
    return list.filter(item => ids.has(item.id));
  }

  static async updateLiked(
    ctx: common.UIAbilityContext,
    uid: string,
    article: Article,
    liked: boolean
  ): Promise<void> {
    if (!uid || uid === '0') {
      return;
    }
    const key = UserActionStore.likedKey(uid);
    const set = await UserActionStore.loadIdSet(ctx, key);
    if (liked) {
      set.add(article.id);
      await UserActionStore.saveArticleSnapshot(ctx, UserActionStore.likedArticleKey(), article);
    } else {
      set.delete(article.id);
      await UserActionStore.removeArticleSnapshot(ctx, UserActionStore.likedArticleKey(), article.id);
    }
    await UserActionStore.saveIdSet(ctx, key, set);
  }

  static async addCommented(ctx: common.UIAbilityContext, uid: string, article: Article): Promise<void> {
    if (!uid || uid === '0') {
      return;
    }
    const key = UserActionStore.commentedKey(uid);
    const set = await UserActionStore.loadIdSet(ctx, key);
    set.add(article.id);
    await UserActionStore.saveIdSet(ctx, key, set);
    await UserActionStore.saveArticleSnapshot(ctx, UserActionStore.commentedArticleKey(), article);
  }
}