/**
 * 离线下载页面 - 管理已下载文章
 *
 * 功能概述：
 * - 展示用户离线下载的文章列表，按下载时间倒序排列
 * - 支持查看已下载文章的详细内容
 * - 提供删除离线内容的清理功能
 * - 优雅的空状态处理和用户引导
 *
 * 架构特点：
 * - 简洁的状态管理设计（@State）
 * - 响应式数据绑定和UI更新
 * - 安全的文件操作和资源管理
 * - 直观的用户操作反馈
 *
 * 技术亮点：
 * - 离线内容的状态管理
 * - 下载时间的格式化显示
 * - 安全的文件删除操作
 * - 页面导航的异常处理
 *
 * 数据管理：
 * - 下载文章列表的状态维护
 * - 用户身份验证和权限检查
 * - 离线内容的增删改查操作
 *
 * 使用场景：
 * - 离线阅读内容管理
 * - 存储空间优化
 * - 无网络环境下的内容访问
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
import { DownloadStore, type DownloadedArticle } from '../store/DownloadStore';
import { ArticleStore } from '../store/ArticleStore';

/**
 * 离线下载页面主组件
 *
 * @Entry 装饰器标记为页面入口组件
 * @Component 定义可复用的UI组件结构
 *
 * 核心职责：
 * - 管理用户离线下载文章的完整生命周期
 * - 提供离线内容的查看和删除功能
 * - 处理页面导航和状态同步
 * - 确保离线内容的安全访问
 *
 * 页面状态：
 * - 空下载状态：显示引导提示
 * - 正常状态：显示下载文章列表
 */
@Entry
@Component
export struct OfflineDownloadsPage {
  // ==================== 组件内部状态管理 ====================

  @State uid: string = '0';                    // 当前用户ID，'0'表示未登录
  @State downloads: DownloadedArticle[] = [];  // 离线下载的文章列表

  /**
   * 获取宿主上下文（UIAbility上下文）
   *
   * 用于访问应用级资源和执行数据存储操作
   *
   * @returns UIAbility上下文对象，用于数据持久化操作
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 组件生命周期方法：页面即将显示时调用
   *
   * 用于页面初始化操作，确保数据正确加载
   * 在页面显示前刷新离线下载数据
   */
  async aboutToAppear() {
    await this.refresh();
  }

  /**
   * 刷新离线下载数据
   *
   * 加载用户的所有离线下载内容
   * 支持用户状态验证和数据权限检查
   *
   * 数据加载流程：
   * - 获取用户身份 → 加载下载列表 → UI更新
   */
  private async refresh() {
    const ctx = this.hostCtx();

    // 1. 获取当前用户ID
    this.uid = await DownloadStore.getUid(ctx);

    // 2. 加载用户的离线下载内容
    this.downloads = await DownloadStore.loadDownloads(ctx, this.uid);
  }

  /**
   * 时间格式化工具函数
   *
   * 将时间戳格式化为可读的日期时间字符串
   * 格式：YYYY-MM-DD HH:MM
   *
   * @param ts 时间戳（毫秒）
   * @returns 格式化后的日期时间字符串
   */
  private formatTime(ts: number): string {
    const d = new Date(ts);
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  /**
   * 打开文章详情页
   *
   * 提供从离线列表到文章详情的导航功能
   * 包含异常处理机制，确保跳转稳定性
   *
   * @param article 要查看的文章对象
   */
  private async openDetail(article: Article) {
    try {
      // 缓存当前文章对象，供详情页使用
      ArticleStore.setArticle(article);

      // 跳转到文章详情页
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: article.id, article: article }
      });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 删除离线下载内容
   *
   * 完整的删除操作流程：
   * 1. 从持久化存储中移除下载记录
   * 2. 更新UI状态（从列表中移除）
   * 3. 提供操作成功反馈
   *
   * @param id 要删除的下载文章ID
   */
  private async removeDownload(id: number) {
    const ctx = this.hostCtx();

    // 1. 从存储中删除下载记录
    await DownloadStore.removeDownload(ctx, this.uid, id);

    // 2. 更新UI状态：从列表中过滤掉已删除的项
    this.downloads = this.downloads.filter(item => item.id !== id);

    // 3. 提供操作成功反馈
    promptAction.showToast({ message: '已删除离线内容' });
  }

  /**
   * 页面UI构建方法
   *
   * 采用简洁的卡片式布局，提供清晰的离线内容管理：
   * - Stack布局：背景层 + 内容层分离
   * - Scroll容器：支持内容滚动浏览
   * - 条件渲染：根据数据状态显示不同内容
   * - 直观的操作按钮：查看和删除功能
   *
   * 布局层次：
   * 1. Stack层：背景图片 + 主内容区域
   * 2. Column层：头部导航 + 滚动内容
   * 3. 条件渲染：数据状态 → 具体内容
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
          Text('离线下载')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Blank().width(36)  // 占位元素：保持布局平衡
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, right: 16, bottom: 12 })

        // ==================== 主体内容区域 ====================
        Scroll() {
          Column({ space: 12 }) {
            if (this.downloads.length === 0) {
              // 空状态提示：引导用户进行下载操作
              Text('暂无离线内容，快去下载文章吧').margin(16).opacity(0.6)
            } else {
              // 离线下载列表：使用ForEach渲染下载项
              ForEach(this.downloads, (item: DownloadedArticle) => {
                Column({ space: 8 }) {
                  // 文章标题：突出显示
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)

                  // 作者信息：辅助信息显示
                  Text(`作者：${item.author || '未知'}`).fontSize(12).opacity(0.6)

                  // 下载时间：显示内容下载的具体时间
                  Text(`下载时间：${this.formatTime(item.downloadedAt)}`).fontSize(11).opacity(0.6)

                  // 操作按钮区域：查看和删除功能
                  Row({ space: 10 }) {
                    // 查看按钮：跳转到文章详情
                    Button('查看', { type: ButtonType.Capsule })
                      .onClick(async () => await this.openDetail(item))

                    // 删除按钮：移除离线内容（红色警示色）
                    Button('删除', { type: ButtonType.Capsule })
                      .backgroundColor('#FEE2E2')
                      .fontColor('#B91C1C')
                      .onClick(async () => await this.removeDownload(item.id))
                  }
                }
                .padding(14)
                .borderRadius(12)
                .backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#E9EEF5' })
                .shadow({ radius: 10, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
              })
            }
          }
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)  // 弹性布局：占据剩余垂直空间
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}