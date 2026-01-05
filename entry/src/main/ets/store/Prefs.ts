import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

const PREF_NAME = 'community_prefs';

export class Prefs {
  private static pref: preferences.Preferences | null = null;

  static async getPref(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    if (Prefs.pref) { //之前打开过
      return Prefs.pref;
    }
    Prefs.pref = await preferences.getPreferences(ctx, PREF_NAME);
    return Prefs.pref;
  }

  static async getBool(ctx: common.UIAbilityContext, key: string, def: boolean = false): Promise<boolean> {
    const p = await Prefs.getPref(ctx);
    const v = await p.get(key, def);
    return (typeof v === 'boolean') ? v : def;
  }

  static async putBool(ctx: common.UIAbilityContext, key: string, value: boolean): Promise<void> {
    const p = await Prefs.getPref(ctx);
    p.put(key, value);
    await p.flush();
  }

  static async getString(ctx: common.UIAbilityContext, key: string, def: string = ''): Promise<string> {
    const p = await Prefs.getPref(ctx);
    const v = await p.get(key, def); // ✅ 注意这里要 await
    if (typeof v === 'string') {
      return v;
    }
    return def;
  }

  static async putString(ctx: common.UIAbilityContext, key: string, value: string): Promise<void> {
    const p = await Prefs.getPref(ctx);
    p.put(key, value);
    await p.flush();
  }
}
