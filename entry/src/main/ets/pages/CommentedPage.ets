/**
 * 评论记录页面 - 用户评论历史管理
 * 
 *  功能概述：
 * - 展示用户评论过的文章列表
 * - 支持评论记录的实时同步更新
 * - 提供文章详情跳转功能
 * - 优雅的登录状态处理和空状态展示
 * 
 *  架构特点：
 * - 全局状态驱动的数据同步机制
 * - 智能数据缓存与远程数据融合
 * - 渐进式动画加载效果
 * - 响应式UI状态管理
 * 
 *  技术亮点：
 * - 评论版本控制实现实时同步
 * - 双层数据源策略（远程API + 本地缓存）
 * - 平滑的页面过渡动画
 * - 完善的错误处理和降级方案
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
 *  全局状态初始化
 * 通过AppStorage实现跨页面状态同步：
 * - commented_version: 评论版本号，评论操作时递增触发同步
 * - session_version: 会话版本号，登录状态变化时触发同步
 */
AppStorage.setOrCreate('commented_version', 0);
AppStorage.setOrCreate('session_version', 0);

/**
 *  评论记录页面主组件
 * 
 * @Entry 装饰器标记为页面入口组件
 * @Component 定义可复用的UI组件结构
 * 
 * 核心职责：
 * - 管理用户评论历史记录
 * - 响应全局状态变化实时更新
 * - 提供优雅的UI交互体验
 */
@Entry
@Component
export struct CommentedPage {
  /**
   * 获取宿主上下文
   * 用于访问UIAbility上下文，执行数据存储等操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   *  全局状态同步绑定
   * @StorageLink 与AppStorage建立双向数据绑定
   * @Watch 监听状态变化，触发回调函数
   * 
   * 实现机制：当用户在其他页面进行评论操作时，
   * 全局版本号递增，触发当前页面的数据刷新
   */
  @StorageLink('commented_version')
  @Watch('onCommentedVersionChange')
  commentedVersion: number = 0; // 评论版本号，评论操作时递增
  
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0; // 会话版本号，登录状态变化时递增

  /**
   *  组件内部状态管理
   * @State 管理的响应式状态，变化时触发UI重新渲染
   */
  @State uid: string = '0'; // 当前用户ID
  @State commentedIds: Set<number> = new Set<number>(); // 用户评论过的文章ID集合
  @State commentedArticles: Article[] = []; // 评论过的文章列表（完整数据）
  
  //  动画相关状态
  @State headerOpacity: number = 0; // 头部导航栏透明度
  @State headerOffset: number = 12; // 头部导航栏垂直偏移
  @State listOpacity: number = 0; // 列表内容透明度
  @State listOffset: number = 16; // 列表内容垂直偏移

  /**
   * 评论版本变化监听器
   * 当用户在其他页面进行评论操作时触发
   * 重新加载评论记录数据
   */
  private onCommentedVersionChange() {
    this.refresh();
  }

  /**
   * 会话版本变化监听器
   * 当用户登录状态发生变化时触发
   * 重新加载当前用户的评论记录
   */
  private onSessionVersionChange() {
    this.refresh();
  }

  /**
   *  刷新评论记录数据
   * 核心数据加载方法，支持多种数据源融合
   * 
   * 数据加载策略：
   * 1. 获取用户ID和评论文章ID集合
   * 2. 优先从远程API获取最新文章数据
   * 3. 使用本地缓存数据作为兜底方案
   * 4. 合并远程和缓存数据，避免重复
   */
  private async refresh() {
    const ctx = this.hostCtx();
    
    // 1. 获取当前用户ID
    this.uid = await UserActionStore.getUid(ctx);
    
    // 2. 未登录用户处理
    if (this.uid === '0') {
      this.commentedIds = new Set<number>();
      this.commentedArticles = [];
      return;
    }

    // 3. 加载用户评论过的文章ID集合
    const set = await UserActionStore.loadCommentedSet(ctx, this.uid);
    this.commentedIds = set;
    
    try {
      // 4. 优先从远程API获取文章数据（获取最新信息）
      const remote = await fetchArticlesByIds(set);
      const remoteIds = new Set(remote.map(item => item.id));
      
      // 5. 从本地缓存获取文章数据（作为兜底）
      const cached = await UserActionStore.pickCachedCommentedArticles(ctx, set);
      
      // 6. 合并远程和缓存数据，避免重复
      const merged = [...remote];
      cached.forEach(item => {
        if (!remoteIds.has(item.id)) {
          merged.push(item);
        }
      });
      
      this.commentedArticles = merged;
    } catch (e) {
      // 7. 远程API失败时的降级处理
      promptAction.showToast({ message: (e as Error)?.message ?? '评论数据加载失败' });
      
      // 8. 使用本地缓存数据展示
      this.commentedArticles = await UserActionStore.pickCachedCommentedArticles(ctx, set);
    }
  }

  /**
   *  安全跳转到文章详情页
   * 包含异常处理机制，确保跳转稳定性
   * 
   * @param article 要查看的文章对象
   */
  private async openDetail(article: Article) {
    try {
      // 缓存当前文章列表，供详情页使用
      ArticleStore.setArticles(this.commentedArticles);
      
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
   *  页面UI构建
   * 采用分层渐入的动画效果，提升用户体验
   */
  build() {
    Column() {
      //  顶部导航栏
      Row() {
        // 返回按钮
        Text('←')
          .fontSize(20)
          .margin({ left: 16 })
          .onClick(() => router.back());

        // 页面标题
        Text('评论过')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 36 }) // 平衡返回按钮的视觉重量
      }
      .alignItems(VerticalAlign.Center)
      .padding({ top: 16, right: 16, bottom: 12 })
      .opacity(this.headerOpacity)
      .translate({ x: 0, y: this.headerOffset })

      //  主体内容区域
      if (this.uid === '0') {
        //  未登录状态提示
        Text('请先去【我的】页登录').margin(16).opacity(0.7)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
      } else if (this.commentedArticles.length === 0) {
        //  空状态提示
        Text('暂无评论记录').margin(16).opacity(0.7)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
      } else {
        //  评论文章列表
        List() {
          ForEach(this.commentedArticles, (item: Article) => {
            ListItem() {
              Column({ space: 6 }) {
                // 文章标题
                Text(item.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .maxLines(2)
                
                // 文章描述
                Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                
                // 作者信息
                Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
              }
              .width('100%')
              .height(120) // 固定高度保证列表项一致性
              .padding(12)
              .margin({ bottom: 12 })
              .borderRadius(16)
              .backgroundColor('#FFFFFF')
              .border({ width: 1, color: '#E9EEF5' }) // 细边框增强视觉层次
              .justifyContent(FlexAlign.SpaceBetween)
              .onClick(async () => await this.openDetail(item))
            }
          })
        }
        .padding({ left: 16, right: 16 })
        .width('100%')
        .layoutWeight(1) // 占据剩余空间
        .opacity(this.listOpacity)
        .translate({ x: 0, y: this.listOffset })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7FB') // 浅灰色背景提升内容可读性
    .onAppear(() => {
      //  页面显示时的初始化操作
      
      // 1. 刷新评论数据
      this.refresh();
      
      // 2. 头部导航栏动画：渐入+上移
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.headerOpacity = 1;
        this.headerOffset = 0;
      });
      
      // 3. 列表内容动画：延迟渐入+上移（创造层次感）
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.listOpacity = 1;
        this.listOffset = 0;
      });
    })
  }
}