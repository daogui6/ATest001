/*
 * SearchPage.ets - 搜索页面
 *
 * 功能说明：
 * - 支持关键词搜索WanAndroid文章
 * - 搜索历史记录管理（添加、删除、清空）
 * - 搜索结果展示与收藏功能
 * - 文章详情页面跳转
 * - 动画过渡效果
 * - 热搜词和推荐词展示
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
 * - 热搜词：WanService.fetchHotKeywords
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

import type { Article } from '../model/Article';
import { ArticleStore } from '../store/ArticleStore';
import { FavoriteStore } from '../store/FavoriteStore';
import { SearchHistoryStore } from '../store/SearchHistoryStore';
import { fetchHotKeywords, searchArticles } from '../service/WanService';
import { AppLoadingProgress } from '../components/AppLoadingProgress';

// ==================== 全局状态初始化 ====================

/**
 * 全局状态管理 - 用于跨页面同步
 *
 * 设计原理：
 * - AppStorage提供应用级的共享状态存储
 * - 版本号机制确保状态变化的可靠同步
 * - 其他页面通过修改版本号触发当前页面更新
 *
 * 状态说明：
 * - fav_version: 收藏版本号，收藏操作时递增，用于同步收藏状态
 * - session_version: 会话版本号，登录状态变化时递增，用于同步用户状态
 */
AppStorage.setOrCreate('fav_version', 0);     // 收藏版本号，收藏操作时递增
AppStorage.setOrCreate('session_version', 0); // 会话版本号，登录状态变化时递增

/**
 * 搜索页面组件
 *
 * 主要功能：
 * 1. 关键词搜索WanAndroid文章
 * 2. 搜索历史记录管理
 * 3. 搜索结果展示与交互
 * 4. 收藏功能集成
 * 5. 文章详情跳转
 * 6. 智能推荐和热搜词展示
 *
 * 页面状态：
 * - 初始状态：显示热搜词、推荐词、搜索历史
 * - 搜索中：显示加载提示
 * - 搜索结果：显示搜索结果列表
 * - 错误状态：显示错误信息
 * - 空结果：显示空状态提示
 *
 * 技术架构：
 * - @Entry: 标记为页面入口组件，支持路由导航
 * - @Component: 可复用的UI组件结构
 * - 响应式状态管理：数据变化自动更新UI
 * - 异步数据加载：支持远程API调用
 */
@Entry
@Component
export struct SearchPage {
  // ========== 推荐关键词 ==========

  /**
   * 热搜关键词（从API获取）
   * @State装饰器确保UI响应式更新
  * 初始值为默认热搜词，页面加载时从API更新
   */
  @State hotKeywords: string[] = ['鸿蒙', 'HarmonyOS', 'Compose', 'Kotlin', 'AI'];

  /**
   * 推荐关键词（内置）
   * 静态推荐词，不依赖外部数据源
   * 用于补充热搜词，提供更丰富的搜索建议
   */
  private recommendKeywords: string[] = ['性能优化', '动画', '架构', '网络请求', '组件化'];

  // ========== 上下文获取 ==========

  /**
   * 获取宿主UIAbility的Context
   * 为数据存储等系统能力提供稳定的上下文参数
   *
   * 技术说明：
   * - getUIContext()获取当前UI组件的上下文
   * - getHostContext()获取宿主Ability的上下文
   * - 类型断言确保类型安全
   *
   * @returns UIAbility上下文对象，用于数据持久化操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ========== 搜索相关状态 ==========

  /**
   * 搜索关键词 - 用户输入的搜索内容
   * 双向绑定到搜索输入框，实时响应用户输入
   */
  @State keyword: string = '';

  /**
   * 搜索结果列表 - 搜索API返回的文章数据
   * 包含文章标题、描述、作者等完整信息
   */
  @State results: Article[] = [];

  /**
   * 加载状态 - 是否正在执行搜索操作
   * 控制加载动画和用户交互状态
   */
  @State loading: boolean = false;

  /**
   * 错误消息 - 搜索失败时的错误信息
   * 提供友好的错误提示，帮助用户理解问题
   */
  @State errorMsg: string = '';

  /**
   * 是否已执行过搜索 - 用于控制页面内容显示
   * 区分首次进入页面和已有搜索结果的显示逻辑
   */
  @State hasSearched: boolean = false;

  /**
   * 是否正在编辑搜索词 - 用于显示推荐和历史记录
   * 用户在输入时显示推荐内容，搜索后隐藏
   */
  @State isEditing: boolean = false;

  // ========== 用户相关状态 ==========

  /**
   * 用户ID - '0'表示未登录用户
   * 用于收藏功能的权限控制和数据隔离
   */
  @State uid: string = '0';

  /**
   * 收藏的文章ID集合 - 用于显示收藏状态
   * Set数据结构确保ID唯一性，提高查找效率
   */
  @State favIds: Set<number> = new Set<number>();

  /**
   * 搜索历史记录 - 用户的历史搜索关键词
   * 按时间顺序排列，支持去重和数量限制
   */
  @State searchHistory: string[] = [];

  // ========== 动画效果状态 ==========

  /**
   * 头部动画效果 - 导航栏的淡入和滑动效果
   * 页面显示时从透明和偏移位置动画到正常状态
   */
  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;

  /**
   * 内容面板动画效果 - 搜索区域和结果的淡入效果
   * 比头部动画稍延迟，创造层次感
   */
  @State panelOpacity: number = 0;
  @State panelOffset: number = 16;

  // ========== 全局状态监听 ==========

  /**
   * 收藏版本号变化监听
   * 当其他页面修改收藏状态时自动刷新本地收藏状态
   *
   * 技术实现：
   * - @StorageLink: 绑定到AppStorage的fav_version
   * - @Watch: 监听属性变化，触发回调方法
   * - 自动同步：确保多页面间的收藏状态一致性
   *
   * 触发场景：
   * - 其他页面添加/取消收藏
   * - 收藏状态全局同步
   */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;

  /**
   * 会话版本号变化监听
   * 当用户登录状态变化时自动刷新相关数据
   *
   * 触发场景：
   * - 用户登录成功
   * - 用户退出登录
   * - 用户信息更新
   */
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // ========== 生命周期方法 ==========

  /**
   * 页面即将显示时调用
   * 初始化数据和加载资源
   *
   * 执行顺序：
   * 1. 刷新收藏状态（确保收藏状态最新）
   * 2. 加载搜索历史（显示用户历史记录）
   * 3. 加载热搜关键词（显示热门搜索）
   *
   * 设计考虑：
   * - 异步操作避免阻塞UI渲染
   * - 错误处理确保页面可用性
   * - 数据缓存提升用户体验
   */
  async aboutToAppear() {
    await this.refreshFav();          // 刷新收藏状态
    await this.loadSearchHistory();   // 加载搜索历史
    await this.loadHotKeywords();     // 加载热搜关键词
  }

  /**
   * 监听收藏版本号变化
   * 当全局收藏状态变化时自动刷新
   *
   * 业务逻辑：
   * - 重新加载用户收藏状态
   * - 更新本地收藏ID集合
   * - 刷新UI显示状态
   *
   * 触发场景：
   * - 其他页面添加/取消收藏
   * - 收藏状态全局同步
   */
  private onFavVersionChange() {
    this.refreshFav();
  }

  /**
   * 监听会话版本号变化
   * 当用户登录状态变化时自动刷新
   *
   * 刷新策略：
   * - 收藏状态：登录用户显示个人收藏，未登录用户清空
   * - 搜索历史：可能因用户切换而显示不同的历史记录
   *
   * 触发场景：
   * - 用户登录成功
   * - 用户退出登录
   */
  private onSessionVersionChange() {
    this.refreshFav();               // 刷新收藏状态
    void this.loadSearchHistory();   // 重新加载搜索历史（可能因登录状态变化）
  }

  // ========== 数据管理方法 ==========

  /**
   * 刷新收藏状态
   * 根据用户登录状态加载收藏的文章ID集合
   *
   * 逻辑流程：
   * 1. 获取当前用户ID
   * 2. 如果是未登录用户，清空收藏状态
   * 3. 如果是登录用户，加载收藏列表
   *
   * 技术实现：
   * - FavoriteStore.getUid: 获取当前登录用户ID
   * - FavoriteStore.loadFavSet: 加载用户收藏集合
   * - Set数据结构: 高效的状态管理和查找
   */
  private async refreshFav() {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);
    this.uid = uid;

    // 未登录用户处理：清空收藏状态
    if (uid === '0') {
      this.favIds = new Set<number>();
      return;
    }

    // 登录用户：加载个人收藏集合
    this.favIds = await FavoriteStore.loadFavSet(ctx, uid);
  }

  /**
   * 加载搜索历史记录
   * 从本地存储中读取用户的搜索历史
   *
   * 存储策略：
   * - 按时间顺序排列，最新搜索在前
   * - 自动去重，避免重复记录
   * - 数量限制，防止历史记录过多
   */
  private async loadSearchHistory() {
    this.searchHistory = await SearchHistoryStore.load(this.hostCtx());
  }

  /**
   * 加载热搜关键词
   * 从远程API获取当前热门搜索关键词
   *
   * 异常处理：
   * - API失败时使用默认热搜词
   * - 显示友好的错误提示但不阻塞页面
   *
   * 用户体验：
   * - 快速显示默认词，异步更新API数据
   * - 失败时降级处理，确保页面可用性
   */
  private async loadHotKeywords() {
    try {
      const keywords = await fetchHotKeywords();
      if (keywords.length > 0) {
        this.hotKeywords = keywords;  // 使用API返回的热搜词
      }
    } catch (e) {
      // API失败时使用默认热搜词，并显示错误提示
      promptAction.showToast({ message: (e as Error)?.message ?? '热词加载失败' });
    }
  }

  /**
   * 保存搜索关键词到历史记录
   *
   * 保存策略：
   * - 自动去重（SearchHistoryStore内部处理）
   * - 按时间顺序排列（最新搜索在前）
   * - 限制历史记录数量（防止存储过多）
   *
   * @param keyword 要保存的搜索关键词
   */
  private async saveSearchKeyword(keyword: string) {
    await SearchHistoryStore.addKeyword(this.hostCtx(), keyword);
    await this.loadSearchHistory();  // 重新加载更新后的历史记录
  }

  /**
   * 从历史记录中删除特定关键词
   *
   * 删除逻辑：
   * - 精确匹配关键词
   * - 立即更新UI状态
   * - 持久化到本地存储
   *
   * @param keyword 要删除的搜索关键词
   */
  private async removeSearchKeyword(keyword: string) {
    await SearchHistoryStore.removeKeyword(this.hostCtx(), keyword);
    await this.loadSearchHistory();  // 重新加载更新后的历史记录
  }

  /**
   * 清空所有搜索历史记录
   *
   * 安全考虑：
   * - 清空操作不可恢复，需要在UI层面提供确认
   * - 立即更新UI状态，提供即时反馈
   *
   * 注意：清空操作不可恢复，需要用户确认（在UI层面）
   */
  private async clearSearchHistory() {
    await SearchHistoryStore.clear(this.hostCtx());
    this.searchHistory = [];  // 立即更新UI状态
  }

  /**
   * 快捷应用关键词（热搜/推荐/历史点击）
   * 将关键词填入搜索框并立即执行搜索
   *
   * 用户体验优化：
   * - 一键搜索，减少用户操作步骤
   * - 自动填入搜索框，方便修改
   * - 立即执行搜索，提供即时结果
   *
   * @param keyword 要应用的搜索关键词
   */
  private async applyKeyword(keyword: string) {
    this.keyword = keyword;        // 填入搜索框
    await this.performSearch();    // 立即执行搜索
  }

  // ========== 搜索功能方法 ==========

  /**
   * 执行搜索操作
   * 包括关键词验证、历史记录保存、API调用和结果处理
   *
   * 执行流程：
   * 1. 关键词验证和清理（去除前后空格）
   * 2. 保存到搜索历史（无论搜索成功与否）
   * 3. 设置搜索状态（加载中、错误清空）
   * 4. 调用远程API获取搜索结果
   * 5. 处理搜索结果（成功/失败）
   * 6. 错误处理和状态清理（finally块）
   *
   * 异常处理：
   * - 网络异常：显示友好的错误提示
   * - API错误：保留错误信息供用户查看
   * - 最终状态：确保加载状态正确清理
   */
  private async performSearch() {
    const kw = this.keyword.trim();  // 清理关键词前后空格

    // 关键词验证：空关键词提示用户
    if (kw.length === 0) {
      promptAction.showToast({ message: '请输入关键词' });
      return;
    }

    // 保存搜索历史（无论搜索成功与否，记录用户意图）
    await this.saveSearchKeyword(kw);

    // 设置搜索状态：开始加载，清空错误，标记已搜索
    this.loading = true;
    this.errorMsg = '';
    this.hasSearched = true;
    this.isEditing = false;  // 搜索执行后退出编辑状态

    try {
      // 调用远程搜索API：WanAndroid文章搜索
      const list = await searchArticles(kw);
      this.results = list;
    } catch (e) {
      // 错误处理：显示具体错误信息，清空搜索结果
      this.errorMsg = (e as Error)?.message ?? '搜索失败';
      this.results = [];  // 清空搜索结果
    } finally {
      // 清理加载状态：无论成功失败都要结束加载
      this.loading = false;
    }
  }

  // ========== 构建工具方法 ==========

  /**
   * 构建关键词标签组
   * 用于显示热搜词、推荐词等关键词列表
   *
   * UI设计：
   * - 弹性布局：自动换行，适应不同屏幕宽度
   * - 圆角标签：友好的视觉样式
   * - 点击交互：一键搜索关键词
   *
   * @param title 标签组标题（如"热搜词"、"推荐词"）
   * @param keywords 关键词数组
   * @returns 关键词标签组UI组件
   *
   * @Builder 装饰器：创建可复用的UI构建块
   */
  @Builder
  private buildKeywordChips(title: string, keywords: string[]) {
    Column({ space: 8 }) {
      // 标题区域：分类标识
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .padding({ left: 16, right: 16 })

      // 关键词标签区域（弹性布局，自动换行）
      Flex({
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.Start,
        alignItems: ItemAlign.Center
      }) {
        ForEach(keywords, (item: string) => {
          Text(item)
            .fontSize(12)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .margin({ right: 8, bottom: 8 })
            .backgroundColor('#F1F5F9')  // 浅灰色背景
            .borderRadius(14)           // 圆角效果
            .onClick(async () => {
              await this.applyKeyword(item);  // 点击关键词快速搜索
            })
        }, (item: string) => item)  // 使用关键词本身作为唯一键
      }
      .padding({ left: 16, right: 16 })
    }
  }

  // ========== 收藏功能方法 ==========

  /**
   * 触发全局收藏版本号更新
   * 用于通知其他页面刷新收藏状态
   *
   * 实现原理：
   * - 修改AppStorage中的fav_version
   * - 所有@StorageLink绑定的组件会自动更新
   * - 触发onFavVersionChange监听器
   *
   * 使用场景：
   * - 添加收藏后同步其他页面
   * - 取消收藏后更新全局状态
   * - 确保多页面间收藏状态一致性
   */
  private async bumpFavVersion() {
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);  // 版本号递增
  }

  /**
   * 切换文章收藏状态
   *
   * 业务逻辑：
   * 1. 验证用户登录状态（未登录提示登录）
   * 2. 更新本地收藏状态（Set数据结构）
   * 3. 持久化到本地存储（FavoriteStore）
   * 4. 触发全局状态同步（bumpFavVersion）
   *
   * 技术实现：
   * - Set操作：add添加，delete删除
   * - 数据持久化：保存到本地数据库
   * - 状态同步：通知其他页面更新
   *
   * @param article 要操作的文章对象
   */
  private async toggleFav(article: Article) {
    const ctx = this.hostCtx();
    const uid = await FavoriteStore.getUid(ctx);

    // 登录状态验证：未登录用户提示登录
    if (uid === '0') {
      promptAction.showToast({ message: '请先在【我的】里登录' });
      return;
    }

    // 更新本地收藏状态：使用Set确保唯一性
    const next = new Set(this.favIds);
    if (next.has(article.id)) {
      // 取消收藏：从集合中删除，移除持久化数据
      next.delete(article.id);
      await FavoriteStore.removeArticleSnapshot(ctx, article.id);
    } else {
      // 添加收藏：添加到集合，保存文章快照
      next.add(article.id);
      await FavoriteStore.saveArticleSnapshot(ctx, article);
    }

    // 更新状态和持久化存储
    this.favIds = next;
    await FavoriteStore.saveFavSet(ctx, uid, next);
    await this.bumpFavVersion();  // 触发全局状态同步
  }

  // ========== 页面跳转方法 ==========

  /**
   * 打开文章详情页面
   *
   * 准备工作：
   * - 缓存当前文章列表供详情页使用（用于前后导航）
   * - 传递文章ID和完整文章对象
   *
   * 导航策略：
   * - pushUrl: 推入新页面，支持返回
   * - 参数传递：文章ID和完整对象
   * - 异常处理：跳转失败友好提示
   *
   * @param article 要查看的文章对象
   */
  private async openDetail(article: Article) {
    try {
      // 设置文章列表供详情页使用（用于前后导航）
      ArticleStore.setArticles(this.results);

      // 跳转到详情页，传递必要的参数
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      // 跳转失败时的友好提示
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  // ========== 页面构建方法 ==========

  /**
   * 构建搜索页面UI
   * 根据不同的状态显示相应的内容区域
   *
   * 布局层次：
   * 1. Stack层：背景图 + 主内容（层级叠加）
   * 2. Column层：头部导航 + 搜索区域 + 内容区域（垂直排列）
   * 3. 条件渲染：根据状态显示不同内容（智能显示）
   *
   * 状态控制逻辑：
   * - hasSearched: 是否执行过搜索（控制推荐/结果显示）
   * - isEditing: 是否正在编辑（控制历史记录显示）
   * - loading: 是否加载中（显示加载提示）
   * - errorMsg: 是否有错误（显示错误信息）
   * - results.length: 搜索结果数量（控制空状态）
   */
  build() {
    Stack() {
      // 背景图片层：全屏背景增强视觉体验
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 主内容区域：包含所有交互元素
      Column() {
        // ========== 头部导航栏 ==========
        Row() {
          // 返回按钮：提供页面导航功能
          Text('←')
            .fontSize(22)
            .onClick(() => router.back())  // 返回上一页
            .width(40)

          // 页面标题：居中显示，突出页面功能
          Text('搜索')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 右侧占位（保持对称布局）
          Blank().width(40)
        }
        .width('100%')
        .padding({ top: 16, left: 16, right: 16, bottom: 12 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ========== 搜索输入区域 ==========
        Row({ space: 8 }) {
          // 搜索输入框区域：包含图标和输入框
          Row({ space: 8 }) {
            // 搜索图标：视觉提示
            Text('🔍').fontSize(16).opacity(0.6)

            // 搜索输入框：主要交互元素
            TextInput({ placeholder: '输入关键词', text: this.keyword })
              .layoutWeight(1)  // 弹性占据剩余空间
              .onChange((v) => {
                this.keyword = v;
                this.isEditing = true; // 标记为编辑状态（显示推荐和历史）
              })
          }
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })

          // 搜索按钮：触发搜索操作
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

        // ========== 热搜词/推荐词（编辑状态或未搜索时显示） ==========
        if (!this.hasSearched || this.isEditing) {
          this.buildKeywordChips('热搜词', this.hotKeywords);
          this.buildKeywordChips('推荐词', this.recommendKeywords);
        }

        // ========== 搜索历史记录区域 ==========
        if (this.searchHistory.length > 0 && (this.isEditing || !this.hasSearched)) {
          Column({ space: 8 }) {
            // 历史记录标题和清空按钮区域
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

            // 操作提示：用户引导信息
            Text('提示：点击关键词快速搜索，右侧可删除单条，清空后不可恢复。')
              .fontSize(11)
              .opacity(0.55)
              .padding({ left: 16, right: 16, bottom: 8 })
              .opacity(this.panelOpacity)
              .translate({ x: 0, y: this.panelOffset })

            // 历史记录列表：可点击搜索和删除
            Column({ space: 6 }) {
              ForEach(this.searchHistory, (item: string) => {
                Row({ space: 8 }) {
                  // 历史关键词（可点击搜索）
                  Text(item)
                    .layoutWeight(1)
                    .fontSize(13)
                    .onClick(async () => {
                      await this.applyKeyword(item);  // 点击关键词快速搜索
                    })

                  // 删除按钮（使用手势避免与列表项点击冲突）
                  Text('删除')
                    .fontSize(12)
                    .opacity(0.6)
                    .gesture(
                      TapGesture().onAction(async () => {
                        await this.removeSearchKeyword(item);  // 删除单条历史记录
                      })
                    )
                }
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: '#E9EEF5' })
                .margin({ left: 16, right: 16 })
              }, (item: string) => item)  // 使用关键词作为唯一键
            }
          }
          .padding({ bottom: 12 })
          .opacity(this.panelOpacity)
          .translate({ x: 0, y: this.panelOffset })
          .margin({ top: 20 })
        }
        // ========== 空历史记录提示 ==========
        else if (this.searchHistory.length === 0 && (this.isEditing || !this.hasSearched)) {
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
            AppLoadingProgress()  // 加载动画组件
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
                // 文章信息区域：标题、描述、作者
                Column({ space: 6 }) {
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                  Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                  Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                }
                .layoutWeight(1)  // 占据剩余空间

                // 收藏按钮（星标）- 使用手势避免与列表项点击冲突
                Text(this.favIds.has(item.id) ? '★' : '☆')
                  .fontSize(22)
                  .margin({ left: 10 })
                  .gesture(
                    TapGesture().onAction(async () => {
                      await this.toggleFav(item);  // 切换收藏状态
                    })
                  )
              }
              .padding(12)
              .margin({ left: 16, right: 16, bottom: 12 })
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => {
                await this.openDetail(item);  // 跳转到文章详情
              })
            }
          }, (item: Article) => item.id.toString())  // 使用文章ID作为唯一键
        }
        .width('100%')
        .layoutWeight(1)  // 占据剩余垂直空间
        .opacity(this.panelOpacity)
        .translate({ x: 0, y: this.panelOffset })
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面进入动画效果：创造流畅的视觉体验
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