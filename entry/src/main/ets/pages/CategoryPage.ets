/**
 * 分类页面 - 文章分类浏览与筛选
 * 
 *  功能概述：
 * - 多级文章分类展示与切换
 * - 分类文章列表的分页加载
 * - 下拉刷新与上拉加载更多
 * - 收藏状态管理与同步
 * - 返回顶部动画交互
 * 
 *  架构特点：
 * - 双栏布局：左侧分类导航 + 右侧文章列表
 * - 响应式状态管理：分类切换实时更新内容
 * - 滚动优化：虚拟列表 + 智能加载
 * - 全局状态同步：收藏状态跨页面同步
 * 
 *  技术亮点：
 * - 分类切换无刷新数据加载
 * - 平滑动画过渡效果
 * - 防重复加载机制
 * - 优雅的错误处理
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型导入
import type { Article } from '../model/Article';
import type { Category } from '../model/Category';
import { FavoriteStore } from '../store/FavoriteStore';
import { fetchArticlesByCid, fetchCategories } from '../service/WanService';
import { ArticleStore } from '../store/ArticleStore';

/**
 *  分类页面主组件
 * 
 * 核心功能：
 * - 分类导航与文章列表联动展示
 * - 支持下拉刷新和上拉加载更多
 * - 收藏状态实时同步
 * - 平滑的动画交互体验
 */
@Component
export struct CategoryPage {
  /**
   * 获取宿主上下文
   * 用于访问UIAbility上下文，执行数据存储等操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  //  响应式状态变量
  
  /**
   * @State 管理的组件内部状态
   * 状态变化会自动触发UI重新渲染
   */
  @State categories: Category[] = []; // 分类列表数据
  @State selectedCid: number = 0; // 当前选中的分类ID
  @State articles: Article[] = []; // 当前分类下的文章列表
  @State loadingCats: boolean = true; // 分类加载状态
  @State loadingArticles: boolean = true; // 文章加载状态
  @State errorMsg: string = ''; // 错误信息
  @State uid: string = '0'; // 当前用户ID
  @State favIds: Set<number> = new Set<number>(); // 用户收藏的文章ID集合
  @State refreshing: boolean = false; // 下拉刷新状态
  @State loadingMore: boolean = false; // 加载更多状态
  @State nextPage: number = 0; // 下一页页码（分页用）
  @State hasMore: boolean = true; // 是否还有更多数据
  @State showBackToTop: boolean = false; // 是否显示返回顶部按钮
  
  //  动画相关状态
  @State headerOpacity: number = 0; // 头部标题透明度
  @State headerOffset: number = 12; // 头部标题偏移量
  @State backTopOpacity: number = 0; // 返回顶部按钮透明度
  @State backTopScale: number = 0.9; // 返回顶部按钮缩放
  
  /**
   * 滚动控制器
   * 用于控制文章列表的滚动行为
   */
  private articleScroller: Scroller = new Scroller();
  
  /**
   *  全局状态同步
   * @StorageLink 与AppStorage建立双向绑定
   * @Watch 监听状态变化，触发回调函数
   * 
   * 实现跨页面状态同步：当其他页面修改收藏或登录状态时，
   * 当前页面会自动更新收藏状态
   */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0; // 收藏版本号
  
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0; // 会话版本号

  /**
   * 收藏版本变化监听器
   * 当全局收藏状态变化时，刷新本地收藏状态
   */
  private onFavVersionChange() {
    this.refreshFav();
  }

  /**
   * 会话版本变化监听器
   * 当用户登录状态变化时，刷新收藏状态
   */
  private onSessionVersionChange() {
    this.refreshFav();
  }

  /**
   *  组件生命周期：页面即将显示
   * 在此阶段执行数据初始化操作
   */
  async aboutToAppear() {
    // 确保全局状态key存在（避免首次为undefined）
    AppStorage.setOrCreate('fav_version', 0);
    AppStorage.setOrCreate('session_version', 0);
    
    // 初始化数据
    await this.refreshFav(); // 刷新收藏状态
    await this.loadCategories(); // 加载分类数据
  }

  /**
   *  文章去重工具方法
   * 防止分页加载时出现重复文章
   * 
   * @param list 待去重的文章列表
   * @returns 去重后的文章列表
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
   *  文章列表随机排序
   * 刷新时重新排列文章顺序，增加内容新鲜感
   * 
   * @param list 待排序的文章列表
   * @returns 随机排序后的文章列表
   */
  private shuffleArticles(list: Article[]): Article[] {
    const result = [...list];
    // Fisher-Yates洗牌算法
    for (let i = result.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));
      const temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }
    return result;
  }

  /**
   *  加载分类数据
   * 从远程API获取文章分类列表
   */
  private async loadCategories() {
    this.loadingCats = true;
    this.errorMsg = '';
    
    try {
      const remote = await fetchCategories();
      this.categories = remote;
      const params = router.getParams() as { cid?: number | string } | undefined;
      const rawCid = params?.cid;
      const requestedCid = typeof rawCid === 'number' ? rawCid : Number(rawCid);
      const matchedCid = remote.some(item => item.cid === requestedCid) ? requestedCid : 0;
      // 默认选中第一个分类或传入分类
      this.selectedCid = matchedCid ?? remote[0]?.cid ?? 0;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '分类加载失败';
      this.categories = [];
      this.selectedCid = 0;
    } finally {
      this.loadingCats = false;
      
      // 分类加载完成后，自动加载对应分类的文章
      if (this.selectedCid !== 0) {
        await this.loadArticlesByCid(this.selectedCid, true);
      } else {
        this.loadingArticles = false;
      }
    }
  }

  /**
   *  按分类ID加载文章
   * 支持分页加载和重置加载两种模式
   * 
   * @param cid 分类ID
   * @param reset 是否重置加载（true:重新加载，false:加载更多）
   */
  private async loadArticlesByCid(cid: number, reset: boolean = true) {
    // 防重复加载检查
    if (!reset && (this.loadingMore || !this.hasMore || this.loadingArticles)) {
      return;
    }

    // 设置加载状态
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
      
      // 合并文章列表（加载更多时需要去重）
      const merged = reset ? remote : this.dedupArticles([...this.articles, ...remote]);
      this.articles = merged;
      
      // 判断是否还有更多数据
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
      // 重置加载状态
      if (reset) {
        this.loadingArticles = false;
        this.refreshing = false;
      } else {
        this.loadingMore = false;
      }
    }
  }

  /**
   *  刷新文章列表
   * 下拉刷新时调用，重新加载并随机排序
   */
  private async refreshArticles() {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    await this.loadArticlesByCid(this.selectedCid, true);
    // 刷新后随机排序，增加内容新鲜感
    this.articles = this.shuffleArticles(this.articles);
  }

  /**
   *  加载更多文章
   * 上拉加载更多时调用
   */
  private async loadMoreArticles() {
    await this.loadArticlesByCid(this.selectedCid, false);
  }

  /**
   *  刷新收藏状态
   * 获取当前用户的收藏列表
   */
  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;
    
    // 未登录用户清空收藏状态
    if (uid === '0') {
      this.favIds = new Set<number>();
      return;
    }
    
    // 加载用户收藏集合
    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  /**
   *  头部标题动画
   * 页面显示时执行渐入动画
   */
  private animateHeader() {
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.headerOpacity = 1;
      this.headerOffset = 0;
    });
  }

  /**
   *  更新返回顶部按钮状态
   * 根据滚动位置显示/隐藏返回顶部按钮
   * 
   * @param show 是否显示返回顶部按钮
   */
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

  /**
   *  触发全局收藏版本更新
   * 修改收藏状态后通知其他页面同步更新
   */
  private async bumpFavVersion() {
    AppStorage.setOrCreate('fav_version', 0);
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  /**
   *  收藏/取消收藏切换
   * 
   * @param article 要操作的文章对象
   */
  private async toggleFav(article: Article) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    
    // 登录验证
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    // 更新本地收藏状态
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
    await this.bumpFavVersion(); // 触发全局状态同步
  }

  /**
   *  安全跳转到文章详情页
   * 包含异常处理，防止跳转失败
   * 
   * @param article 要查看的文章对象
   */
  private async openDetail(article: Article) {
    try {
      // 缓存当前文章列表，供详情页使用
      ArticleStore.setArticles(this.articles);
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * ️ 页面UI构建
   * 采用Stack + Column分层布局结构
   */
  build() {
    Stack() {
      //  主内容区域
      Column() {
        //  头部标题区域（带动画效果）
        Row() {
          Text('分类')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(12)
        .margin({ top: 12, left: 16, right: 16, bottom: 12 })
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 6 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        //  主体内容区域：双栏布局
        Row() {
          //  左侧：分类导航列表
          Column() {
            List() {
              ForEach(this.categories, (c: Category) => {
                ListItem() {
                  Text(c.name)
                    .fontSize(14)
                    .fontWeight(this.selectedCid === c.cid ? FontWeight.Bold : FontWeight.Normal)
                    .padding(12)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.selectedCid === c.cid ? '#EEF4FF' : '#FFFFFF')
                    .borderRadius(8)
                    .border({ width: 1, color: this.selectedCid === c.cid ? '#D6E4FF' : '#EEF0F3' })
                    .shadow({ radius: 6, color: '#0D000000', offsetX: 0, offsetY: 2 })
                }
                .width('100%')
                .onClick(async () => {
                  // 分类切换逻辑
                  if (this.selectedCid !== c.cid) {
                    this.selectedCid = c.cid;
                    this.showBackToTop = false; // 隐藏返回顶部按钮
                    this.articleScroller.scrollToIndex(0); // 滚动到顶部
                    await this.loadArticlesByCid(c.cid, true); // 加载新分类文章
                  }
                })
              }, (c: Category) => c.cid.toString()) // 唯一键生成器
            }
          }
          .width('34%')
          .padding({ left: 12, right: 6 })

          //  右侧：文章列表区域
          Column() {
            //  加载状态显示
            if (this.loadingCats || this.loadingArticles) {
              Row({ space: 8 }) {
                LoadingProgress()
                Text('正在加载数据...').opacity(0.7)
              }
              .padding(12)
            } else if (this.errorMsg) {
              //  错误状态显示
              Column({ space: 6 }) {
                Text('网络加载失败，数据暂不可用').fontSize(13).opacity(0.7)
                Text(this.errorMsg).fontSize(12).opacity(0.6)
              }
              .padding({ left: 12, right: 12, bottom: 6 })
            }

            //  下拉刷新容器
            Refresh({ refreshing: this.refreshing }) {
              if (this.articles.length === 0) {
                //  空状态提示
                Text('该分类暂无文章').margin(16).opacity(0.7)
              } else {
                //  文章列表
                List({ scroller: this.articleScroller }) {
                  ForEach(this.articles, (item: Article) => {
                    ListItem() {
                      Row() {
                        // 文章信息区域
                        Column({ space: 6 }) {
                          Text(item.title).fontSize(15).fontWeight(FontWeight.Medium)
                          Text(item.desc).fontSize(12).opacity(0.7).maxLines(2)
                        }
                        .layoutWeight(1)

                        // 收藏按钮
                        Text(this.favIds.has(item.id) ? '★' : '☆')
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
                      .borderRadius(16)
                      .backgroundColor('#FFFFFF')
                      .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 5 })
                      .onClick(async () => {
                        await this.openDetail(item);
                      })
                    }
                  })

                  //  列表底部加载状态
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
                  // 滚动监听：触底加载更多
                  if (last >= this.articles.length - 1) {
                    this.loadMoreArticles();
                  }
                  // 根据滚动位置显示/隐藏返回顶部按钮
                  this.updateBackToTop(first > 0);
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
        // 页面显示时刷新收藏状态和执行动画
        this.refreshFav();
        this.animateHeader();
      })

      //  返回顶部按钮（浮动在内容上方）
      Button('↑')
        .backgroundColor('#FFFFFF')
        .fontColor('#444444')
        .border({ width: 1, color: '#E3E5EA', style: BorderStyle.Solid })
        .borderRadius(20)
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .position({ x: '85%', y: '92%' }) // 定位到父容器右下角
        .margin({ right: 16, bottom: 24 }) // 通过负边距调整位置
        .shadow({ radius: 10, color: '#1A000000', offsetX: 0, offsetY: 4 })
        .opacity(this.backTopOpacity)
        .scale({ x: this.backTopScale, y: this.backTopScale })
        .enabled(this.showBackToTop)
        .onClick(() => this.articleScroller.scrollToIndex(0))
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA') // 页面背景色
  }
}