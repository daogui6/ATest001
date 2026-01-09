/*
 * SplashPage.ets - 启动页面
 * 
 * 功能说明：
 * - 应用启动时的欢迎页面
 * - 展示应用Logo和品牌信息
 * - 执行启动动画效果
 * - 自动跳转到主页面
 * 
 * 页面架构：
 * - 全屏背景图片
 * - 中央应用图标区域
 * - 加载提示文本
 * 
 * 动画效果：
 * - 图标淡入动画
 * - 图标缩放动画
 * - 定时自动跳转
 * 
 * 生命周期管理：
 * - aboutToAppear: 启动动画和跳转定时器
 * - aboutToDisappear: 清理定时器资源
 */

import router from '@ohos.router';

/**
 * 启动页面组件
 * 
 * 主要功能：
 * 1. 展示应用启动画面
 * 2. 执行品牌展示动画
 * 3. 自动导航到主页面
 * 4. 管理启动定时器资源
 */
@Entry
@Component
export struct SplashPage {
  // ========== 定时器管理 ==========
  
  /**
   * 导航定时器引用
   * 用于在启动动画完成后自动跳转到主页面
   */
  private navigateTimer?: number;

  // ========== 动画状态管理 ==========
  
  /**
   * 图标透明度状态
   * 初始值为0.6，动画过程中逐渐变为1（完全不透明）
   */
  @State iconOpacity: number = 0.6;
  
  /**
   * 图标缩放状态
   * 初始值为0.9，动画过程中逐渐变为1（原始大小）
   */
  @State iconScale: number = 0.9;

  /**
   * 进度条数值
   * 初始值为0，动画过程中逐渐变为100（完成）
   */
  @State loadingProgress: number = 0;

  // ========== 生命周期方法 ==========
  
  /**
   * 页面即将显示时调用
   * 执行启动动画和设置跳转定时器
   */
  aboutToAppear() {
    // 执行图标动画效果
    animateTo({ duration: 1800, curve: Curve.EaseOut }, () => {
      this.iconOpacity = 1;     // 完全显示
      this.iconScale = 1;       // 原始大小
      this.loadingProgress = 100; // 进度条完成
    });

    // 设置跳转定时器
    // 1800毫秒后自动跳转到主页面
    this.navigateTimer = setTimeout(() => {
      router.replaceUrl({ url: 'pages/Index' });
    }, 1800);
  }

  /**
   * 页面即将消失时调用
   * 清理定时器资源，防止内存泄漏
   */
  aboutToDisappear() {
    // 清理导航定时器
    if (this.navigateTimer !== undefined) {
      clearTimeout(this.navigateTimer);
      this.navigateTimer = undefined;
    }
  }

  // ========== 页面构建方法 ==========
  
  /**
   * 构建启动页面UI
   * 使用Stack布局实现全屏背景和居中内容
   */
  build() {
    Stack({ alignContent: Alignment.Center }) {
      // ========== 背景图片区域 ==========
      
      /**
       * 全屏背景图片
       * 使用app.media.background资源，覆盖整个屏幕
       */
      Image($r('app.media.beijingtu'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // ========== 中央内容区域 ==========
      
      Column({ space: 16 }) {
        /**
         * 进度条
         * 位于图标上方，用于提示加载进度
         */
        Progress({ value: this.loadingProgress, total: 100, style: ProgressStyle.Linear })
          .width(220)
          .height(6)
          .color('#4C7DFF')
          .backgroundColor('#E1E6F5')
          .borderRadius(3)

        /**
         * 应用图标
         * 使用app.media.xuexi资源
         * 应用透明度动画和缩放动画效果
         */
        Image($r('app.media.xuexi'))
          .width(140)
          .height(140)
          .objectFit(ImageFit.Contain)
          .opacity(this.iconOpacity)        // 动态透明度
          .scale({ x: this.iconScale, y: this.iconScale })  // 动态缩放
          .borderRadius(28)                 // 圆角效果

        /**
         * 加载提示文本
         * 显示"加载中..."提示信息
         * 应用与图标相同的透明度动画
         */
        Text('加载中...')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .opacity(this.iconOpacity)        // 同步透明度动画
      }
      .alignItems(HorizontalAlign.Center)   // 水平居中
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FF')             // 备用背景色
  }
}