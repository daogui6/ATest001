import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { HistoryStore } from '../store/HistoryStore';

AppStorage.setOrCreate('history_version', 0);

@Entry
@Component
export struct HistoryPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @State history: Article[] = [];
  @State loading: boolean = false;
  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;
  @State listOpacity: number = 0;
  @State listOffset: number = 16;
  @StorageLink('history_version')
  @Watch('onHistoryVersionChange')
  historyVersion: number = 0;

  async aboutToAppear() {
    await this.loadHistory();
  }

  private onHistoryVersionChange() {
    this.loadHistory();
  }

  private async loadHistory() {
    this.loading = true;
    const list = await HistoryStore.loadHistory(this.hostCtx());
    this.history = list;
    this.loading = false;
  }

  private async clearHistory() {
    await HistoryStore.clear(this.hostCtx());
    this.history = [];
    promptAction.showToast({ message: '已清空历史' });
  }

  private async openDetail(id: number) {
    try {
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .margin({ left: 16 })
          .onClick(() => router.back());
        Text('阅读历史')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        if (this.history.length > 0) {
          Button('清空', { type: ButtonType.Capsule })
            .onClick(async () => await this.clearHistory());
        } else {
          Blank().width(78)
        }
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })
      .opacity(this.headerOpacity)
      .translate({ x: 0, y: this.headerOffset })

      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress()
          Text('正在加载历史...').opacity(0.7)
        }
        .padding(16)
        .opacity(this.listOpacity)
        .translate({ x: 0, y: this.listOffset })
      } else if (this.history.length === 0) {
        Text('暂无阅读记录').margin(16).opacity(0.7)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
      } else {
        List() {
          ForEach(this.history, (item: Article) => {
            ListItem() {
              Row() {
                Column({ space: 6 }) {
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                  Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                  Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                }
                .layoutWeight(1)
              }
              .padding(12)
              .margin({ left: 16, right: 16, bottom: 12 })
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openDetail(item.id))
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .opacity(this.listOpacity)
        .translate({ x: 0, y: this.listOffset })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7FB')
    .onAppear(() => {
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.headerOpacity = 1;
        this.headerOffset = 0;
      });
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.listOpacity = 1;
        this.listOffset = 0;
      });
    })
  }
}