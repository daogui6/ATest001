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