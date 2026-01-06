import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { LocalArticles } from '../data/LocalArticles';
import { FavoriteStore } from '../store/FavoriteStore';
import { fetchLatestArticles, fetchTopArticles } from '../service/WanService';
import { ArticleStore } from '../store/ArticleStore';

// ✅ 确保 key 存在（避免首次为 undefined）
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);

@Component
export struct HomePage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ✅ 监听：收藏变化 / 登录变化
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;
  @State articles: Article[] = LocalArticles;
  @State loading: boolean = true;
  @State errorMsg: string = '';
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();

  private onFavVersionChange() {
    this.refreshFav();
  }

  private onSessionVersionChange() {
    this.refreshFav();
  }

  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;

    if (uid === '0') {
      // ✅ 未登录：主页红心全部熄灭
      this.favIds = new Set<number>();
      return;
    }

    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  async aboutToAppear() {
    await this.loadArticles();
    await this.refreshFav();
  }

  private async loadArticles() {
    this.loading = true;
    this.errorMsg = '';
    try {
      const requests: Promise<Article[]>[] = [fetchTopArticles(), fetchLatestArticles()];
      const results = await Promise.all(requests);
      const merged: Article[] = [...results[0], ...results[1]];
      // 去重合并，保证列表至少有几条
      const uniqMap = new Map<number, Article>();
      merged.forEach(item => uniqMap.set(item.id, item));
      const uniq = Array.from(uniqMap.values());
      if (uniq.length > 0) {
        this.articles = uniq;
      } else {
        this.articles = LocalArticles;
      }
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '加载失败';
      this.articles = LocalArticles;
    } finally {
      this.loading = false;
    }
  }

  private async bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  // private async toggleFav(id: number) {
  private async toggleFav(article: Article) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    const next = new Set(this.favIds);
    // if (next.has(id)) {
    //   next.delete(id);
    if (next.has(article.id)) {
      next.delete(article.id);
      await FavoriteStore.removeArticleSnapshot(ctx, article.id);
    } else {
      // next.add(id);
      next.add(article.id);
      await FavoriteStore.saveArticleSnapshot(ctx, article);
    }

    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);

    // 通知其他页面（收藏页/主页自己）
    await this.bumpFavVersion();
  }

  build() {
    Column() {
      Text('首页').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 16, left: 16, bottom: 12 })

      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress()
          Text('正在加载文章...').opacity(0.7)
        }
        .padding(16)
      } else if (this.errorMsg) {
        Column({ space: 6 }) {
          Text('网络加载失败，已使用本地示例数据').fontSize(14).opacity(0.7)
          Text(this.errorMsg).fontSize(12).opacity(0.6)
        }
        .padding({ left: 16, right: 16, bottom: 6 })
      }

      List() {
        ForEach(this.articles, (item: Article) => {
          ListItem() {
            Row() {
              Column({ space: 6 }) {
                Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
              }
              .layoutWeight(1)

              Text(this.favIds.has(item.id) ? '❤️' : '🤍')
                .fontSize(22)
                .margin({ left: 10 })
                // .onClick(async () => await this.toggleFav(item.id))
                .onClick(async () => await this.toggleFav(item))
            }
            .padding(12)
            .margin({ left: 16, right: 16, bottom: 12 })
            .borderRadius(12)
            .backgroundColor('#F5F5F5')
            .onClick(() => {
              ArticleStore.setArticles(this.articles);
              router.pushUrl({
                url: 'pages/ArticleDetailPage',
                params: { id: item.id, article: item }
              })
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .onAppear(() => {
      // 进入首页时也刷新一次（更稳）
      this.refreshFav();
    })
  }
}
