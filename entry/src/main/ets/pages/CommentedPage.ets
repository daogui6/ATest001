import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { ArticleStore } from '../store/ArticleStore';
import { UserActionStore } from '../store/UserActionStore';
import { fetchArticlesByIds } from '../service/WanService';

AppStorage.setOrCreate('commented_version', 0);
AppStorage.setOrCreate('session_version', 0);

@Entry
@Component
export struct CommentedPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @StorageLink('commented_version')
  @Watch('onCommentedVersionChange')
  commentedVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;
  @State uid: string = '0';
  @State commentedIds: Set<number> = new Set<number>();
  @State commentedArticles: Article[] = [];

  private onCommentedVersionChange() {
    this.refresh();
  }

  private onSessionVersionChange() {
    this.refresh();
  }

  private async refresh() {
    const ctx = this.hostCtx();
    this.uid = await UserActionStore.getUid(ctx);
    if (this.uid === '0') {
      this.commentedIds = new Set<number>();
      this.commentedArticles = [];
      return;
    }

    const set = await UserActionStore.loadCommentedSet(ctx, this.uid);
    this.commentedIds = set;
    try {
      const remote = await fetchArticlesByIds(set);
      const remoteIds = new Set(remote.map(item => item.id));
      const cached = await UserActionStore.pickCachedCommentedArticles(ctx, set);
      const merged = [...remote];
      cached.forEach(item => {
        if (!remoteIds.has(item.id)) {
          merged.push(item);
        }
      });
      this.commentedArticles = merged;
    } catch (e) {
      promptAction.showToast({ message: (e as Error)?.message ?? '评论数据加载失败' });
      this.commentedArticles = await UserActionStore.pickCachedCommentedArticles(ctx, set);
    }
  }

  private async openDetail(article: Article) {
    try {
      ArticleStore.setArticles(this.commentedArticles);
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
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

        Text('评论过')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 36 })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })

      if (this.uid === '0') {
        Text('请先去【我的】页登录').margin(16).opacity(0.7)
      } else if (this.commentedArticles.length === 0) {
        Text('暂无评论记录').margin(16).opacity(0.7)
      } else {
        List() {
          ForEach(this.commentedArticles, (item: Article) => {
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
              .borderRadius(12)
              .backgroundColor('#F5F5F5')
              .justifyContent(FlexAlign.SpaceBetween)
              .onClick(async () => await this.openDetail(item))
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
    .onAppear(() => {
      this.refresh();
    })
  }
}