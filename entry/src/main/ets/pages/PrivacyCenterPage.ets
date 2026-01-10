/**
 * 隐私中心页面 - 隐私设置与数据管理
 *
 * 功能概述：
 * - 管理隐私开关（个性化推荐/数据统计等）
 * - 查看隐私协议说明
 * - 提供数据清理入口
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { Prefs } from '../store/Prefs';
import { HistoryStore } from '../store/HistoryStore';
import { DownloadStore } from '../store/DownloadStore';

@Entry
@Component
export struct PrivacyCenterPage {
  private KEY_PERSONALIZED = 'privacy.personalized';
  private KEY_ANALYTICS = 'privacy.analytics';
  private KEY_ADS = 'privacy.ads';

  @State personalized: boolean = true;
  @State analytics: boolean = true;
  @State ads: boolean = false;

  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear() {
    const ctx = this.hostCtx();
    this.personalized = await Prefs.getBool(ctx, this.KEY_PERSONALIZED, true);
    this.analytics = await Prefs.getBool(ctx, this.KEY_ANALYTICS, true);
    this.ads = await Prefs.getBool(ctx, this.KEY_ADS, false);
  }

  private async saveSetting(key: string, value: boolean) {
    await Prefs.putBool(this.hostCtx(), key, value);
    promptAction.showToast({ message: '隐私设置已更新' });
  }

  private async openPolicy() {
    promptAction.showDialog({
      title: '隐私政策',
      message: '我们仅在提供服务所需范围内处理必要信息，并采取合理措施保护您的数据安全。',
      buttons: [{ text: '我知道了', color: '#4C6FFF' }]
    });
  }

  private async clearHistory() {
    await HistoryStore.clear(this.hostCtx());
    AppStorage.setOrCreate('history_version', 0);
    const v = (AppStorage.get('history_version') as number) ?? 0;
    AppStorage.set('history_version', v + 1);
    promptAction.showToast({ message: '浏览历史已清除' });
  }

  private async clearDownloads() {
    const ctx = this.hostCtx();
    const uid = await DownloadStore.getUid(ctx);
    await DownloadStore.clearDownloads(ctx, uid);
    AppStorage.setOrCreate('download_version', 0);
    const v = (AppStorage.get('download_version') as number) ?? 0;
    AppStorage.set('download_version', v + 1);
    promptAction.showToast({ message: '离线下载已清除' });
  }

  build() {
    Stack() {
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column() {
        Row() {
          Text('←')
            .fontSize(20)
            .margin({ left: 16 })
            .onClick(() => router.back());
          Text('隐私中心')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Blank().width(36)
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, right: 16, bottom: 12 })

        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 10 }) {
              Text('隐私设置').fontSize(16).fontWeight(FontWeight.Medium)

              Row() {
                Text('个性化推荐').fontSize(14)
                Blank().layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.personalized })
                  .onChange(async (value: boolean) => {
                    this.personalized = value;
                    await this.saveSetting(this.KEY_PERSONALIZED, value);
                  })
              }
              Row() {
                Text('使用数据统计优化体验').fontSize(14)
                Blank().layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.analytics })
                  .onChange(async (value: boolean) => {
                    this.analytics = value;
                    await this.saveSetting(this.KEY_ANALYTICS, value);
                  })
              }
              Row() {
                Text('个性化广告').fontSize(14)
                Blank().layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.ads })
                  .onChange(async (value: boolean) => {
                    this.ads = value;
                    await this.saveSetting(this.KEY_ADS, value);
                  })
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })

          Column({ space: 10 }) {
              Text('数据管理').fontSize(16).fontWeight(FontWeight.Medium)
              Button('查看隐私政策', { type: ButtonType.Capsule })
                .onClick(async () => await this.openPolicy())
              Button('清除浏览历史', { type: ButtonType.Capsule })
                .backgroundColor('#FEF3C7')
                .fontColor('#92400E')
                .onClick(async () => await this.clearHistory())
              Button('清除离线下载', { type: ButtonType.Capsule })
                .backgroundColor('#FEE2E2')
                .fontColor('#B91C1C')
                .onClick(async () => await this.clearDownloads())
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
          }
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
