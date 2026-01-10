/**
 * 收藏页面 - 用户收藏文章管理
 * 
 * 功能概述：
 * - 展示用户收藏的文章列表
 * - 支持取消收藏操作
 * - 提供文章详情跳转功能
 * - 实时同步收藏状态变化
 * 
 * 架构特点：
 * - 全局状态驱动的数据同步机制
 * - 智能数据缓存与远程数据融合
 * - 响应式UI状态管理
 * - 安全的页面跳转机制
 * 
 * 技术亮点：
 * - 收藏版本控制实现实时同步
 * - 双层数据源策略（远程API + 本地缓存）
 * - 平滑的页面过渡动画
 * - 完善的错误处理和降级方案
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';

// 数据模型和存储导入
import type { Article } from '../model/Article';
import { FavoriteStore } from '../store/FavoriteStore';
import { ArticleStore } from '../store/ArticleStore';
import { fetchArticlesByIds } from '../service/WanService';

interface FavoritePageParams {
  showBackButton?: boolean;
  showBack?: boolean;
}

// 确保全局状态key存在（避免首次get为undefined）
AppStorage.setOrCreate('fav_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 * 收藏页面主组件
 * 
 * 核心职责：
 * - 管理用户收藏文章列表
 * - 响应全局状态变化实时更新
 * - 提供收藏文章的浏览和取消收藏功能
 */
@Entry
@Component
export struct FavoritePage {
  @State showBackButton: boolean = false; // 是否显示返回按钮
  /**
   * 获取宿主上下文
   * 用于访问UIAbility上下文，执行数据存储等操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 全局状态同步绑定
   * StorageLink与AppStorage建立双向数据绑定
   * Watch监听状态变化，触发回调函数
   * 
   * 实现机制：当用户在其他页面进行收藏操作时，
   * 全局版本号递增，触发当前页面的数据刷新
   */
  @StorageLink('fav_version')
  @Watch('onFavVersionChange')
  favVersion: number = 0; // 收藏版本号，收藏操作时递增
  
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0; // 会话版本号，登录状态变化时递增

  /**
   * 组件内部状态管理
   * State管理的响应式状态，变化时触发UI重新渲染
   */
  @State uid: string = '0'; // 当前用户ID
  @State favIds: Set<number> = new Set<number>(); // 用户收藏的文章ID集合
  @State favArticles: Article[] = []; // 收藏的文章列表（完整数据）

  // 动画相关状态
  @State headerOpacity: number = 0; // 头部导航栏透明度
  @State headerOffset: number = 12; // 头部导航栏垂直偏移

  /**
   * 路由参数解析
   * 用于判断是否显示返回按钮
   */
  private updateBackButton() {
    const params = router.getParams() as FavoritePageParams | undefined;
    this.showBackButton = Boolean(params?.showBackButton ?? params?.showBack);
  }

  /**
   * 收藏版本变化监听器
   * 当用户在其他页面进行收藏操作时触发
   * 重新加载收藏数据
   */
  private onFavVersionChange() {
    this.refresh();
  }

  /**
   * 会话版本变化监听器
   * 当用户登录状态发生变化时触发
   * 重新加载当前用户的收藏数据
   */
  private onSessionVersionChange() {
    this.refresh();
  }

  /**
   * 刷新收藏数据
   * 核心数据加载方法，支持多种数据源融合
   * 
   * 数据加载策略：
   * 1. 获取用户ID和收藏文章ID集合
   * 2. 优先从远程API获取最新文章数据
   * 3. 使用本地缓存数据作为兜底方案
   * 4. 合并远程和缓存数据，避免重复
   */
  private async refresh() {
    const ctx = this.hostCtx();
    
    // 获取当前用户ID
    this.uid = await FavoriteStore.getUid(ctx);
    
    // 未登录用户处理
    if (this.uid === '0') {
      this.favIds = new Set<number>();
      this.favArticles = [];
      return;
    }

    // 加载用户收藏的文章ID集合
    const set = await FavoriteStore.loadFavSet(ctx, this.uid);
    this.favIds = set;
    
    try {
      // 优先从远程API获取文章数据（获取最新信息）
      const remote = await fetchArticlesByIds(set);
      const remoteIds = new Set(remote.map(item => item.id));
      
      // 从本地缓存获取文章数据（作为兜底）
      const cached = await FavoriteStore.pickCachedArticles(ctx, set);
      
      // 合并远程和缓存数据，避免重复
      const merged = [...remote];
      cached.forEach(item => {
        if (!remoteIds.has(item.id)) {
          merged.push(item);
        }
      });
      
      this.favArticles = merged;
    } catch (e) {
      // 远程API失败时的降级处理
      promptAction.showToast({ message: (e as Error)?.message ?? '收藏数据加载失败' });
      
      // 使用本地缓存数据展示
      this.favArticles = await FavoriteStore.pickCachedArticles(ctx, set);
    }
  }

  /**
   * 安全跳转到文章详情页
   * 包含异常处理机制，确保跳转稳定性
   * 
   * @param article 要查看的文章对象
   */
  private async openDetail(article: Article) {
    try {
      // 缓存当前文章列表，供详情页使用
      ArticleStore.setArticles(this.favArticles);
      
      // 跳转到文章详情页，传递文章ID和完整文章对象
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      // 跳转失败时的友好提示
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 取消收藏操作
   * 从收藏列表中移除指定文章
   * 
   * @param id 要取消收藏的文章ID
   */
  private async removeFav(id: number) {
    // 登录验证
    if (this.uid === '0') {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    
    const ctx = this.hostCtx();
    
    // 更新本地收藏状态
    const next = new Set(this.favIds);
    next.delete(id);
    this.favIds = next;

    const times = await FavoriteStore.loadFavTimes(ctx, this.uid);
    times.delete(id);
    // 保存到持久化存储
    await FavoriteStore.saveFavSet(ctx, this.uid, next);
    await FavoriteStore.saveFavTimes(ctx, this.uid, times);

    // 更新UI显示
    this.favArticles = this.favArticles.filter(item => item.id !== id);
    
    // 移除文章快照
    await FavoriteStore.removeArticleSnapshot(ctx, id);
    
    // 触发全局状态同步（通知其他页面更新）
    AppStorage.setOrCreate('fav_version', 0);
    const v = (AppStorage.get('fav_version') as number) ?? 0;
    AppStorage.set('fav_version', v + 1);
  }

  /**
   * 头部标题动画
   * 页面显示时执行渐入动画
   */
  private animateHeader() {
    animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
      this.headerOpacity = 1;
      this.headerOffset = 0;
    });
  }

  /**
   * 页面UI构建
   * 采用分层布局结构，包含头部标题和文章列表
   */
  build() {
    Stack() {
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column() {
        // 顶部标题栏
        Stack({ alignContent: Alignment.Center }) {
          Row() {
            if (this.showBackButton) {
              Text('←')
                .fontSize(22)
                .onClick(() => router.back())
                .width(40)
            } else {
              Blank().width(40)
            }

            Blank().layoutWeight(1)

            // 收藏数量统计
            Text(`共 ${this.favArticles.length} 条`)
              .fontSize(14)
              .opacity(0.7)
              .textAlign(TextAlign.End)
              .padding({ right: 8 })
          }
          .alignItems(VerticalAlign.Center)
          .width('100%')

          // 页面标题
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

        // 主体内容区域
        if (this.uid === '0') {
          // 未登录状态提示
          Text('请先去【我的】页登录').margin(16).opacity(0.7)
        } else if (this.favArticles.length === 0) {
          // 空状态提示
          Text('暂无收藏').margin(16).opacity(0.7)
        } else {
          // 收藏文章列表
          List() {
            ForEach(this.favArticles, (item: Article) => {
              ListItem() {
                Row() {
                  // 文章信息区域
                  Column({ space: 6 }) {
                    Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                    Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                  }.layoutWeight(1)

                  // 取消收藏按钮（使用gesture避免触发卡片跳转）
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
                // 点击卡片进入正文
                .onClick(async () => {
                  await this.openDetail(item);
                })
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面显示时的初始化操作
        this.updateBackButton();
        this.refresh();
        this.animateHeader();
      })
    }
    .width('100%')
    .height('100%')
  }
}