import { ConfigurationConstant } from '@kit.AbilityKit';
import type common from '@ohos.app.ability.common';
import { Prefs } from './Prefs';

export interface ThemePalette {
  background: string;
  card: string;
  cardActive: string;
  primaryText: string;
  secondaryText: string;
  hintText: string;
  accent: string;
  divider: string;
  inputBackground: string;
}

const DARK_MODE_KEY = 'app_dark_mode';
const DARK_MODE_PREF_KEY = 'pref.dark_mode';

AppStorage.setOrCreate(DARK_MODE_KEY, false);

const lightPalette: ThemePalette = {
  background: '#FFFFFF',
  card: '#F5F5F5',
  cardActive: '#E5E7EB',
  primaryText: '#111827',
  secondaryText: '#4B5563',
  hintText: '#9CA3AF',
  accent: '#2563EB',
  divider: '#E5E7EB',
  inputBackground: '#F5F5F5',
};

const darkPalette: ThemePalette = {
  background: '#121212',
  card: '#1E1E1E',
  cardActive: '#2B2B2B',
  primaryText: '#E5E7EB',
  secondaryText: '#CBD5E1',
  hintText: '#94A3B8',
  accent: '#60A5FA',
  divider: '#2D2D2D',
  inputBackground: '#1C1C1E',
};

export const DARK_MODE_STORAGE_KEY = DARK_MODE_KEY;

export class ThemeStore {
  static palette(isDark: boolean): ThemePalette {
    return isDark ? darkPalette : lightPalette;
  }

  /**
   * 兜底返回完整的配色，避免 ThemeStore 调用异常或字段缺失导致 UI 崩溃。
   */
  static safePalette(isDark: boolean): ThemePalette {
    const palette = (() => {
      try {
        return ThemeStore.palette(isDark) as ThemePalette | undefined;
      } catch (_) {
        return undefined;
      }
    })();

    // 显式逐字段合并，避免 Object.assign / 展开运算符在 ArkTS 下的兼容性问题
    return {
      background: palette?.background ?? lightPalette.background,
      card: palette?.card ?? lightPalette.card,
      cardActive: palette?.cardActive ?? lightPalette.cardActive,
      primaryText: palette?.primaryText ?? lightPalette.primaryText,
      secondaryText: palette?.secondaryText ?? lightPalette.secondaryText,
      hintText: palette?.hintText ?? lightPalette.hintText,
      accent: palette?.accent ?? lightPalette.accent,
      divider: palette?.divider ?? lightPalette.divider,
      inputBackground: palette?.inputBackground ?? lightPalette.inputBackground,
    };
  }

  static async init(ctx: common.UIAbilityContext): Promise<void> {
    const saved = await Prefs.getBool(ctx, DARK_MODE_PREF_KEY, false);
    AppStorage.set(DARK_MODE_KEY, saved);
    await ThemeStore.applyColorMode(ctx, saved);
  }

  static async setDarkMode(ctx: common.UIAbilityContext, enabled: boolean): Promise<void> {
    AppStorage.set(DARK_MODE_KEY, enabled);
    await Prefs.putBool(ctx, DARK_MODE_PREF_KEY, enabled);
    await ThemeStore.applyColorMode(ctx, enabled);
  }

  private static async applyColorMode(ctx: common.UIAbilityContext, enabled: boolean): Promise<void> {
    try {
      ctx.getApplicationContext().setColorMode(
        enabled ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      );
    } catch (err) {
      // ignore color mode errors and fall back to manual palette colors
    }
  }
}