/**
 * 首页 - 文章流展示页面
 * 
 * 功能概述：
 * - 展示置顶文章和最新文章
 * - 支持下拉刷新和上拉加载更多
 * - 文章收藏状态管理
 * - 搜索功能入口
 * 
 * 组件结构：
 * - Component组件封装首页逻辑
 * - 响应式状态管理文章数据
 * - 全局状态同步收藏状态
 * 
 * 状态管理：
 * - 文章列表和分页状态
 * - 收藏ID集合管理
 * - 加载和错误状态
 * - 动画效果状态
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型和存储导入
import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { fetchLatestArticles, fetchTopArticles } from '../service/WanService';
import { ArticleStore } from '../store/ArticleStore';

// 确保全局状态key存在
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 * 首页组件
 * 核心职责：文章流展示和用户交互
 */
@Component
export struct HomePage {
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // 全局状态同步
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;
  
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // 文章数据状态
  @State articles: Article[] = [];
  @State loading: boolean = true;
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State errorMsg: string = '';
  @State uid: string = '0';
  @State favIds: Set<number> = new Set<number>();
  @State nextPage: number = 0;
  @State hasMore: boolean = true;
  
  // UI动画状态
  @State showBackToTop: boolean = false;
  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;
  @State backTopOpacity: number = 0;
  @State backTopScale: number = 0.9;
  
  private listScroller: Scroller = new Scroller();

  private onFavVersionChange() {
    this.refreshFav();
  }

  private onSessionVersionChange() {
    this.refreshFav();
  }

  /**
   * 刷新收藏状态
   * 获取当前用户的收藏列表
   */
  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;

    if (uid === '0') {
      // 未登录用户清空收藏状态
      this.favIds = new Set<number>();
      return;
    }

    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  /**
   * 组件生命周期：页面即将显示
   */
  async aboutToAppear() {
    await this.reloadArticles();
    await this.refreshFav();
  }

  /**
   * 文章去重工具
   */
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

  /**
   * 文章随机排序
   */
  private shuffleArticles(list: Article[]): Article[] {
    const result = [...list];
    for (let i = result.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  /**
   * 重新加载文章
   * 获取置顶和最新文章
   */
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

  /**
   * 刷新文章列表
   */
  private async refreshArticles() {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    await this.reloadArticles();
    this.articles = this.shuffleArticles(this.articles);
    this.refreshing = false;
  }

  /**
   * 加载更多文章
   */
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

  private animateHeader() {
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.headerOpacity = 1;
      this.headerOffset = 0;
    });
  }

  private updateBackToTop(show: boolean) {
    if (this.showBackToTop === show) {
      return;
    }
    this.showBackToTop = show;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.backTopOpacity = show ? 1 : 0;
      this.backTopScale = show ? 1 : 0.9;
    });
  }

  private async bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  /**
   * 切换收藏状态
   */
  private async toggleFav(article: Article) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    const next = new Set(this.favIds);
    if (next.has(article.id)) {
      next.delete(article.id);
      await FavoriteStore.removeArticleSnapshot(ctx, article.id);
    } else {
      next.add(article.id);
      await FavoriteStore.saveArticleSnapshot(ctx, article);
    }

    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);
    await this.bumpFavVersion();
  }

  private async openSearchPage() {
    try {
      await router.pushUrl({ url: 'pages/SearchPage' });
    } catch (e) {
      promptAction.showToast({ message: '无法打开搜索页' });
    }
  }

  /**
   * UI构建方法
   * 创建首页文章流界面
   */
  build() {
    Stack() {
      Column() {
        // 头部导航栏
        Row() {
          Blank().width(36)
          Text('首页')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Text('搜索')
            .fontSize(18)
            .backgroundColor('#F3F4F6')
            .padding(6)
            .borderRadius(14)
            .shadow({ radius: 8, color: '#14000000', offsetX: 0, offsetY: 3 })
            .onClick(async () => await this.openSearchPage())
        }
        .alignItems(VerticalAlign.Center)
        .padding(12)
        .margin({ top: 12, left: 16, right: 16, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 6 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // 内容区域
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

        // 下拉刷新容器
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

                  Text(this.favIds.has(item.id) ? '★' : '☆')
                    .fontSize(22)
                    .margin({ left: 10 })
                    .onClick(async () => await this.toggleFav(item))
                }
                .padding(12)
                .margin({ left: 16, right: 16, bottom: 12 })
                  .borderRadius(16)
                  .backgroundColor('#FFFFFF')
                  .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 5 })
                .onClick(() => {
                  ArticleStore.setArticles(this.articles);
                  router.pushUrl({
                    url: 'pages/ArticleDetailPage',
                    params: { id: item.id, article: item }
                  })
                })
              }
            })

            // 列表底部状态
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
              if (last >= this.articles.length - 1) {
                this.loadMoreArticles();
              }
              this.updateBackToTop(first > 0);
            })
        }
        .onRefreshing(async () => {
          await this.refreshArticles();
        })
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        this.refreshFav();
        this.animateHeader();
      })

      // 返回顶部按钮
      Button('↑')
        .backgroundColor('#FFFFFF')
        .fontColor('#444444')
        .border({ width: 1, color: '#E3E5EA', style: BorderStyle.Solid })
        .borderRadius(20)
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .position({ x: '85%', y: '92%' })
        .margin({ right: 16, bottom: 24 })
        .shadow({ radius: 10, color: '#1A000000', offsetX: 0, offsetY: 4 })
        .opacity(this.backTopOpacity)
        .scale({ x: this.backTopScale, y: this.backTopScale })
        .enabled(this.showBackToTop)
        .onClick(() => this.scrollToTop())
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }
}