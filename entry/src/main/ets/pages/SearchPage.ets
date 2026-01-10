/*
 * SearchPage.ets - 搜索页面
 *
 * 功能说明：
 * - 支持关键词搜索WanAndroid文章
 * - 搜索历史记录管理（添加、删除、清空）
 * - 搜索结果展示与收藏功能
 * - 文章详情页面跳转
 * - 动画过渡效果
 *
 * 页面架构：
 * - 头部导航栏（返回按钮 + 页面标题）
 * - 搜索输入区域（搜索框 + 搜索按钮）
 * - 搜索历史记录区域
 * - 搜索结果列表区域
 * - 状态提示区域（加载中、错误、空结果）
 *
 * 状态管理：
 * - @State: 管理组件内部状态
 * - @StorageLink: 跨页面状态同步（收藏状态、会话状态）
 * - @Watch: 监听状态变化
 *
 * 数据流：
 * - 本地搜索历史：SearchHistoryStore
 * - 远程搜索API：WanService.searchArticles
 * - 收藏管理：FavoriteStore
 * - 文章数据：ArticleStore
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { ArticleStore } from '../store/ArticleStore';
import { FavoriteStore } from '../store/FavoriteStore';
import { SearchHistoryStore } from '../store/SearchHistoryStore';
import { searchArticles } from '../service/WanService';
import { AppLoadingProgress } from '../components/AppLoadingProgress';

// 全局状态管理 - 用于跨页面同步
AppStorage.setOrCreate('fav_version', 0);     // 收藏版本号
AppStorage.setOrCreate('session_version', 0); // 会话版本号

/**
 * 搜索页面组件
 *
 * 主要功能：
 * 1. 关键词搜索WanAndroid文章
 * 2. 搜索历史记录管理
 * 3. 搜索结果展示与交互
 * 4. 收藏功能集成
 * 5. 文章详情跳转
 */
@Entry
@Component
export struct SearchPage {
  // ========== 推荐关键词 ==========
  private hotKeywords: string[] = ['鸿蒙', 'HarmonyOS', 'Compose', 'Kotlin', 'AI'];
  private recommendKeywords: string[] = ['性能优化', '动画', '架构', '网络请求', '组件化'];

  // ========== 上下文获取 ==========

  /**
   * 获取宿主UIAbility的Context
   * 为数据存储等系统能力提供稳定的上下文参数
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ========== 搜索相关状态 ==========

  /** 搜索关键词 */
  @State keyword: string = '';

  /** 搜索结果列表 */
  @State results: Article[] = [];

  /** 加载状态 */
  @State loading: boolean = false;

  /** 错误消息 */
  @State errorMsg: string = '';

  /** 是否已执行过搜索 */
  @State hasSearched: boolean = false;

  /** 是否正在编辑搜索词 */
  @State isEditing: boolean = false;

  // ========== 用户相关状态 ==========

  /** 用户ID */
  @State uid: string = '0';

  /** 收藏的文章ID集合 */
  @State favIds: Set<number> = new Set<number>();

  /** 搜索历史记录 */
  @State searchHistory: string[] = [];

  // ========== 动画效果状态 ==========

  /** 头部动画效果 */
  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;

  /** 内容面板动画效果 */
  @State panelOpacity: number = 0;
  @State panelOffset: number = 16;

  // ========== 全局状态监听 ==========

  /** 收藏版本号变化监听 */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;

  /** 会话版本号变化监听 */
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // ========== 生命周期方法 ==========

  /**
   * 页面即将显示时调用
   * 初始化数据和加载资源
   */
  async aboutToAppear() {
    await this.refreshFav();          // 刷新收藏状态
    await this.loadSearchHistory();   // 加载搜索历史
  }

  /**
   * 监听收藏版本号变化
   * 当全局收藏状态变化时自动刷新
   */
  private onFavVersionChange() {
    this.refreshFav();
  }

  /**
   * 监听会话版本号变化
   * 当用户登录状态变化时自动刷新
   */
  private onSessionVersionChange() {
    this.refreshFav();
  }

  // ========== 数据管理方法 ==========

  /**
   * 刷新收藏状态
   * 根据用户登录状态加载收藏的文章ID集合
   */
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

  /**
   * 加载搜索历史记录
   */
  private async loadSearchHistory() {
    this.searchHistory = await SearchHistoryStore.load(this.hostCtx());
  }

  /**
   * 保存搜索关键词到历史记录
   *
   * @param keyword 要保存的搜索关键词
   */
  private async saveSearchKeyword(keyword: string) {
    await SearchHistoryStore.addKeyword(this.hostCtx(), keyword);
    await this.loadSearchHistory();
  }

  /**
   * 从历史记录中删除特定关键词
   *
   * @param keyword 要删除的搜索关键词
   */
  private async removeSearchKeyword(keyword: string) {
    await SearchHistoryStore.removeKeyword(this.hostCtx(), keyword);
    await this.loadSearchHistory();
  }

  /**
   * 清空所有搜索历史记录
   */
  private async clearSearchHistory() {
    await SearchHistoryStore.clear(this.hostCtx());
    this.searchHistory = [];
  }

  /**
   * 快捷应用关键词（热搜/推荐/历史点击）
   */
  private async applyKeyword(keyword: string) {
    this.keyword = keyword;
    await this.performSearch();
  }

  // ========== 搜索功能方法 ==========

  /**
   * 执行搜索操作
   * 包括关键词验证、历史记录保存、API调用和结果处理
   */
  private async performSearch() {
    const kw = this.keyword.trim();

    // 关键词验证
    if (kw.length === 0) {
      promptAction.showToast({ message: '请输入关键词' });
      return;
    }

    // 保存搜索历史
    await this.saveSearchKeyword(kw);

    // 设置搜索状态
    this.loading = true;
    this.errorMsg = '';
    this.hasSearched = true;
    this.isEditing = false;

    try {
      // 调用远程搜索API
      const list = await searchArticles(kw);
      this.results = list;
    } catch (e) {
      // 错误处理
      this.errorMsg = (e as Error)?.message ?? '搜索失败';
      this.results = [];
    } finally {
      // 清理加载状态
      this.loading = false;
    }
  }

  // ========== 构建工具方法 ==========

  /**
   * 构建关键词标签组
   */
  @Builder
  private buildKeywordChips(title: string, keywords: string[]) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 16, right: 16 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, alignItems: ItemAlign.Center }) {
        ForEach(keywords, (item: string) => {
          Text(item)
            .fontSize(12)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .margin({ right: 8, bottom: 8 })
            .backgroundColor('#F1F5F9')
            .borderRadius(14)
            .onClick(async () => {
              await this.applyKeyword(item);
            })
        }, (item: string) => item)
      }
      .padding({ left: 16, right: 16 })
    }
  }

  // ========== 收藏功能方法 ==========

  /**
   * 触发全局收藏版本号更新
   * 用于通知其他页面刷新收藏状态
   */
  private async bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  /**
   * 切换文章收藏状态
   *
   * @param article 要操作的文章对象
   */
  private async toggleFav(article: Article) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);

    // 登录状态验证
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

    // 更新状态和持久化存储
    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);
    await this.bumpFavVersion();
  }

  // ========== 页面跳转方法 ==========

  /**
   * 打开文章详情页面
   *
   * @param article 要查看的文章对象
   */
  private async openDetail(article: Article) {
    try {
      // 设置文章列表供详情页使用
      ArticleStore.setArticles(this.results);

      // 跳转到详情页
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  // ========== 页面构建方法 ==========

  /**
   * 构建搜索页面UI
   * 根据不同的状态显示相应的内容区域
   */
  build() {
    Stack() {
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column() {
        // ========== 头部导航栏 ==========
        Row() {
          // 返回按钮
          Text('←')
            .fontSize(22)
            .onClick(() => router.back())
            .width(40)

          // 页面标题
          Text('搜索')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 右侧占位（保持对称）
          Blank().width(40)
        }
        .width('100%')
        .padding({ top: 16, left: 16, right: 16, bottom: 12 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ========== 搜索输入区域 ==========
        Row({ space: 8 }) {
          Row({ space: 8 }) {
            // 搜索图标
            Text('🔍').fontSize(16).opacity(0.6)

            // 搜索输入框
            TextInput({ placeholder: '输入关键词', text: this.keyword })
              .layoutWeight(1)
              .onChange((v) => {
                this.keyword = v;
                this.isEditing = true; // 标记为编辑状态
              })
          }
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })

          // 搜索按钮
          Button('搜索', { type: ButtonType.Capsule })
            .onClick(async () => await this.performSearch())
        }
        .padding({ left: 16, right: 16, bottom: 12 })
        .opacity(this.panelOpacity)
        .translate({ x: 0, y: this.panelOffset })

        // ========== 提示语（搜索前） ==========
        if (!this.hasSearched) {
          Text('支持远端搜索 WanAndroid 文章，试试输入"鸿蒙"或"AI"。')
            .fontSize(13)
            .opacity(0.7)
            .margin({ left: 16, right: 16, bottom: 8 })
            .opacity(this.panelOpacity)
            .translate({ x: 0, y: this.panelOffset })
        }

        // ========== 热搜词/推荐词 ==========
        if (!this.hasSearched || this.isEditing) {
          this.buildKeywordChips('热搜词', this.hotKeywords);
          this.buildKeywordChips('推荐词', this.recommendKeywords);
        }

        // ========== 搜索历史记录区域 ==========
        if (this.searchHistory.length > 0 && (this.isEditing || !this.hasSearched)) {
          Column({ space: 8 }) {
            // 历史记录标题和清空按钮
            Row() {
              Text('搜索记录')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
              Text('清空')
                .fontSize(12)
                .opacity(0.6)
                .onClick(async () => await this.clearSearchHistory())
            }
            .padding({ left: 16, right: 16 })


            Text('提示：点击关键词快速搜索，右侧可删除单条，清空后不可恢复。')
              .fontSize(11)
              .opacity(0.55)
              .padding({ left: 16, right: 16, bottom: 8 })
              .opacity(this.panelOpacity)
              .translate({ x: 0, y: this.panelOffset })

            // 历史记录列表
            Column({ space: 6 }) {
              ForEach(this.searchHistory, (item: string) => {
                Row({ space: 8 }) {
                  // 历史关键词（可点击搜索）
                  Text(item)
                    .layoutWeight(1)
                    .fontSize(13)
                    .onClick(async () => {
                      await this.applyKeyword(item);
                    })

                  // 删除按钮
                  Text('删除')
                    .fontSize(12)
                    .opacity(0.6)
                    .gesture(
                      TapGesture().onAction(async () => {
                        await this.removeSearchKeyword(item);
                      })
                    )
                }
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E9EEF5' })
                .margin({ left: 16, right: 16 })
              }, (item: string) => item)
            }
          }
          .padding({ bottom: 12 })
          .opacity(this.panelOpacity)
          .translate({ x: 0, y: this.panelOffset })
          .margin({ top: 20 })
        } else if (this.searchHistory.length === 0 && (this.isEditing || !this.hasSearched)) {
          Column({ space: 6 }) {
            Text('暂无搜索记录')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 16, right: 16, bottom: 12 })
          .opacity(this.panelOpacity)
          .translate({ x: 0, y: this.panelOffset })
        }

        // ========== 加载状态提示 ==========
        if (this.loading) {
          Row({ space: 8 }) {
            AppLoadingProgress()
            Text('正在搜索...').opacity(0.7)
          }
          .padding(16)
          .opacity(this.panelOpacity)
          .translate({ x: 0, y: this.panelOffset })
        }
        // ========== 错误状态提示 ==========
        else if (this.errorMsg) {
          Column({ space: 6 }) {
            Text('搜索失败，请稍后重试').fontSize(13).opacity(0.7)
            Text(this.errorMsg).fontSize(12).opacity(0.6)
          }
          .padding({ left: 16, right: 16, bottom: 6 })
          .opacity(this.panelOpacity)
          .translate({ x: 0, y: this.panelOffset })
        }
        // ========== 空结果提示 ==========
        else if (this.hasSearched && this.results.length === 0) {
          Column({ space: 6 }) {
            Text('未找到相关内容').fontSize(13).opacity(0.8)
            Text('可以尝试更短的关键词，或点击上方热搜词快速搜索。')
              .fontSize(12)
              .opacity(0.6)
          }
          .margin({ left: 16, right: 16, bottom: 8 })
          .opacity(this.panelOpacity)
          .translate({ x: 0, y: this.panelOffset })
        }

        // ========== 搜索结果列表 ==========
        List() {
          ForEach(this.results, (item: Article) => {
            ListItem() {
              Row() {
                // 文章信息区域
                Column({ space: 6 }) {
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                  Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                  Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                }
                .layoutWeight(1)

                // 收藏按钮（星标）
                Text(this.favIds.has(item.id) ? '★' : '☆')
                  .fontSize(22)
                  .margin({ left: 10 })
                  .gesture(
                    TapGesture().onAction(async () => {
                      await this.toggleFav(item);
                    })
                  )
              }
              .padding(12)
              .margin({ left: 16, right: 16, bottom: 12 })
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => { await this.openDetail(item); })
            }
          }, (item: Article) => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .opacity(this.panelOpacity)
        .translate({ x: 0, y: this.panelOffset })
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面进入动画效果
        animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.headerOpacity = 1;
          this.headerOffset = 0;
        });
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.panelOpacity = 1;
          this.panelOffset = 0;
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}