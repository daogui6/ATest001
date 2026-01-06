import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import { HistoryStore } from './HistoryStore';
import { loginUser, logoutUser, registerUser, type WanUser } from '../service/WanService';

export class UserStore {
  private static SESSION_KEY = 'session.userId';
  private static SESSION_USER_KEY = 'session.user';
  private static COOKIE_KEY = 'session.cookie';

  private static async saveSession(ctx: common.UIAbilityContext, user: WanUser, cookie: string): Promise<void> {
    const merged: WanUser = { ...user, bio: user.bio ?? '这个人很懒，还没有签名～' };
    await Prefs.putString(ctx, UserStore.SESSION_USER_KEY, JSON.stringify(merged));
    await Prefs.putString(ctx, UserStore.SESSION_KEY, String(merged.id));
    await Prefs.putString(ctx, UserStore.COOKIE_KEY, cookie ?? '');
  }

  private static async clearSession(ctx: common.UIAbilityContext): Promise<void> {
    await Prefs.putString(ctx, UserStore.SESSION_USER_KEY, '');
    await Prefs.putString(ctx, UserStore.SESSION_KEY, '0');
    await Prefs.putString(ctx, UserStore.COOKIE_KEY, '');
  }

  static async register(
    ctx: common.UIAbilityContext,
    username: string,
    password: string,
    nickname: string,
    bio: string = '这个人很懒，还没有签名～'
  ): Promise<{ ok: true; user: WanUser } | { ok: false; message: string }> {
    username = username.trim();
    if (!username || !password) {
      return { ok: false, message: '用户名和密码不能为空' };
    }

    try {
      const { user, cookie } = await registerUser(username, password, password);
      const finalUser: WanUser = { ...user, nickname: nickname || user.nickname, bio };
      await UserStore.saveSession(ctx, finalUser, cookie);
      return { ok: true, user: finalUser };
    } catch (e) {
      return { ok: false, message: (e as Error)?.message ?? '注册失败' };
    }
  }

  static async login(
    ctx: common.UIAbilityContext,
    username: string,
    password: string
  ): Promise<{ ok: true; user: WanUser } | { ok: false; message: string }> {
    username = username.trim();
    if (!username || !password) {
      return { ok: false, message: '用户名和密码不能为空' };
    }

    try {
      const { user, cookie } = await loginUser(username, password);
      const mergedUser: WanUser = { ...user, bio: user.bio ?? '这个人很懒，还没有签名～' };
      await UserStore.saveSession(ctx, mergedUser, cookie);
      return { ok: true, user: mergedUser };
    } catch (e) {
      return { ok: false, message: (e as Error)?.message ?? '登录失败' };
    }
  }

  static async logout(ctx: common.UIAbilityContext): Promise<void> {
    const cookie = await Prefs.getString(ctx, UserStore.COOKIE_KEY, '');
    try {
      if (cookie) {
        await logoutUser(cookie);
      }
    } catch (e) {
      // ignore network errors during logout
    }
    await UserStore.clearSession(ctx);
    await HistoryStore.clear(ctx);

    const v = (AppStorage.get('history_version') as number) ?? 0;
    AppStorage.setOrCreate('history_version', v + 1);
  }

  static async currentUser(ctx: common.UIAbilityContext): Promise<WanUser | null> {
    const raw = await Prefs.getString(ctx, UserStore.SESSION_USER_KEY, '');
    if (!raw) {
      return null;
    }
    try {
      const user = JSON.parse(raw) as WanUser;
      if (user && typeof user.id === 'number') {
        return user;
      }
    } catch {}
    return null;
  }

  static async updateProfile(
    ctx: common.UIAbilityContext,
    profile: Pick<WanUser, 'nickname' | 'bio'>
  ): Promise<void> {
    const current = await UserStore.currentUser(ctx);
    if (!current) {
      return;
    }
    const next: WanUser = {
      ...current,
      nickname: profile.nickname ?? current.nickname,
      bio: profile.bio ?? current.bio
    };
    await Prefs.putString(ctx, UserStore.SESSION_USER_KEY, JSON.stringify(next));
  }

  static async getCookie(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, UserStore.COOKIE_KEY, '');
  }
}