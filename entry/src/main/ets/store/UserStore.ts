import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';

export interface LocalUser {
  username: string;
  password: string;
  nickname: string;
  bio?: string;
}

export class UserStore {
  private static USERS_KEY = 'account.users';
  private static SESSION_KEY = 'session.userId';

  private static async loadUsers(ctx: common.UIAbilityContext): Promise<LocalUser[]> {
    const raw = await Prefs.getString(ctx, UserStore.USERS_KEY, '[]');
    try {
      const users = JSON.parse(raw) as LocalUser[];
      if (Array.isArray(users)) {
        return users;
      }
    } catch {}
    return [];
  }

  private static async saveUsers(ctx: common.UIAbilityContext, users: LocalUser[]): Promise<void> {
    await Prefs.putString(ctx, UserStore.USERS_KEY, JSON.stringify(users));
  }

  static async register(
    ctx: common.UIAbilityContext,
    username: string,
    password: string,
    nickname: string,
    bio: string = '这个人很懒，还没有签名～'
  ): Promise<{ ok: true } | { ok: false; message: string }> {
    username = username.trim();
    if (!username || !password) {
      return { ok: false, message: '用户名和密码不能为空' };
    }

    const users = await UserStore.loadUsers(ctx);
    if (users.find(u => u.username === username)) {
      return { ok: false, message: '该用户名已被注册' };
    }

    users.push({ username, password, nickname: nickname || username, bio });
    await UserStore.saveUsers(ctx, users);
    await Prefs.putString(ctx, UserStore.SESSION_KEY, username);
    return { ok: true };
  }

  static async login(
    ctx: common.UIAbilityContext,
    username: string,
    password: string
  ): Promise<LocalUser | null> {
    const users = await UserStore.loadUsers(ctx);
    const user = users.find(u => u.username === username && u.password === password);
    if (!user) {
      return null;
    }
    await Prefs.putString(ctx, UserStore.SESSION_KEY, username);
    return user;
  }

  static async logout(ctx: common.UIAbilityContext): Promise<void> {
    await Prefs.putString(ctx, UserStore.SESSION_KEY, '0');
  }

  static async currentUser(ctx: common.UIAbilityContext): Promise<LocalUser | null> {
    const uid = await Prefs.getString(ctx, UserStore.SESSION_KEY, '0');
    if (!uid || uid === '0') {
      return null;
    }
    const users = await UserStore.loadUsers(ctx);
    return users.find(u => u.username === uid) ?? null;
  }

  static async updateProfile(
    ctx: common.UIAbilityContext,
    username: string,
    profile: Pick<LocalUser, 'nickname' | 'bio'>
  ): Promise<void> {
    const users = await UserStore.loadUsers(ctx);
    const next = users.map(u => {
      if (u.username === username) {
        return { ...u, nickname: profile.nickname, bio: profile.bio };
      }
      return u;
    });
    await UserStore.saveUsers(ctx, next);
  }
}