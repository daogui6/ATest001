import type common from '@ohos.app.ability.common';

import { Prefs } from './Prefs';
import type { Comment } from '../model/Comment';

export interface LikeState {
  liked: boolean;
  count: number;
}

export class InteractionStore {
  private static commentKey(articleId: number): string {
    return `comments.${articleId}`;
  }

  private static likeKey(articleId: number): string {
    return `likes.${articleId}.users`;
  }

  private static commentLikeKey(articleId: number, commentId: string): string {
    return `comment.likes.${articleId}.${commentId}`;
  }

  static async loadComments(ctx: common.UIAbilityContext, articleId: number): Promise<Comment[]> {
    const key = InteractionStore.commentKey(articleId);
    const raw = await Prefs.getString(ctx, key, '[]');
    try {
      const list = JSON.parse(raw) as Comment[];
      if (!Array.isArray(list)) {
        return [];
      }
      // 按时间倒序
      return [...list].sort((a, b) => b.createdAt - a.createdAt);
    } catch {
      return [];
    }
  }

  static async addComment(
    ctx: common.UIAbilityContext,
    articleId: number,
    comment: Comment
  ): Promise<Comment[]> {
    const existing = await InteractionStore.loadComments(ctx, articleId);
    const merged = [comment, ...existing.filter(item => item.id !== comment.id)];
    const key = InteractionStore.commentKey(articleId);
    await Prefs.putString(ctx, key, JSON.stringify(merged));
    return merged;
  }

  static async loadLikeState(
    ctx: common.UIAbilityContext,
    articleId: number,
    uid: string
  ): Promise<LikeState> {
    const raw = await Prefs.getString(ctx, InteractionStore.likeKey(articleId), '[]');
    try {
      const arr = JSON.parse(raw) as string[];
      const set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
      return { liked: uid !== '0' && set.has(uid), count: set.size };
    } catch {
      return { liked: false, count: 0 };
    }
  }

  static async toggleLike(
    ctx: common.UIAbilityContext,
    articleId: number,
    uid: string
  ): Promise<LikeState> {
    const raw = await Prefs.getString(ctx, InteractionStore.likeKey(articleId), '[]');
    let set = new Set<string>();
    try {
      const arr = JSON.parse(raw) as string[];
      set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
    } catch {}

    if (set.has(uid)) {
      set.delete(uid);
    } else {
      set.add(uid);
    }

    await Prefs.putString(ctx, InteractionStore.likeKey(articleId), JSON.stringify(Array.from(set)));
    return { liked: set.has(uid), count: set.size };
  }

  static async loadCommentLikeState(
    ctx: common.UIAbilityContext,
    articleId: number,
    commentId: string,
    uid: string
  ): Promise<LikeState> {
    const raw = await Prefs.getString(ctx, InteractionStore.commentLikeKey(articleId, commentId), '[]');
    try {
      const arr = JSON.parse(raw) as string[];
      const set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
      return { liked: uid !== '0' && set.has(uid), count: set.size };
    } catch {
      return { liked: false, count: 0 };
    }
  }

  static async toggleCommentLike(
    ctx: common.UIAbilityContext,
    articleId: number,
    commentId: string,
    uid: string
  ): Promise<LikeState> {
    const raw = await Prefs.getString(ctx, InteractionStore.commentLikeKey(articleId, commentId), '[]');
    let set = new Set<string>();
    try {
      const arr = JSON.parse(raw) as string[];
      set = new Set(arr.filter(item => typeof item === 'string' && item.trim().length > 0));
    } catch {}

    if (set.has(uid)) {
      set.delete(uid);
    } else {
      set.add(uid);
    }

    await Prefs.putString(
      ctx,
      InteractionStore.commentLikeKey(articleId, commentId),
      JSON.stringify(Array.from(set))
    );
    return { liked: set.has(uid), count: set.size };
  }
}