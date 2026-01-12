/**
 * 待读清单页面 - 用户待阅读文章管理
 *
 * 功能概述：
 * - 展示用户加入待读清单的文章
 * - 实时同步待读清单状态变化
 * - 提供文章详情跳转功能
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { ArticleStore } from '../store/ArticleStore';
import { ReadingListStore } from '../store/ReadingListStore';
import { fetchArticlesByIds } from '../service/WanService';

AppStorage.setOrCreate('reading_version', 0);
AppStorage.setOrCreate('session_version', 0);

@Entry
@Component
export struct ReadingListPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @StorageLink('reading_version')
  @Watch('onReadingVersionChange')
  readingVersion: number = 0;

  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  @State uid: string = '0';
  @State readingIds: Set<number> = new Set<number>();
  @State readingArticles: Article[] = [];

  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;
  @State listOpacity: number = 0;
  @State listOffset: number = 16;

  private onReadingVersionChange() {
    this.refresh();
  }

  private onSessionVersionChange() {
    this.refresh();
  }

  private async refresh() {
    const ctx = this.hostCtx();
    this.uid = await ReadingListStore.getUid(ctx);
    if (this.uid === '0') {
      this.readingIds = new Set<number>();
      this.readingArticles = [];
      return;
    }

    const set = await ReadingListStore.loadList(ctx, this.uid);
    this.readingIds = set;
    try {
      this.readingArticles = await fetchArticlesByIds(set);
    } catch (e) {
      promptAction.showToast({ message: (e as Error)?.message ?? '待读清单加载失败' });
      this.readingArticles = [];
    }
  }

  private async openDetail(article: Article) {
    try {
      ArticleStore.setArticles(this.readingArticles);
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
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

          Text('待读清单')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .margin({ right: 36 })
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, right: 16, bottom: 12 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        if (this.uid === '0') {
          Text('请先去【我的】页登录').margin(16).opacity(0.7)
            .opacity(this.listOpacity)
            .translate({ x: 0, y: this.listOffset })
        } else if (this.readingIds.size === 0) {
          Text('暂无待读文章').margin(16).opacity(0.7)
            .opacity(this.listOpacity)
            .translate({ x: 0, y: this.listOffset })
        } else {
          List() {
            ForEach(this.readingArticles, (item: Article) => {
              ListItem() {
                Column({ space: 6 }) {
                  Text(item.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(2)
                  Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                  Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                }
                .width('100%')
                .height(120)
                .padding(12)
                .margin({ bottom: 12 })
                .borderRadius(16)
                .backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#E9EEF5' })
                .justifyContent(FlexAlign.SpaceBetween)
                .onClick(async () => await this.openDetail(item))
              }
            })
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
          .layoutWeight(1)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
        }
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        this.refresh();

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
    .width('100%')
    .height('100%')
  }
}