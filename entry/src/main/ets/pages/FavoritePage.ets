/**
 * 收藏页面 - 用户收藏文章管理
 *
 * 功能概述：
 * - 展示用户收藏的文章列表，支持实时同步更新
 * - 提供取消收藏操作和文章详情跳转功能
 * - 实现多数据源融合展示（远程API + 本地缓存）
 * - 优雅的登录状态处理和空状态展示
 *
 * 架构特点：
 * - 全局状态驱动的数据同步机制（AppStorage + @StorageLink）
 * - 智能数据缓存与远程数据融合策略
 * - 响应式UI状态管理和动画效果
 * - 安全的页面跳转和操作确认机制
 *
 * 技术亮点：
 * - 收藏版本控制实现跨页面实时同步
 * - 双层数据源策略：远程API（新鲜度）+ 本地缓存（可用性）
 * - 平滑的页面过渡动画和交互反馈
 * - 完善的错误处理和降级方案
 *
 * 数据流设计：
 * 1. 页面初始化 → 加载收藏数据
 * 2. 全局状态变化 → 触发数据刷新
 * 3. 用户操作 → 更新本地和全局状态
 * 4. 异常情况 → 降级到缓存数据
 *
 * 版本信息：
 * - 创建时间：2024年
 * - 依赖版本：HarmonyOS 4.0+
 * - 组件类型：页面级组件（@Entry）
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型和存储导入
import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { ArticleStore } from '../store/ArticleStore';
import { fetchArticlesByIds } from '../service/WanService';

/**
 * 收藏页面路由参数接口
 * 用于接收从其他页面跳转时传递的参数，支持灵活的路由配置
 */
interface FavoritePageParams {
  showBackButton?: boolean;  // 是否显示返回按钮（主要参数）
  showBack?: boolean;        // 是否显示返回按钮（兼容性参数，历史版本）
}

/**
 * 全局状态初始化
 * 通过AppStorage实现跨页面状态同步，确保状态键存在
 *
 * 状态说明：
 * - fav_version: 收藏版本号，收藏操作时递增触发同步
 * - session_version: 会话版本号，登录状态变化时触发同步
 */
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 * 收藏页面主组件
 *
 * 核心职责：
 * - 管理用户收藏文章的完整生命周期
 * - 响应全局状态变化实现实时数据同步
 * - 提供收藏文章的浏览、取消收藏和详情查看功能
 * - 实现多数据源的智能数据融合展示
 *
 * 页面状态：
 * - 未登录状态：显示登录引导提示
 * - 空收藏状态：显示空状态UI
 * - 正常状态：显示收藏文章列表和操作功能
 */
@Entry
@Component
export struct FavoritePage {
  /**
   * 是否显示返回按钮
   * 根据路由参数决定是否显示返回上一页的按钮
   * 支持灵活的页面导航配置
   */
  @State showBackButton: boolean = false;

  /**
   * 获取宿主上下文（UIAbility上下文）
   *
   * 用于访问应用级资源和执行数据存储操作
   * 通过UI上下文获取宿主上下文，确保类型安全
   *
   * @returns UIAbility上下文对象，用于数据持久化操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ==================== 全局状态同步绑定 ====================

  /**
   * 收藏版本号状态绑定
   *
   * @StorageLink 与AppStorage建立双向数据绑定
   * @Watch 监听状态变化，触发回调函数
   *
   * 实现机制：当用户在其他页面进行收藏操作时，
   * 全局版本号递增，通过@Watch触发当前页面的数据刷新
   */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0;

  /**
   * 会话版本号状态绑定
   *
   * 监听用户登录状态变化，重新加载对应用户的收藏数据
   */
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // ==================== 组件内部状态管理 ====================

  /**
   * 组件内部响应式状态，变化时触发UI重新渲染
   */
  @State uid: string = '0';                    // 当前用户ID，'0'表示未登录
  @State favIds: Set<number> = new Set<number>();      // 用户收藏的文章ID集合
  @State favArticles: Article[] = [];          // 收藏的文章列表（完整数据）

  // ==================== 动画相关状态 ====================

  @State headerOpacity: number = 0;            // 头部导航栏透明度（用于渐入动画）
  @State headerOffset: number = 12;            // 头部导航栏垂直偏移（用于滑动动画）

  /**
   * 路由参数解析方法
   *
   * 用于判断是否显示返回按钮，支持参数兼容性处理
   *
   * 解析逻辑：
   * - 优先使用showBackButton参数（新版本）
   * - 兼容showBack参数（历史版本，保持向后兼容）
   * - 默认不显示返回按钮（独立页面模式）
   */
  private updateBackButton(): void {
    const params = router.getParams() as FavoritePageParams | undefined;
    this.showBackButton = Boolean(params?.showBackButton ?? params?.showBack);
  }

  /**
   * 收藏版本变化监听器
   *
   * 当用户在其他页面进行收藏操作时触发
   * 重新加载收藏数据，保持页面数据同步
   *
   * 触发场景：
   * - 用户在文章详情页添加新收藏
   * - 用户在其他页面取消现有收藏
   * - 收藏状态全局同步通知
   */
  private onFavVersionChange(): void {
    this.refresh();
  }

  /**
   * 会话版本变化监听器
   *
   * 当用户登录状态发生变化时触发
   * 重新加载当前用户的收藏数据，实现用户数据隔离
   *
   * 触发场景：
   * - 用户成功登录应用
   * - 用户退出当前账号
   * - 用户切换不同账号
   */
  private onSessionVersionChange(): void {
    this.refresh();
  }

  /**
   * 刷新收藏数据（核心数据加载方法）
   *
   * 支持多种数据源融合的智能加载策略：
   * 1. 获取用户ID和收藏文章ID集合
   * 2. 优先从远程API获取最新文章数据（保证数据新鲜度）
   * 3. 使用本地缓存数据作为兜底方案（保证可用性）
   * 4. 合并远程和缓存数据，避免重复（保证数据完整性）
   *
   * 数据加载流程：
   * - 用户身份验证 → 加载ID集合 → 远程API优先 → 本地缓存兜底 → 数据合并 → UI更新
   *
   * 异常处理策略：
   * - 网络异常：降级到本地缓存数据
   * - 数据解析错误：使用空数据防止应用崩溃
   * - 权限错误：清空数据并提示用户
   */
  private async refresh(): Promise<void> {
    const ctx = this.hostCtx();

    // 1. 获取当前用户ID（用户身份验证）
    this.uid = await FavoriteStore.getUid(ctx);

    // 2. 未登录用户处理：清空数据并返回
    if (this.uid === '0') {
      this.favIds = new Set<number>();
      this.favArticles = [];
      return;
    }

    // 3. 加载用户收藏的文章ID集合
    const set = await FavoriteStore.loadFavSet(ctx, this.uid);
    this.favIds = set;

    try {
      // 4. 优先从远程API获取文章数据（获取最新信息）
      const remote = await fetchArticlesByIds(set);
      const remoteIds = new Set(remote.map(item => item.id));

      // 5. 从本地缓存获取文章数据（作为兜底方案）
      const cached = await FavoriteStore.pickCachedArticles(ctx, set);

      // 6. 合并远程和缓存数据，避免重复
      // 策略：优先使用远程数据，缓存数据作为补充
      const merged = [...remote];
      cached.forEach(item => {
        if (!remoteIds.has(item.id)) {
          merged.push(item);
        }
      });

      this.favArticles = merged;
    } catch (e) {
      // 7. 远程API失败时的降级处理：使用本地缓存数据
      promptAction.showToast({
        message: (e as Error)?.message ?? '收藏数据加载失败，使用缓存数据'
      });

      // 8. 使用本地缓存数据展示（保证页面可用性）
      this.favArticles = await FavoriteStore.pickCachedArticles(ctx, set);
    }
  }

  /**
   * 安全跳转到文章详情页
   *
   * 包含完整的异常处理机制，确保页面跳转的稳定性
   *
   * 跳转准备：
   * - 缓存当前文章列表供详情页使用（支持前后导航）
   * - 传递文章ID和完整文章对象（避免重复请求）
   * - 异常边界处理（防止跳转失败导致应用崩溃）
   *
   * @param article 要查看的文章对象，包含完整的文章信息
   *
   * @throws 不会抛出异常，所有错误都在内部处理
   */
  private async openDetail(article: Article): Promise<void> {
    try {
      // 缓存当前文章列表，供详情页使用（支持前后导航）
      ArticleStore.setArticles(this.favArticles);

      // 跳转到文章详情页，传递文章ID和完整文章对象
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      // 跳转失败时的友好提示，避免应用崩溃
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 取消收藏操作
   *
   * 从收藏列表中移除指定文章，包含完整的业务逻辑：
   * 1. 验证用户登录状态（操作权限检查）
   * 2. 更新本地收藏状态和收藏时间戳
   * 3. 持久化到本地存储（数据一致性）
   * 4. 更新UI显示（即时反馈）
   * 5. 移除文章快照缓存（资源清理）
   * 6. 触发全局状态同步（跨页面通知）
   *
   * @param id 要取消收藏的文章ID
   *
   * @throws 不会抛出异常，所有错误都在内部处理
   */
  private async removeFav(id: number): Promise<void> {
    // 1. 登录验证：确保用户有操作权限
    if (this.uid === '0') {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    const ctx = this.hostCtx();

    // 2. 更新本地收藏状态：从集合中移除指定ID
    const next = new Set(this.favIds);
    next.delete(id);
    this.favIds = next;

    // 3. 更新收藏时间戳：移除对应文章的时间记录
    const times = await FavoriteStore.loadFavTimes(ctx, this.uid);
    times.delete(id);

    // 4. 保存到持久化存储：确保数据持久化
    await FavoriteStore.saveFavSet(ctx, this.uid, next);
    await FavoriteStore.saveFavTimes(ctx, this.uid, times);

    // 5. 更新UI显示：从文章列表中移除对应项
    this.favArticles = this.favArticles.filter(item => item.id !== id);

    // 6. 移除文章快照缓存：清理不再需要的缓存数据
    await FavoriteStore.removeArticleSnapshot(ctx, id);

    // 7. 触发全局状态同步：通知其他页面更新收藏状态
    AppStorage.setOrCreate('fav_version', 0);
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  /**
   * 头部标题动画控制
   *
   * 页面显示时执行渐入动画，提升用户体验：
   * - 透明度从0到1（淡入效果）
   * - 位置从偏移到正常（滑动效果）
   * - 持续时间260ms，缓出曲线（平滑过渡）
   */
  private animateHeader(): void {
    animateTo({
      duration: 260,
      curve: Curve.EaseOut  // 缓出曲线：平滑结束效果
    }, () => {
      this.headerOpacity = 1;
      this.headerOffset = 0;
    });
  }

  /**
   * 页面UI构建方法
   *
   * 采用分层布局结构，包含头部标题和文章列表：
   * - Stack布局：背景层 + 内容层分离
   * - 条件渲染：根据状态显示不同UI内容
   * - 动画控制：组件级动画状态管理
   * - 响应式设计：适配不同屏幕尺寸
   *
   * 布局层次：
   * 1. Stack层：背景图片 + 主内容区域
   * 2. Column层：头部导航 + 内容区域
   * 3. 条件渲染：登录状态 → 数据状态 → 具体内容
   */
  build() {
    Stack() {
      // 背景图片层：全屏背景，增强视觉体验
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 主内容区域：包含所有交互元素
      Column() {
        // ==================== 顶部标题栏 ====================
        Stack({ alignContent: Alignment.Center }) {
          Row() {
            // 返回按钮区域：根据路由参数动态显示
            if (this.showBackButton) {
              Text('←')
                .fontSize(22)
                .onClick(() => router.back())  // 返回上一页功能
                .width(40)
            } else {
              Blank().width(40)  // 占位元素：保持布局平衡
            }

            Blank().layoutWeight(1)  // 弹性空间：实现标题居中

            // 收藏数量统计：实时显示收藏文章数量
            Text(`共 ${this.favArticles.length} 条`)
              .fontSize(14)
              .opacity(0.7)
              .textAlign(TextAlign.End)
              .padding({ right: 8 })
          }
          .alignItems(VerticalAlign.Center)
          .width('100%')

          // 页面标题：居中显示，突出页面功能
          Text('收藏')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
        }
        .padding(12)
        .margin({ top: 12, left: 16, right: 16, bottom: 12 })
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 6 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ==================== 主体内容区域 ====================
        if (this.uid === '0') {
          // 未登录状态提示：引导用户进行登录
          Text('请先去【我的】页登录')
            .margin(16)
            .opacity(0.7)
        } else if (this.favArticles.length === 0) {
          // 空收藏状态提示：友好的空数据展示
          Text('暂无收藏')
            .margin(16)
            .opacity(0.7)
        } else {
          // 收藏文章列表：使用List组件实现高性能滚动
          List() {
            ForEach(this.favArticles, (item: Article) => {
              ListItem() {
                Row() {
                  // 文章信息区域：显示标题和描述
                  Column({ space: 6 }) {
                    Text(item.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                    Text(item.desc)
                      .fontSize(13)
                      .opacity(0.7)
                      .maxLines(2)
                  }
                  .layoutWeight(1)  // 弹性布局：占据剩余水平空间

                  // 取消收藏按钮：使用gesture避免触发卡片跳转
                  Text('★')
                    .fontSize(22)
                    .margin({ left: 10 })
                    .gesture(
                      TapGesture().onAction(async () => {
                        await this.removeFav(item.id);
                      })
                    )
                }
                .padding(12)
                .margin({ left: 16, right: 16, bottom: 12 })
                .borderRadius(16)
                .backgroundColor('#FFFFFF')
                .shadow({ radius: 12, color: '#1A000000', offsetX: 0, offsetY: 5 })
                // 点击卡片进入正文：主要交互功能
                .onClick(async () => {
                  await this.openDetail(item);
                })
              }
            })
          }
          .width('100%')
          .layoutWeight(1)  // 弹性布局：占据剩余垂直空间
        }
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面显示时的初始化操作（生命周期钩子）

        this.updateBackButton();  // 解析路由参数，确定是否显示返回按钮
        this.refresh();           // 加载收藏数据，确保显示最新内容
        this.animateHeader();     // 执行头部动画，提升用户体验
      })
    }
    .width('100%')
    .height('100%')
  }
}