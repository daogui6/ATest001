/*
 * Prefs.ts - 本地存储管理工具类
 * 
 * 功能说明：
 * - 封装HarmonyOS preferences存储的常用操作
 * - 提供布尔值和字符串类型的读写接口
 * - 实现存储实例的单例管理
 * - 自动处理存储刷新和数据同步
 * 
 * 技术特点：
 * - 使用@ohos.data.preferences作为底层存储
 * - 支持异步操作和错误处理
 * - 提供默认值保障数据安全
 * - 自动管理存储实例生命周期
 *
 * 性能优化：
 * - 单例模式避免重复创建存储实例
 * - 自动flush确保数据持久化
 * - 类型安全验证防止数据损坏
 */

import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

/**
 * 存储文件名
 * 用于标识应用的本地存储空间
 */
const PREF_NAME = 'community_prefs';

/**
 * 本地存储管理工具类
 * 
 * 提供简单易用的键值对存储接口
 * 封装preferences存储的常用操作
 */
export class Prefs {
  /**
   * 存储实例单例
   * 避免重复创建存储实例
   */
  private static pref: preferences.Preferences | null = null;

  /**
   * 获取存储实例
   * 实现单例模式，避免重复初始化
   * 
   * @param ctx UIAbility上下文
   * @returns preferences存储实例
   */
  static async getPref(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    // 检查是否已有存储实例
    if (Prefs.pref) {
      return Prefs.pref;
    }
    
    // 创建新的存储实例
    Prefs.pref = await preferences.getPreferences(ctx, PREF_NAME);
    return Prefs.pref;
  }

  /**
   * 读取布尔值
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @param def 默认值（可选，默认为false）
   * @returns 存储的布尔值或默认值
   */
  static async getBool(ctx: common.UIAbilityContext, key: string, def: boolean = false): Promise<boolean> {
    // 获取存储实例
    const p = await Prefs.getPref(ctx);
    
    // 读取存储值
    const v = await p.get(key, def);
    
    // 验证数据类型并返回
    return (typeof v === 'boolean') ? v : def;
  }

  /**
   * 保存布尔值
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @param value 要保存的布尔值
   */
  static async putBool(ctx: common.UIAbilityContext, key: string, value: boolean): Promise<void> {
    // 获取存储实例
    const p = await Prefs.getPref(ctx);
    
    // 保存值到存储
    p.put(key, value);
    
    // 刷新存储确保数据持久化
    await p.flush();
  }

  /**
   * 读取字符串值
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @param def 默认值（可选，默认为空字符串）
   * @returns 存储的字符串值或默认值
   */
  static async getString(ctx: common.UIAbilityContext, key: string, def: string = ''): Promise<string> {
    // 获取存储实例
    const p = await Prefs.getPref(ctx);
    
    // 读取存储值（注意需要await）
    const v = await p.get(key, def);
    
    // 验证数据类型并返回
    if (typeof v === 'string') {
      return v;
    }
    return def;
  }

  /**
   * 保存字符串值
   * 
   * @param ctx UIAbility上下文
   * @param key 存储键名
   * @param value 要保存的字符串值
   */
  static async putString(ctx: common.UIAbilityContext, key: string, value: string): Promise<void> {
    // 获取存储实例
    const p = await Prefs.getPref(ctx);
    
    // 保存值到存储
    p.put(key, value);
    
    // 刷新存储确保数据持久化
    await p.flush();
  }
}