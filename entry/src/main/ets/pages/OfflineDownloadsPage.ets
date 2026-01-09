/**
 * 离线下载页面 - 管理已下载文章
 *
 * 功能概述：
 * - 展示离线下载的文章列表
 * - 支持查看与删除下载内容
 * - 按下载时间倒序显示
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { DownloadStore, type DownloadedArticle } from '../store/DownloadStore';
import { ArticleStore } from '../store/ArticleStore';

@Entry
@Component
export struct OfflineDownloadsPage {
  @State uid: string = '0';
  @State downloads: DownloadedArticle[] = [];

  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear() {
    await this.refresh();
  }

  private async refresh() {
    const ctx = this.hostCtx();
    this.uid = await DownloadStore.getUid(ctx);
    this.downloads = await DownloadStore.loadDownloads(ctx, this.uid);
  }

  private formatTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private async openDetail(article: Article) {
    try {
      ArticleStore.setArticle(article);
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  private async removeDownload(id: number) {
    const ctx = this.hostCtx();
    await DownloadStore.removeDownload(ctx, this.uid, id);
    this.downloads = this.downloads.filter(item => item.id !== id);
    promptAction.showToast({ message: '已删除离线内容' });
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(20)
          .margin({ left: 16 })
          .onClick(() => router.back());
        Text('离线下载')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(36)
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.downloads.length === 0) {
            Text('暂无离线内容，快去下载文章吧').margin(16).opacity(0.6)
          } else {
            ForEach(this.downloads, (item: DownloadedArticle) => {
              Column({ space: 8 }) {
                Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                Text(`作者：${item.author || '未知'}`).fontSize(12).opacity(0.6)
                Text(`下载时间：${this.formatTime(item.downloadedAt)}`).fontSize(11).opacity(0.6)
                Row({ space: 10 }) {
                  Button('查看', { type: ButtonType.Capsule })
                    .onClick(async () => await this.openDetail(item))
                  Button('删除', { type: ButtonType.Capsule })
                    .backgroundColor('#FEE2E2')
                    .fontColor('#B91C1C')
                    .onClick(async () => await this.removeDownload(item.id))
                }
              }
              .padding(14)
              .borderRadius(12)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' })
              .shadow({ radius: 10, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
            })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EFF2F9')
  }
}