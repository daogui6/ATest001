/**
 * 分类页面 - 文章分类浏览与筛选
 *
 * 功能概述：
 * - 多级文章分类展示与切换
 * - 分类文章列表的分页加载
 * - 下拉刷新与上拉加载更多
 * - 收藏状态管理与同步
 * - 返回顶部动画交互
 *
 * 架构特点：
 * - 双栏布局：左侧分类导航 + 右侧文章列表
 * - 响应式状态管理：分类切换实时更新内容
 * - 滚动优化：虚拟列表 + 智能加载
 * - 全局状态同步：收藏状态跨页面同步
 *
 * 技术亮点：
 * - 分类切换无刷新数据加载
 * - 平滑动画过渡效果
 * - 防重复加载机制
 * - 优雅的错误处理
 *
 * 页面结构：
 * - Stack层叠布局：背景图 + 主内容 + 浮动按钮
 * - Column垂直布局：头部导航 + 双栏内容
 * - Row水平布局：分类导航 + 文章列表
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
import { AppLoadingProgress } from '../components/AppLoadingProgress';

/**
 * 分类页面路由参数接口
 * 用于接收从其他页面跳转时传递的参数
 */
interface CategoryPageParams {
  cid?: number | string;    // 可选分类ID，用于直接跳转到指定分类
  fromHome?: boolean;       // 是否从首页跳转，用于显示返回按钮
}

/**
 * 分类页面主组件
 *
 * 核心功能：
 * - 分类导航与文章列表联动展示
 * - 支持下拉刷新和上拉加载更多
 * - 收藏状态实时同步
 * - 平滑的动画交互体验
 *
 * 数据流：
 * 1. 页面初始化 → 加载分类列表
 * 2. 分类选择 → 加载对应文章
 * 3. 滚动操作 → 分页加载更多
 * 4. 收藏操作 → 更新本地和全局状态
 */
@Entry
@Component
export struct CategoryPage {
  /**
   * 获取宿主上下文
   * 用于访问UIAbility上下文，执行数据存储等操作
   *
   * @returns UIAbility上下文对象
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ==================== 响应式状态变量 ====================

  /**
   * @State 管理的组件内部状态
   * 状态变化会自动触发UI重新渲染
   */
  @State categories: Category[] = [];           // 分类列表数据
  @State selectedCid: number = 0;               // 当前选中的分类ID，0表示未选择
  @State articles: Article[] = [];              // 当前分类下的文章列表
  @State loadingCats: boolean = true;           // 分类数据加载状态
  @State loadingArticles: boolean = true;       // 文章数据加载状态
  @State errorMsg: string = '';                 // 错误信息显示
  @State uid: string = '0';                     // 当前用户ID，'0'表示未登录
  @State favIds: Set<number> = new Set<number>(); // 用户收藏的文章ID集合
  @State refreshing: boolean = false;           // 下拉刷新状态
  @State loadingMore: boolean = false;          // 加载更多状态
  @State nextPage: number = 0;                  // 下一页页码（用于分页加载）
  @State hasMore: boolean = true;               // 是否还有更多数据可加载
  @State showBackToTop: boolean = false;        // 是否显示返回顶部按钮
  @State showBackButton: boolean = false;       // 是否显示返回按钮（从首页跳转时显示）

  // ==================== 动画相关状态 ====================

  @State headerOpacity: number = 0;             // 头部标题透明度（用于渐入动画）
  @State headerOffset: number = 12;             // 头部标题偏移量（用于滑动动画）
  @State backTopOpacity: number = 0;            // 返回顶部按钮透明度
  @State backTopScale: number = 0.9;            // 返回顶部按钮缩放比例

  /**
   * 滚动控制器
   * 用于控制文章列表的滚动行为，支持滚动到指定位置
   */
  private articleScroller: Scroller = new Scroller();

  // ==================== 全局状态同步 ====================

  /**
   * @StorageLink 与AppStorage建立双向绑定
   * @Watch 监听状态变化，触发回调函数
   *
   * 实现跨页面状态同步：当其他页面修改收藏或登录状态时，
   * 当前页面会自动更新收藏状态
   */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0; // 收藏版本号，用于触发收藏状态更新

  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0; // 会话版本号，用于用户登录状态变化

  /**
   * 收藏版本变化监听器
   * 当全局收藏状态变化时，刷新本地收藏状态
   *
   * 触发场景：
   * - 其他页面修改了收藏状态
   * - 用户登录/退出登录
   */
  private onFavVersionChange() {
    this.refreshFav();
  }

  /**
   * 会话版本变化监听器
   * 当用户登录状态变化时，刷新收藏状态
   *
   * 触发场景：
   * - 用户登录成功
   * - 用户退出登录
   */
  private onSessionVersionChange() {
    this.refreshFav();
  }

  /**
   * 组件生命周期：页面即将显示
   * 在此阶段执行数据初始化操作
   *
   * 执行顺序：
   * 1. 确保全局状态存在
   * 2. 解析路由参数
   * 3. 刷新收藏状态
   * 4. 加载分类数据
   */
  async aboutToAppear() {
    // 确保全局状态key存在（避免首次为undefined）
    AppStorage.setOrCreate('fav_version', 0);
    AppStorage.setOrCreate('session_version', 0);

    // 解析路由参数，判断是否显示返回按钮
    const params = router.getParams() as CategoryPageParams | undefined;
    this.showBackButton = Boolean(params?.fromHome);

    // 初始化数据（顺序执行，确保依赖关系）
    await this.refreshFav();      // 刷新收藏状态
    await this.loadCategories();  // 加载分类数据
  }

  /**
   * 文章去重工具方法
   * 防止分页加载时出现重复文章
   *
   * 应用场景：
   * - 加载更多时合并新旧数据
   * - 下拉刷新后重新加载
   *
   * @param list 待去重的文章列表
   * @returns 去重后的文章列表（保持原始顺序）
   */
  private dedupArticles(list: Article[]): Article[] {
    const seen = new Set<number>();  // 用于记录已见过的文章ID
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
   * 文章列表随机排序
   * 刷新时重新排列文章顺序，增加内容新鲜感
   *
   * 算法：Fisher-Yates洗牌算法（原地随机排序）
   * 时间复杂度：O(n)
   *
   * @param list 待排序的文章列表
   * @returns 随机排序后的文章列表
   */
  private shuffleArticles(list: Article[]): Article[] {
    const result = [...list];  // 创建副本，避免修改原数组

    // Fisher-Yates洗牌算法实现
    for (let i = result.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1));  // 随机索引
      const temp = result[i];
      result[i] = result[j];
      result[j] = temp;
    }

    return result;
  }

  /**
   * 加载分类数据
   * 从远程API获取文章分类列表并设置默认选中项
   *
   * 逻辑流程：
   * 1. 设置加载状态和清空错误信息
   * 2. 从API获取分类数据
   * 3. 根据路由参数设置默认选中分类
   * 4. 加载对应分类的文章数据
   */
  private async loadCategories() {
    this.loadingCats = true;
    this.errorMsg = '';

    try {
      const remote = await fetchCategories();  // 获取远程分类数据
      this.categories = remote;

      // 解析路由参数中的分类ID
      const params = router.getParams() as CategoryPageParams | undefined;
      const rawCid = params?.cid;
      const requestedCid = typeof rawCid === 'number' ? rawCid : Number(rawCid);

      // 验证请求的分类ID是否存在
      const matchedCid = remote.some(item => item.cid === requestedCid) ? requestedCid : 0;
      const fallbackCid = remote[0]?.cid ?? 0;  // 默认选择第一个分类

      // 设置选中分类：优先使用请求的分类，否则使用默认分类
      this.selectedCid = matchedCid !== 0 ? matchedCid : fallbackCid;
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '分类加载失败';
      this.categories = [];
      this.selectedCid = 0;
    } finally {
      this.loadingCats = false;

      // 分类加载完成后，自动加载对应分类的文章
      if (this.selectedCid !== 0) {
        await this.loadArticlesByCid(this.selectedCid, true);  // 重置加载
      } else {
        this.loadingArticles = false;  // 没有分类可加载
      }
    }
  }

  /**
   * 按分类ID加载文章
   * 支持分页加载和重置加载两种模式
   *
   * 防重复加载机制：
   * - 重置加载：loadingArticles状态控制
   * - 加载更多：loadingMore状态控制
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
      this.articles = [];  // 重置时清空现有文章
    } else {
      this.loadingMore = true;
    }

    this.errorMsg = '';

    try {
      const page = reset ? 0 : this.nextPage;  // 重置时从第0页开始
      const remote = await fetchArticlesByCid(cid, page);

      // 合并文章列表（加载更多时需要去重）
      const merged = reset ? remote : this.dedupArticles([...this.articles, ...remote]);
      this.articles = merged;

      // 判断是否还有更多数据
      if (remote.length === 0) {
        this.hasMore = false;  // 没有更多数据
      } else {
        this.nextPage = page + 1;  // 更新下一页页码
      }
    } catch (e) {
      this.errorMsg = (e as Error)?.message ?? '文章加载失败';
      if (reset) {
        this.articles = [];  // 重置加载失败时清空列表
      }
      this.hasMore = false;
    } finally {
      // 重置加载状态
      if (reset) {
        this.loadingArticles = false;
        this.refreshing = false;  // 结束下拉刷新
      } else {
        this.loadingMore = false;  // 结束加载更多
      }
    }
  }

  /**
   * 刷新文章列表
   * 下拉刷新时调用，重新加载并随机排序
   *
   * 特点：
   * - 防重复刷新：refreshing状态控制
   * - 增加新鲜感：随机排序文章
   * - 完整重置：从第0页重新加载
   */
  private async refreshArticles() {
    if (this.refreshing) {
      return;  // 防止重复刷新
    }

    this.refreshing = true;
    await this.loadArticlesByCid(this.selectedCid, true);

    // 刷新后随机排序，增加内容新鲜感
    this.articles = this.shuffleArticles(this.articles);
  }

  /**
   * 加载更多文章
   * 上拉加载更多时调用
   *
   * 特点：
   * - 智能分页：自动计算下一页
   * - 数据合并：与现有列表合并
   * - 去重处理：防止重复数据
   */
  private async loadMoreArticles() {
    await this.loadArticlesByCid(this.selectedCid, false);
  }

  /**
   * 刷新收藏状态
   * 获取当前用户的收藏列表并更新本地状态
   *
   * 逻辑流程：
   * 1. 获取当前用户ID
   * 2. 如果是未登录用户，清空收藏状态
   * 3. 如果是登录用户，加载收藏列表
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
   * 头部标题动画
   * 页面显示时执行渐入动画
   *
   * 动画效果：
   * - 透明度从0到1
   * - 位置从偏移到正常
   * - 持续时间260ms，缓出曲线
   */
  private animateHeader() {
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.headerOpacity = 1;
      this.headerOffset = 0;
    });
  }

  /**
   * 更新返回顶部按钮状态
   * 根据滚动位置显示/隐藏返回顶部按钮
   *
   * 显示条件：滚动位置不在顶部（first > 0）
   * 动画效果：透明度渐变 + 缩放动画
   *
   * @param show 是否显示返回顶部按钮
   */
  private updateBackToTop(show: boolean) {
    if (this.showBackToTop === show) {
      return;  // 状态未变化，避免重复动画
    }

    this.showBackToTop = show;
    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.backTopOpacity = show ? 1 : 0;
      this.backTopScale = show ? 1 : 0.9;
    });
  }

  /**
   * 触发全局收藏版本更新
   * 修改收藏状态后通知其他页面同步更新
   *
   * 实现原理：
   * - 修改AppStorage中的fav_version
   * - 所有@StorageLink绑定的组件会自动更新
   * - 触发onFavVersionChange监听器
   */
  private async bumpFavVersion() {
    AppStorage.setOrCreate('fav_version', 0);  // 确保key存在
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);  // 版本号递增
  }

  /**
   * 收藏/取消收藏切换
   *
   * 业务逻辑：
   * 1. 验证用户登录状态
   * 2. 更新本地收藏状态
   * 3. 持久化到本地存储
   * 4. 触发全局状态同步
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
      // 取消收藏
      next.delete(article.id);
      await FavoriteStore.removeArticleSnapshot(ctx, article.id);
    } else {
      // 添加收藏
      next.add(article.id);
      await FavoriteStore.saveArticleSnapshot(ctx, article);
    }

    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);
    await this.bumpFavVersion();  // 触发全局状态同步
  }

  /**
   * 安全跳转到文章详情页
   * 包含异常处理，防止跳转失败
   *
   * 准备工作：
   * - 缓存当前文章列表供详情页使用
   * - 传递文章ID和文章对象
   *
   * @param article 要查看的文章对象
   */
  private async openDetail(article: Article) {
    try {
      // 缓存当前文章列表，供详情页使用（用于前后导航）
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
   * 页面UI构建
   * 采用Stack + Column分层布局结构
   *
   * 布局层次：
   * 1. Stack层：背景图 + 主内容 + 浮动按钮
   * 2. Column层：头部导航 + 双栏内容
   * 3. Row层：分类导航 + 文章列表
   */
  build() {
    Stack() {
      // 背景图片层
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 主内容区域
      Column() {
        // ==================== 头部标题区域（带动画效果） ====================
        Row() {
          // 返回按钮（根据路由参数显示）
          if (this.showBackButton) {
            Text('←')
              .fontSize(22)
              .onClick(() => router.back())  // 返回上一页
              .width(40)
              .fontColor('#4A5568')
          } else {
            Blank().width(40)  // 占位保持布局平衡
          }

          // 页面标题
          Text('分类')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .fontColor('#1F2937')

          Blank().width(40)  // 右侧占位保持对称
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .margin({ top: 12, left: 16, right: 16, bottom: 10 })
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .shadow({ radius: 16, color: '#1A000000', offsetX: 0, offsetY: 8 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ==================== 主体内容区域：双栏布局 ====================
        Row() {
          // 左侧：分类导航列表（宽度34%）
          Column() {
            Text('分类导航')
              .fontSize(12)
              .fontColor('#8A94A6')
              .margin({ left: 4, bottom: 6 })
            List() {
              ForEach(this.categories, (c: Category) => {
                ListItem() {
                  Row() {
                    if (this.selectedCid === c.cid) {
                      Text('')
                        .width(4)
                        .height(18)
                        .borderRadius(2)
                        .backgroundColor('#4C7DFF')
                        .margin({ right: 8 })
                    } else {
                      Blank().width(12)
                    }

                    Text(c.name)
                      .fontSize(14)
                      .fontWeight(this.selectedCid === c.cid ? FontWeight.Bold : FontWeight.Normal)
                      .layoutWeight(1)
                      .fontColor(this.selectedCid === c.cid ? '#1F2A44' : '#5B6576')
                  }
                  .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                  .width('100%')
                  .backgroundColor(this.selectedCid === c.cid ? '#EEF4FF' : '#FFFFFF')  // 选中状态高亮
                  .borderRadius(12)
                  .border({ width: 1, color: this.selectedCid === c.cid ? '#D6E4FF' : '#EEF0F3' })
                  .shadow({ radius: 8, color: '#12000000', offsetX: 0, offsetY: 3 })
                }
                .margin({ bottom: 8 })
                .width('100%')
                .onClick(async () => {
                  // 分类切换逻辑
                  if (this.selectedCid !== c.cid) {
                    this.selectedCid = c.cid;
                    this.showBackToTop = false;  // 切换分类时隐藏返回顶部按钮
                    this.articleScroller.scrollToIndex(0);  // 滚动到顶部
                    await this.loadArticlesByCid(c.cid, true);  // 加载新分类文章
                  }
                })
              }, (c: Category) => c.cid.toString())  // 唯一键生成器
            }
          }
          .width('34%')
          .padding({ left: 12, right: 6, top: 10, bottom: 10 })
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .shadow({ radius: 10, color: '#0F000000', offsetX: 0, offsetY: 4 })

          // 右侧：文章列表区域（宽度66%）
          Column() {
            // 加载状态显示
            if (this.loadingCats || this.loadingArticles) {
              Row({ space: 8 }) {
                AppLoadingProgress()
                Text('正在加载数据...').opacity(0.7)
              }
              .padding(12)
            } else if (this.errorMsg) {
              // 错误状态显示
              Column({ space: 6 }) {
                Text('网络加载失败，数据暂不可用').fontSize(13).opacity(0.7)
                Text(this.errorMsg).fontSize(12).opacity(0.6)
              }
              .padding({ left: 12, right: 12, bottom: 6, top: 6 })
            }

            // 下拉刷新容器
            Refresh({ refreshing: this.refreshing }) {
              if (this.articles.length === 0) {
                // 空状态提示
                Text('该分类暂无文章').margin(16).opacity(0.7)
              } else {
                // 文章列表
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

                        // 收藏按钮（使用手势避免与列表项点击冲突）
                        Text(this.favIds.has(item.id) ? '★' : '☆')
                          .fontSize(20)
                          .margin({ left: 8 })
                          .fontColor(this.favIds.has(item.id) ? '#FF9F1C' : '#A3A9B6')
                          .gesture(
                            TapGesture().onAction(async () => {
                              await this.toggleFav(item);
                            })
                          )
                      }
                      .padding(12)
                      .margin({ left: 6, right: 12, bottom: 12 })
                      .borderRadius(18)
                      .backgroundColor('#FFFFFF')
                      .shadow({ radius: 14, color: '#1F000000', offsetX: 0, offsetY: 6 })
                      .onClick(async () => {
                        await this.openDetail(item);  // 跳转到详情页
                      })
                    }
                  })

                  // 列表底部加载状态
                  ListItem() {
                    if (this.loadingMore) {
                      // 加载更多状态
                      Row({ space: 8 }) {
                        AppLoadingProgress()
                        Text('加载中...').fontSize(13).opacity(0.7)
                      }
                      .padding(12)
                      .justifyContent(FlexAlign.Center)
                    } else if (!this.hasMore) {
                      // 无更多数据状态
                      Text('已经到底了').fontSize(12).opacity(0.6).padding(12)
                    } else {
                      // 提示上拉加载更多
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
              // 下拉刷新回调
              await this.refreshArticles();
            })
          }
          .width('66%')
        }
        .padding({ left: 8, right: 8, bottom: 12 })
        .margin({ left: 12, right: 12, bottom: 12 })
        .borderRadius(20)
        .layoutWeight(1)  // 占据剩余空间
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面显示时执行的操作
        this.refreshFav();     // 刷新收藏状态
        this.animateHeader();  // 执行头部动画
      })

      // ==================== 返回顶部按钮（浮动在内容上方） ====================
      Button('↑')
        .backgroundColor('#FFFFFF')
        .fontColor('#444444')
        .border({ width: 1, color: '#E3E5EA', style: BorderStyle.Solid })
        .borderRadius(20)
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .position({ x: '85%', y: '92%' })  // 定位到父容器右下角
        .margin({ right: 16, bottom: 24 })  // 通过负边距调整位置
        .shadow({ radius: 10, color: '#1A000000', offsetX: 0, offsetY: 4 })
        .opacity(this.backTopOpacity)
        .scale({ x: this.backTopScale, y: this.backTopScale })
        .enabled(this.showBackToTop)  // 只在显示时启用
        .onClick(() => this.articleScroller.scrollToIndex(0))  // 滚动到顶部
    }
    .width('100%')
    .height('100%')
  }
}