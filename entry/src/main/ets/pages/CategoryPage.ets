import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import type { Category } from '../model/Category';
import { FavoriteStore } from '../store/FavoriteStore';
import { fetchArticlesByCid, fetchCategories } from '../service/WanService';
import { ArticleStore } from '../store/ArticleStore';

@Component
export struct CategoryPage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  @State categories: Category[] = [];
  @State selectedCid: number = 0;
  @State articles: Article[] = [];
  @State loadingCats: boolean = true;
  @State loadingArticles: boolean = true;
  @State errorMsg: string = '';
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State nextPage: number = 0;
  @State hasMore: boolean = true;
  @State showBackToTop: boolean = false;
  private articleScroller: Scroller = new Scroller();
  // 监听全局变化：收藏变化 / 登录变化（和你首页/收藏页同一套机制）
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  private onFavVersionChange() {
    this.refreshFav();
  }

  private onSessionVersionChange() {
    this.refreshFav();
  }

  async aboutToAppear() {
    // ✅ 确保 key 存在（避免首次为 undefined）
    AppStorage.setOrCreate('fav_version', 0);
    AppStorage.setOrCreate('session_version', 0);
    await this.refreshFav();
    await this.loadCategories();
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

  private async loadCategories() {
    this.loadingCats = true;
    this.errorMsg = '';
    try {
      const remote = await fetchCategories();
      this.categories = remote;
      this.selectedCid = remote[0]?.cid ?? 0;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '分类加载失败';
      this.categories = [];
      this.selectedCid = 0;
    } finally {
      this.loadingCats = false;
      if (this.selectedCid !== 0) {
        await this.loadArticlesByCid(this.selectedCid, true);
      } else {
        this.loadingArticles = false;
      }
    }
  }

  private async loadArticlesByCid(cid: number, reset: boolean = true) {
    if (!reset && (this.loadingMore || !this.hasMore || this.loadingArticles)) {
      return;
    }

    if (reset) {
      this.loadingArticles = true;
      this.hasMore = true;
      this.nextPage = 0;
      this.articles = [];
    } else {
      this.loadingMore = true;
    }

    this.errorMsg = '';
    try {
      const page = reset ? 0 : this.nextPage;
      const remote = await fetchArticlesByCid(cid, page);
      const merged = reset ? remote : this.dedupArticles([...this.articles, ...remote]);
      this.articles = merged;
      if (remote.length === 0) {
        this.hasMore = false;
      } else {
        this.nextPage = page + 1;
      }
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '文章加载失败';
      if (reset) {
        this.articles = [];
      }
      this.hasMore = false;
    } finally {
      if (reset) {
        this.loadingArticles = false;
        this.refreshing = false;
      } else {
        this.loadingMore = false;
      }
    }
  }

  private async refreshArticles() {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    await this.loadArticlesByCid(this.selectedCid, true);
  }

  private async loadMoreArticles() {
    await this.loadArticlesByCid(this.selectedCid, false);
  }

  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;
    if (uid === '0') {
      this.favIds = new Set<number>();
      return;
    }
    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  private async bumpFavVersion() {
    AppStorage.setOrCreate('fav_version', 0);
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }
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
    await this.bumpFavVersion();
  }

  // 安全跳转（解决 ArkTSCheck：可能抛异常）
  private async openDetail(article: Article) {
    try {
      ArticleStore.setArticles(this.articles);
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
      Column() {
        Text('分类')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 16, left: 16, bottom: 12 })

        Row() {
          // 左侧：分类列表
          Column() {
            List() {
              ForEach(this.categories, (c: Category) => {
                ListItem() {
                  Text(c.name)
                    .fontSize(14)
                    .fontWeight(this.selectedCid === c.cid ? FontWeight.Bold : FontWeight.Normal)
                    .padding(12)
                    .backgroundColor(this.selectedCid === c.cid ? '#EDEDED' : '#FFFFFF')
                    .borderRadius(8)
                }
                .onClick(async () => {
                  if (this.selectedCid !== c.cid) {
                    this.selectedCid = c.cid;
                    this.showBackToTop = false;
                    this.articleScroller.scrollTo({ index: 0, smooth: true });
                    await this.loadArticlesByCid(c.cid, true);
                  }
                })
              }, (c: Category) => c.cid.toString())
            }
          }
          .width('34%')
          .padding({ left: 12, right: 6 })

          // 右侧：文章列表（按 selectedCid 筛选）
          Column() {
            if (this.loadingCats || this.loadingArticles) {
              Row({ space: 8 }) {
                LoadingProgress()
                Text('正在加载数据...').opacity(0.7)
              }
              .padding(12)
            } else if (this.errorMsg) {
              Column({ space: 6 }) {
                Text('网络加载失败，数据暂不可用').fontSize(13).opacity(0.7)
                Text(this.errorMsg).fontSize(12).opacity(0.6)
              }
              .padding({ left: 12, right: 12, bottom: 6 })
            }

            Refresh({ refreshing: this.refreshing }) {
              if (this.articles.length === 0) {
                Text('该分类暂无文章').margin(16).opacity(0.7)
              } else {
                List({ scroller: this.articleScroller }) {
                  ForEach(this.articles, (item: Article) => {
                    ListItem() {
                      Row() {
                        Column({ space: 6 }) {
                          Text(item.title).fontSize(15).fontWeight(FontWeight.Medium)
                          Text(item.desc).fontSize(12).opacity(0.7).maxLines(2)
                        }
                        .layoutWeight(1)

                        Text(this.favIds.has(item.id) ? '❤️' : '🤍')
                          .fontSize(20)
                          .margin({ left: 8 })
                          .gesture(
                            TapGesture().onAction(async () => {
                              await this.toggleFav(item);
                            })
                          )
                      }
                      .padding(12)
                      .margin({ left: 6, right: 12, bottom: 12 })
                      .borderRadius(12)
                      .backgroundColor('#F5F5F5')
                      .onClick(async () => {
                        await this.openDetail(item);
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
                .onScrollIndex((first, last) => {
                  if (last >= this.articles.length - 1) {
                    this.loadMoreArticles();
                  }
                  this.showBackToTop = first > 0;
                })
              }
            }
            .onRefreshing(async () => {
              await this.refreshArticles();
            })
          }
          .width('66%')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 切回分类页也刷新收藏状态
        this.refreshFav();
      })

      if (this.showBackToTop) {
        Positioned({ bottom: 26, right: 20 }) {
          Button('↑ 顶部')
            .backgroundColor('#007DFF')
            .fontColor(Color.White)
            .borderRadius(18)
            .padding({ left: 12, right: 12 })
            .onClick(() => this.articleScroller.scrollTo({ index: 0, smooth: true }))
            }
      }
    }
  }
}
