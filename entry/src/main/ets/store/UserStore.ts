/*
 * UserStore.ts - 用户数据存储管理
 * 
 * 功能说明：
 * - 管理用户会话状态（登录、退出、当前用户）
 * - 处理用户注册和登录业务流程
 * - 管理用户个人资料和配置覆盖
 * - 协调用户相关的数据清理（如历史记录）
 * 
 * 数据存储：
 * - 使用Preferences进行本地持久化存储
 * - 会话信息管理（用户ID、用户数据、Cookie）
 * - 个人资料覆盖配置
 * 
 * 业务逻辑：
 * - 用户注册流程验证
 * - 用户登录状态管理
 * - 用户资料更新同步
 * - 退出登录的完整清理
 */

import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';
import { HistoryStore } from './HistoryStore';
import { loginUser, logoutUser, registerUser, type WanUser } from '../service/WanService';

/**
 * 用户数据存储管理类
 * 
 * 提供用户相关的数据持久化和业务逻辑处理
 * 采用静态方法设计，便于全局调用
 */
export class UserStore {
  // ========== 存储键名常量 ==========
  
  /**
   * 会话用户ID存储键
   */
  private static SESSION_KEY = 'session.userId';
  
  /**
   * 会话用户数据存储键
   */
  private static SESSION_USER_KEY = 'session.user';
  
  /**
   * 会话Cookie存储键
   */
  private static COOKIE_KEY = 'session.cookie';

  // ========== 工具方法 ==========
  
  /**
   * 生成用户资料覆盖配置的存储键
   * 
   * @param userId 用户ID
   * @returns 对应的存储键名
   */
  private static profileOverrideKey(userId: number): string {
    return `profile.user.${userId}`;
  }

  /**
   * 应用用户资料覆盖配置
   * 将本地保存的个人资料覆盖应用到用户数据上
   * 
   * @param ctx UIAbility上下文
   * @param user 原始用户数据
   * @returns 应用覆盖后的用户数据
   */
  private static async applyProfileOverrides(
    ctx: common.UIAbilityContext,
    user: WanUser
  ): Promise<WanUser> {
    // 从本地存储读取覆盖配置
    const raw = await Prefs.getString(ctx, UserStore.profileOverrideKey(user.id), '');
    if (!raw) {
      return user;
    }
    
    try {
      // 解析覆盖配置并应用到用户数据
      const override = JSON.parse(raw) as Partial<WanUser>;
      return {
        ...user,
        ...override,
        bio: (override.bio ?? user.bio) ?? '这个人很懒，还没有签名～'
      };
    } catch (e) {
      // 解析失败时返回原始用户数据
      return user;
    }
  }

  /**
   * 保存用户会话信息
   * 将用户数据和Cookie保存到本地存储
   * 
   * @param ctx UIAbility上下文
   * @param user 用户数据
   * @param cookie 会话Cookie
   */
  private static async saveSession(ctx: common.UIAbilityContext, user: WanUser, cookie: string): Promise<void> {
    // 确保用户资料有默认值
    const merged: WanUser = { ...user, bio: user.bio ?? '这个人很懒，还没有签名～' };
    
    // 保存用户数据、用户ID和Cookie
    await Prefs.putString(ctx, UserStore.SESSION_USER_KEY, JSON.stringify(merged));
    await Prefs.putString(ctx, UserStore.SESSION_KEY, String(merged.id));
    await Prefs.putString(ctx, UserStore.COOKIE_KEY, cookie ?? '');
  }

  /**
   * 清除用户会话信息
   * 退出登录时清理本地存储的会话数据
   * 
   * @param ctx UIAbility上下文
   */
  private static async clearSession(ctx: common.UIAbilityContext): Promise<void> {
    await Prefs.putString(ctx, UserStore.SESSION_USER_KEY, '');
    await Prefs.putString(ctx, UserStore.SESSION_KEY, '0');
    await Prefs.putString(ctx, UserStore.COOKIE_KEY, '');
  }

  // ========== 公共业务方法 ==========
  
  /**
   * 用户注册
   * 
   * @param ctx UIAbility上下文
   * @param username 用户名
   * @param password 密码
   * @param nickname 昵称
   * @param bio 个人简介（可选，默认值）
   * @returns 注册结果（成功包含用户数据，失败包含错误信息）
   */
  static async register(
    ctx: common.UIAbilityContext,
    username: string,
    password: string,
    nickname: string,
    bio: string = '这个人很懒，还没有签名～'
  ): Promise<{ ok: true; user: WanUser } | { ok: false; message: string }> {
    // 参数验证和清理
    username = username.trim();
    if (!username || !password) {
      return { ok: false, message: '用户名和密码不能为空' };
    }

    try {
      // 调用注册API
      const { user, cookie } = await registerUser(username, password, password);
      
      // 应用个人资料覆盖并保存会话
      const finalUser: WanUser = await UserStore.applyProfileOverrides(ctx, {
        ...user,
        nickname: nickname || user.nickname,
        bio
      });
      
      await UserStore.saveSession(ctx, finalUser, cookie);
      return { ok: true, user: finalUser };
    } catch (e) {
      // 错误处理
      return { ok: false, message: (e as Error)?.message ?? '注册失败' };
    }
  }

  /**
   * 用户登录
   * 
   * @param ctx UIAbility上下文
   * @param username 用户名
   * @param password 密码
   * @returns 登录结果（成功包含用户数据，失败包含错误信息）
   */
  static async login(
    ctx: common.UIAbilityContext,
    username: string,
    password: string
  ): Promise<{ ok: true; user: WanUser } | { ok: false; message: string }> {
    // 参数验证
    username = username.trim();
    if (!username || !password) {
      return { ok: false, message: '用户名和密码不能为空' };
    }

    try {
      // 调用登录API
      const { user, cookie } = await loginUser(username, password);
      
      // 应用个人资料覆盖并保存会话
      const mergedUser: WanUser = await UserStore.applyProfileOverrides(ctx, {
        ...user,
        bio: user.bio ?? '这个人很懒，还没有签名～'
      });
      
      await UserStore.saveSession(ctx, mergedUser, cookie);
      return { ok: true, user: mergedUser };
    } catch (e) {
      // 错误处理
      return { ok: false, message: (e as Error)?.message ?? '登录失败' };
    }
  }

  /**
   * 用户退出登录
   * 清理本地会话数据并调用退出API
   * 
   * @param ctx UIAbility上下文
   */
  static async logout(ctx: common.UIAbilityContext): Promise<void> {
    // 获取当前Cookie
    const cookie = await Prefs.getString(ctx, UserStore.COOKIE_KEY, '');
    
    try {
      // 调用退出API（忽略网络错误）
      if (cookie) {
        await logoutUser(cookie);
      }
    } catch (e) {
      // 退出API调用失败不影响本地清理
    }
    
    // 清理本地会话数据
    await UserStore.clearSession(ctx);
    
    // 清理用户相关的历史记录
    await HistoryStore.clear(ctx);

    // 触发历史记录版本更新，通知其他页面刷新
    const v = (AppStorage.get('history_version') as number) ?? 0;
    AppStorage.setOrCreate('history_version', v + 1);
  }

  /**
   * 获取当前登录用户
   * 
   * @param ctx UIAbility上下文
   * @returns 当前用户数据或null（未登录）
   */
  static async currentUser(ctx: common.UIAbilityContext): Promise<WanUser | null> {
    // 从本地存储读取用户数据
    const raw = await Prefs.getString(ctx, UserStore.SESSION_USER_KEY, '');
    if (!raw) {
      return null;
    }
    
    try {
      // 解析用户数据并验证格式
      const user = JSON.parse(raw) as WanUser;
      if (user && typeof user.id === 'number') {
        return user;
      }
    } catch {
      // 解析失败返回null
    }
    
    return null;
  }

  /**
   * 更新用户个人资料
   * 
   * @param ctx UIAbility上下文
   * @param profile 要更新的资料（昵称和简介）
   */
  static async updateProfile(
    ctx: common.UIAbilityContext,
    profile: Pick<WanUser, 'nickname' | 'bio'>
  ): Promise<void> {
    // 获取当前用户
    const current = await UserStore.currentUser(ctx);
    if (!current) {
      return;
    }
    
    // 合并更新后的用户数据
    const next: WanUser = {
      ...current,
      nickname: profile.nickname ?? current.nickname,
      bio: profile.bio ?? current.bio
    };
    
    // 更新会话数据
    await Prefs.putString(ctx, UserStore.SESSION_USER_KEY, JSON.stringify(next));
    
    // 保存个人资料覆盖配置
    await Prefs.putString(
      ctx,
      UserStore.profileOverrideKey(next.id),
      JSON.stringify({ nickname: next.nickname, bio: next.bio })
    );
  }

  /**
   * 获取当前用户的Cookie
   * 
   * @param ctx UIAbility上下文
   * @returns 用户Cookie字符串
   */
  static async getCookie(ctx: common.UIAbilityContext): Promise<string> {
    return await Prefs.getString(ctx, UserStore.COOKIE_KEY, '');
  }
}