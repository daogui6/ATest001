/**
 * 点赞记录页面 - 用户点赞历史管理
 *
 * 功能概述：
 * - 展示用户点赞过的文章列表，支持实时同步更新
 * - 提供文章详情跳转功能，支持平滑过渡动画
 * - 优雅的登录状态处理和空状态展示
 * - 智能数据缓存与远程数据融合策略
 *
 * 架构特点：
 * - 全局状态驱动的数据同步机制（AppStorage + @StorageLink）
 * - 响应式UI状态管理（@State + @Watch）
 * - 渐进式动画加载效果，提升用户体验
 * - 完善的错误处理和降级方案
 *
 * 技术亮点：
 * - 点赞版本控制实现跨页面实时同步
 * - 双层数据源策略：远程API（新鲜度）+ 本地缓存（可用性）
 * - 平滑的页面过渡动画和组件级动画控制
 * - 资源自动管理和异常边界处理
 *
 * 数据流设计：
 * 1. 页面初始化 → 加载点赞数据
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
import { ArticleStore } from '../store/ArticleStore';
import { UserActionStore } from '../store/UserActionStore';
import { fetchArticlesByIds } from '../service/WanService';

/**
 * 全局状态初始化
 * 通过AppStorage实现跨页面状态同步，确保状态键存在
 *
 * 状态说明：
 * - liked_version: 点赞版本号，点赞操作时递增触发同步
 * - session_version: 会话版本号，登录状态变化时触发同步
 */
AppStorage.setOrCreate('liked_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 * 点赞记录页面主组件
 *
 * @Entry 装饰器标记为页面入口组件，可被路由系统识别
 * @Component 定义可复用的UI组件结构
 *
 * 核心职责：
 * - 管理用户点赞历史记录的完整生命周期
 * - 响应全局状态变化实现实时数据同步
 * - 提供优雅的UI交互体验和视觉反馈
 * - 处理用户认证状态和数据权限
 *
 * 页面状态：
 * - 未登录状态：显示登录引导提示
 * - 空点赞状态：显示空状态UI
 * - 正常状态：显示点赞文章列表
 */
@Entry
@Component
export struct LikedPage {
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
   * 点赞版本号状态绑定
   *
   * @StorageLink 与AppStorage建立双向数据绑定
   * @Watch 监听状态变化，触发回调函数
   *
   * 实现机制：当用户在其他页面进行点赞操作时，
   * 全局版本号递增，通过@Watch触发当前页面的数据刷新
   */
  @StorageLink('liked_version')
  @Watch('onLikedVersionChange')
  likedVersion: number = 0;

  /**
   * 会话版本号状态绑定
   *
   * 监听用户登录状态变化，重新加载对应用户的点赞数据
   */
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  // ==================== 组件内部状态管理 ====================

  /**
   * 组件内部响应式状态，变化时触发UI重新渲染
   */
  @State uid: string = '0';                    // 当前用户ID，'0'表示未登录
  @State likedIds: Set<number> = new Set<number>();    // 用户点赞过的文章ID集合
  @State likedArticles: Article[] = [];        // 点赞过的文章列表（完整数据）

  // ==================== 动画相关状态 ====================

  @State headerOpacity: number = 0;            // 头部导航栏透明度（用于渐入动画）
  @State headerOffset: number = 12;            // 头部导航栏垂直偏移（用于滑动动画）
  @State listOpacity: number = 0;              // 列表内容透明度（用于渐入动画）
  @State listOffset: number = 16;              // 列表内容垂直偏移（用于滑动动画）

  /**
   * 点赞版本变化监听器
   *
   * 当用户在其他页面进行点赞操作时触发
   * 重新加载点赞数据，保持页面数据同步
   *
   * 触发场景：
   * - 用户在文章详情页进行点赞操作
   * - 用户在其他页面取消点赞
   * - 点赞状态全局同步通知
   */
  private onLikedVersionChange() {
    this.refresh();
  }

  /**
   * 会话版本变化监听器
   *
   * 当用户登录状态发生变化时触发
   * 重新加载当前用户的点赞数据，实现用户数据隔离
   *
   * 触发场景：
   * - 用户成功登录应用
   * - 用户退出当前账号
   * - 用户切换不同账号
   */
  private onSessionVersionChange() {
    this.refresh();
  }

  /**
   * 刷新点赞记录数据（核心数据加载方法）
   *
   * 支持多种数据源融合的智能加载策略：
   * 1. 获取用户ID和点赞文章ID集合
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
  private async refresh() {
    const ctx = this.hostCtx();

    // 1. 获取当前用户ID（用户身份验证）
    this.uid = await UserActionStore.getUid(ctx);

    // 2. 未登录用户处理：清空数据并返回
    if (this.uid === '0') {
      this.likedIds = new Set<number>();
      this.likedArticles = [];
      return;
    }

    // 3. 加载用户点赞过的文章ID集合
    const set = await UserActionStore.loadLikedSet(ctx, this.uid);
    this.likedIds = set;

    try {
      // 4. 优先从远程API获取文章数据（获取最新信息）
      const remote = await fetchArticlesByIds(set);
      const remoteIds = new Set(remote.map(item => item.id));

      // 5. 从本地缓存获取文章数据（作为兜底方案）
      const cached = await UserActionStore.pickCachedLikedArticles(ctx, set);

      // 6. 合并远程和缓存数据，避免重复
      // 策略：优先使用远程数据，缓存数据作为补充
      const merged = [...remote];
      cached.forEach(item => {
        if (!remoteIds.has(item.id)) {
          merged.push(item);
        }
      });

      this.likedArticles = merged;
    } catch (e) {
      // 7. 远程API失败时的降级处理：使用本地缓存数据
      promptAction.showToast({ message: (e as Error)?.message ?? '点赞数据加载失败' });

      // 8. 使用本地缓存数据展示（保证页面可用性）
      this.likedArticles = await UserActionStore.pickCachedLikedArticles(ctx, set);
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
  private async openDetail(article: Article) {
    try {
      // 缓存当前文章列表，供详情页使用（支持前后导航）
      ArticleStore.setArticles(this.likedArticles);

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
   * 页面UI构建方法
   *
   * 采用分层渐入的动画效果，提升用户体验：
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
        // ==================== 顶部导航栏 ====================
        Row() {
          // 返回按钮：提供页面导航功能
          Text('←')
            .fontSize(20)
            .margin({ left: 16 })
            .onClick(() => router.back());

          // 页面标题：居中显示，突出页面功能
          Text('点赞过')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .margin({ right: 36 }) // 视觉平衡：抵消返回按钮的布局影响
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, right: 16, bottom: 12 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ==================== 主体内容区域 ====================
        if (this.uid === '0') {
          // 未登录状态提示：引导用户进行登录
          Text('请先去【我的】页登录').margin(16).opacity(0.7)
            .opacity(this.listOpacity)
            .translate({ x: 0, y: this.listOffset })
        } else if (this.likedArticles.length === 0) {
          // 空状态提示：友好的空数据展示
          Text('暂无点赞记录').margin(16).opacity(0.7)
            .opacity(this.listOpacity)
            .translate({ x: 0, y: this.listOffset })
        } else {
          // 点赞文章列表：使用List组件实现高性能滚动
          List() {
            ForEach(this.likedArticles, (item: Article) => {
              ListItem() {
                Column({ space: 6 }) {
                  // 文章标题：突出显示，限制2行防止溢出
                  Text(item.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(2)

                  // 文章描述：辅助信息，透明度降低突出层次
                  Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)

                  // 作者信息：元数据展示，最小化视觉权重
                  Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                }
                .width('100%')
                .height(120) // 固定高度：保证列表项视觉一致性
                .padding(12)
                .margin({ bottom: 12 })
                .borderRadius(16)
                .backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#E9EEF5' }) // 细边框：增强视觉层次
                .justifyContent(FlexAlign.SpaceBetween)
                .onClick(async () => await this.openDetail(item))
              }
            })
          }
          .padding({ left: 16, right: 16 })
          .width('100%')
          .layoutWeight(1) // 弹性布局：占据剩余垂直空间
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
        }
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面显示时的初始化操作（生命周期钩子）

        // 1. 刷新点赞数据：确保显示最新数据
        this.refresh();

        // 2. 头部导航栏动画：渐入+上移效果
        animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.headerOpacity = 1;
          this.headerOffset = 0;
        });

        // 3. 列表内容动画：延迟渐入+上移（创造视觉层次感）
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.listOpacity = 1;
          this.listOffset = 0;
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}