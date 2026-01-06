import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
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
  @State articles: Article[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State errorMsg: string = '';
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();
  @State nextPage: number = 0;
  @State hasMore: boolean = true;
  @State showBackToTop: boolean = false;
  private listScroller: Scroller = new Scroller();

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
    await this.reloadArticles();
    await this.refreshFav();
  }

  private dedupArticles(list: Article[]): Article[] {
    const seen = new Set<number>();
    const result: Article[] = [];
    list.forEach(item => {
      if (!seen.has(item.id)) {
        seen.add(item.id);
        result.push(item);
      }
    });
    return result;
  }

  private async reloadArticles() {
    this.loading = true;
    this.errorMsg = '';
    this.hasMore = true;
    this.nextPage = 0;
    try {
      const result = await Promise.all([fetchTopArticles(), fetchLatestArticles(0)]);
      const top = result[0];
      const latest = result[1];
      const merged: Article[] = [...top, ...latest];
      this.articles = this.dedupArticles(merged);
      this.hasMore = latest.length > 0;
      this.nextPage = 1;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '加载失败';
      this.articles = [];
      this.hasMore = false;
    } finally {
      this.loading = false;
    }
  }

  private async refreshArticles() {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    await this.reloadArticles();
    this.refreshing = false;
  }

  private async loadMoreArticles() {
    if (this.loadingMore || this.loading || !this.hasMore) {
      return;
    }

    this.loadingMore = true;
    this.errorMsg = '';
    try {
      const latest = await fetchLatestArticles(this.nextPage);
      if (latest.length === 0) {
        this.hasMore = false;
        return;
      }
      const merged = [...this.articles, ...latest];
      this.articles = this.dedupArticles(merged);
      this.nextPage += 1;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '加载失败';
    } finally {
      this.loadingMore = false;
    }
  }

  private scrollToTop() {
    this.listScroller.scrollToIndex(0);
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

  private async openSearchPage() {
    try {
      await router.pushUrl({ url: 'pages/SearchPage' });
    } catch (e) {
      promptAction.showToast({ message: '无法打开搜索页' });
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Blank().width(36)
          Text('首页')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('🔍')
            .fontSize(22)
            .onClick(async () => await this.openSearchPage())
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, left: 16, right: 16, bottom: 12 })

        if (this.loading) {
          Row({ space: 8 }) {
            LoadingProgress()
            Text('正在加载文章...').opacity(0.7)
          }
          .padding(16)
        } else if (this.errorMsg) {
          Column({ space: 6 }) {
            Text('网络加载失败，数据暂不可用').fontSize(14).opacity(0.7)
            Text(this.errorMsg).fontSize(12).opacity(0.6)
          }
          .padding({ left: 16, right: 16, bottom: 6 })
        }

        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.listScroller }) {
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

          ListItem() {
            if (this.loadingMore) {
              Row({ space: 8 }) {
                LoadingProgress().width(20).height(20)
                Text('加载中...').fontSize(13).opacity(0.7)
              }
              .padding(12)
              .justifyContent(FlexAlign.Center)
            } else if (!this.hasMore) {
              Text('已经到底了').fontSize(12).opacity(0.6).padding(12)
            } else {
              Text('上拉加载更多').fontSize(12).opacity(0.5).padding(12)
            }
          }
          }
          .width('100%')
          .layoutWeight(1)
          .onScrollIndex((first, last) => {
            // 靠近底部时触发加载
            if (last >= this.articles.length - 1) {
              this.loadMoreArticles();
            }
            this.showBackToTop = first > 0;
          })
        }
        .onRefreshing(async () => {
          await this.refreshArticles();
        })
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 进入首页时也刷新一次（更稳）
        this.refreshFav();
      })

      if (this.showBackToTop) {
        Button('↑ 顶部')
          .backgroundColor('#007DFF')
          .fontColor(Color.White)
          .borderRadius(18)
          .padding({ left: 12, right: 12 })
          .margin({ bottom: 26, right: 20 })
          .align(Alignment.BottomEnd)
          .onClick(() => this.scrollToTop())
      }
    }
  }
}