import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { NotificationItem } from '../model/Notification';
import { NotificationStore } from '../store/NotificationStore';
import { FavoriteStore } from '../store/FavoriteStore';

AppStorage.setOrCreate('notification_version', 0);
AppStorage.setOrCreate('session_version', 0);

@Entry
@Component
export struct NotificationPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @StorageLink('notification_version')
  @Watch('onNotificationVersionChange')
  notificationVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;
  @State uid: string = '0';
  @State notifications: NotificationItem[] = [];

  private onNotificationVersionChange() {
    this.refresh();
  }

  private onSessionVersionChange() {
    this.refresh();
  }

  private async refresh() {
    const ctx = this.hostCtx();
    this.uid = await FavoriteStore.getUid(ctx);
    if (this.uid === '0') {
      this.notifications = [];
      return;
    }
    this.notifications = await NotificationStore.load(ctx, this.uid);
  }

  private formatTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private renderTitle(item: NotificationItem): string {
    if (item.type === 'comment_like') {
      return `${item.fromNickname} 点赞了你的评论`;
    }
    return `${item.fromNickname} 回复了你的评论`;
  }

  private async markAllRead() {
    if (this.uid === '0') {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    await NotificationStore.markAllRead(this.hostCtx(), this.uid);
    this.notifications = this.notifications.map(item => Object.assign({}, item, { read: true }));
    const v = (AppStorage.get('notification_version') as number) ?? 0;
    AppStorage.set('notification_version', v + 1);
  }

  private async markAllReadSilently() {
    if (this.uid === '0') {
      return;
    }
    if (!this.notifications.some(item => !item.read)) {
      return;
    }
    await NotificationStore.markAllRead(this.hostCtx(), this.uid);
    this.notifications = this.notifications.map(item => Object.assign({}, item, { read: true }));
    const v = (AppStorage.get('notification_version') as number) ?? 0;
    AppStorage.set('notification_version', v + 1);
  }

  private async openArticle(item: NotificationItem) {
    try {
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: item.articleId }
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

        Text('通知')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 36 })

        Text('全部已读')
          .fontSize(12)
          .opacity(0.7)
          .margin({ right: 16 })
          .onClick(async () => await this.markAllRead());
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })

      if (this.uid === '0') {
        Text('请先去【我的】页登录').margin(16).opacity(0.7)
      } else if (this.notifications.length === 0) {
        Text('暂无通知').margin(16).opacity(0.7)
      } else {
        List() {
          ForEach(this.notifications, (item: NotificationItem) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 6 }) {
                  if (!item.read) {
                    Text('●').fontSize(10).fontColor('#4C6FFF')
                  }
                  Text(this.renderTitle(item)).fontSize(14).fontWeight(FontWeight.Medium)
                }
                Text(`文章：${item.articleTitle}`).fontSize(12).opacity(0.7)
                if (item.content) {
                  Text(item.content).fontSize(12).opacity(0.6).maxLines(2)
                }
                Text(this.formatTime(item.createdAt)).fontSize(11).opacity(0.5)
              }
              .width('100%')
              .padding(12)
              .margin({ bottom: 12 })
              .borderRadius(12)
              .backgroundColor('#F5F5F5')
              .onClick(async () => await this.openArticle(item))
            }
          })
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .onAppear(async () => {
      await this.refresh();
      await this.markAllReadSilently();
    })
  }
}