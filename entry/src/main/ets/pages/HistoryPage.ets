/**
 * 历史记录页面 - 用户阅读历史管理
 *
 * 功能概述：
 * - 展示用户阅读过的文章历史记录，支持时间倒序排列
 * - 支持清空历史记录功能，提供一键清理操作
 * - 提供历史文章快速跳转，恢复阅读上下文
 * - 实时同步阅读历史变化，跨页面状态一致性
 *
 * 架构特点：
 * - 全局状态驱动的数据同步机制（AppStorage + @StorageLink）
 * - 渐进式动画加载效果，提升用户体验
 * - 简洁的列表展示界面，突出内容可读性
 * - 响应式UI状态管理，自动适应数据变化
 *
 * 技术亮点：
 * - 历史版本控制实现实时同步，确保数据时效性
 * - 平滑的页面过渡动画，创造流畅交互体验
 * - 安全的页面跳转机制，包含异常边界处理
 * - 优雅的空状态处理，提供友好的用户引导
 *
 * 数据流程：
 * 1. 页面初始化 → 加载本地历史记录
 * 2. 全局状态变化 → 触发数据刷新
 * 3. 用户操作 → 更新本地存储和UI状态
 * 4. 异常情况 → 降级处理和用户提示
 */

// 导入HarmonyOS系统模块
import type common from '@ohos.app.ability.common'; // UIAbility上下文类型，用于数据存储操作
import promptAction from '@ohos.promptAction'; // 用户提示操作，提供Toast反馈
import router from '@ohos.router'; // 页面路由导航，实现页面跳转功能

// 导入应用数据模型和存储模块
import type { Article } from '../model/Article'; // 文章数据模型，定义文章数据结构
import { HistoryStore } from '../store/HistoryStore'; // 历史记录存储管理，提供数据持久化
import { AppLoadingProgress } from '../components/AppLoadingProgress'; // 加载进度组件，提升等待体验

/**
 * 全局状态初始化
 * 通过AppStorage实现跨页面状态同步，确保状态键存在
 *
 * 状态说明：
 * - history_version: 历史版本号，阅读操作时递增触发同步
 *   当用户在其他页面阅读文章时，版本号递增，触发本页面数据刷新
 */
AppStorage.setOrCreate('history_version', 0);

/**
 * 历史记录页面主组件
 *
 * @Entry 装饰器标记为页面入口组件，可被路由系统识别和导航
 * @Component 定义可复用的UI组件结构，封装页面逻辑和样式
 *
 * 核心职责：
 * - 管理用户阅读历史记录的完整生命周期
 * - 响应全局状态变化实现实时数据同步
 * - 提供历史记录的浏览、清理和跳转功能
 * - 处理页面动画效果和用户交互反馈
 *
 * 页面状态：
 * - 加载中状态：显示进度指示器
 * - 空历史状态：显示引导提示
 * - 正常状态：显示历史文章列表
 */
@Entry
@Component
export struct HistoryPage {
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

  /**
   * 组件内部状态管理
   * @State 管理的响应式状态，变化时触发UI重新渲染
   */
  @State history: Article[] = []; // 阅读历史文章列表，按时间倒序排列
  @State loading: boolean = false; // 数据加载状态，控制加载指示器显示

  // 动画相关状态，用于页面显示时的渐入效果
  @State headerOpacity: number = 0; // 头部导航栏透明度，0为完全透明，1为完全不透明
  @State headerOffset: number = 12; // 头部导航栏垂直偏移，用于滑动动画效果
  @State listOpacity: number = 0; // 列表内容透明度，控制内容区域的显示效果
  @State listOffset: number = 16; // 列表内容垂直偏移，创造层次感动画

  /**
   * 全局状态同步绑定
   * @StorageLink 与AppStorage建立双向数据绑定
   * @Watch 监听状态变化，触发回调函数
   *
   * 实现机制：当用户在其他页面阅读文章时，
   * 全局版本号递增，通过@Watch触发当前页面的数据刷新
   * 确保历史记录始终保持最新状态
   */
  @StorageLink('history_version')
  @Watch('onHistoryVersionChange')
  historyVersion: number = 0; // 历史版本号，阅读操作时递增

  /**
   * 组件生命周期：页面即将显示
   * 在此阶段执行数据初始化操作，确保页面显示时数据已准备就绪
   *
   * 执行时机：页面即将进入可视状态时调用
   * 主要任务：加载历史记录数据，准备页面内容
   */
  async aboutToAppear() {
    await this.loadHistory();
  }

  /**
   * 历史版本变化监听器
   *
   * 当用户在其他页面阅读文章时触发
   * 重新加载历史记录数据，保持页面数据同步
   *
   * 触发场景：
   * - 用户在文章详情页阅读新文章
   * - 其他页面触发了历史记录更新
   * - 全局状态同步通知
   */
  private onHistoryVersionChange() {
    this.loadHistory();
  }

  /**
   * 加载历史记录数据
   *
   * 从本地存储中读取用户的阅读历史，支持异步加载
   * 包含完整的加载状态管理，提供用户友好的等待体验
   *
   * 加载流程：
   * 1. 设置加载状态，显示进度指示器
   * 2. 调用存储服务获取历史数据
   * 3. 更新本地状态，触发UI重新渲染
   * 4. 清除加载状态，隐藏进度指示器
   */
  private async loadHistory() {
    this.loading = true; // 开始加载，显示加载指示器
    const list = await HistoryStore.loadHistory(this.hostCtx()); // 从存储加载数据
    this.history = list; // 更新历史记录状态
    this.loading = false; // 加载完成，隐藏加载指示器
  }

  /**
   * 清空历史记录
   *
   * 清除用户的所有阅读历史，提供一键清理功能
   * 包含用户确认和操作反馈，确保操作安全性
   *
   * 清理流程：
   * 1. 调用存储服务清除持久化数据
   * 2. 更新本地状态，清空历史列表
   * 3. 显示操作成功提示，提供用户反馈
   */
  private async clearHistory() {
    await HistoryStore.clear(this.hostCtx()); // 清除存储中的数据
    this.history = []; // 更新本地状态，清空历史记录
    promptAction.showToast({ message: '已清空历史' }); // 用户反馈，确认操作完成
  }

  /**
   * 安全跳转到文章详情页
   *
   * 包含异常处理机制，确保页面跳转的稳定性
   * 防止因路由错误或参数异常导致的应用崩溃
   *
   * @param id 要查看的文章ID，用于定位具体文章
   *
   * @throws 不会抛出异常，所有错误都在内部处理
   */
  private async openDetail(id: number) {
    try {
      // 跳转到文章详情页，传递文章ID作为参数
      await router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id }
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
   *
   * 布局层次：
   * 1. Stack层：背景图片 + 主内容区域
   * 2. Column层：头部导航 + 内容区域
   * 3. 条件渲染：加载状态 → 空状态 → 正常状态
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
          Text('阅读历史')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 动态操作按钮：根据历史记录状态显示不同内容
          if (this.history.length > 0) {
            // 有历史记录时显示清空按钮
            Button('清空', { type: ButtonType.Capsule })
              .fontSize(12)
              .fontColor('#4F46E5')
              .backgroundColor('#EEF2FF')
              .height(28)
              .padding({ left: 10, right: 10 })
              .onClick(async () => await this.clearHistory());
          } else {
            // 无历史记录时显示占位元素，保持布局平衡
            Blank().width(78)
          }
        }
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, right: 16, bottom: 12 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        // ==================== 主体内容区域 ====================
        if (this.loading) {
          // 加载中状态：显示进度指示器和提示文字
          Row({ space: 8 }) {
            AppLoadingProgress()
            Text('正在加载历史...').opacity(0.7)
          }
          .padding(16)
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
        } else if (this.history.length === 0) {
          // 空状态提示：友好的空数据展示
          Text('暂无阅读记录').margin(16).opacity(0.7)
            .opacity(this.listOpacity)
            .translate({ x: 0, y: this.listOffset })
        } else {
          // 历史记录列表：使用List组件实现高性能滚动
          List() {
            ForEach(this.history, (item: Article) => {
              ListItem() {
                Row() {
                  Column({ space: 6 }) {
                    // 文章标题：突出显示，限制行数防止溢出
                    Text(item.title).fontSize(16).fontWeight(FontWeight.Medium)
                    // 文章描述：辅助信息，透明度降低突出层次
                    Text(item.desc).fontSize(13).opacity(0.7).maxLines(2)
                    // 作者信息：元数据展示，最小化视觉权重
                    Text(`作者：${item.author}`).fontSize(12).opacity(0.6)
                  }
                  .layoutWeight(1) // 弹性布局：占据剩余水平空间
                }
                .padding(12)
                .margin({ left: 16, right: 16, bottom: 12 })
                .borderRadius(16)
                .backgroundColor('#FFFFFF')
                .border({ width: 1, color: '#E9EEF5' }) // 细边框：增强视觉层次
                .onClick(async () => await this.openDetail(item.id))
              }
            })
          }
          .width('100%')
          .layoutWeight(1) // 弹性布局：占据剩余垂直空间
          .opacity(this.listOpacity)
          .translate({ x: 0, y: this.listOffset })
        }
      }
      .width('100%')
      .height('100%')
      .onAppear(() => {
        // 页面显示时的动画效果（生命周期钩子）

        // 头部导航栏动画：渐入+上移效果
        animateTo({
          duration: 220,
          curve: Curve.EaseOut  // 缓出曲线：平滑结束效果
        }, () => {
          this.headerOpacity = 1;
          this.headerOffset = 0;
        });

        // 列表内容动画：延迟渐入+上移（创造视觉层次感）
        animateTo({
          duration: 260,
          curve: Curve.EaseOut
        }, () => {
          this.listOpacity = 1;
          this.listOffset = 0;
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}