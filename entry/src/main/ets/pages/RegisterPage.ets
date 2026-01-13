/**
 * 注册页面 - 新用户注册功能
 *
 * 功能概述：
 * - 提供完整的用户注册表单和前端验证
 * - 支持用户名、密码、昵称、头像等基本信息设置
 * - 用户协议和隐私政策的交互式确认机制
 * - 注册成功后自动登录并引导权限申请
 *
 * 组件结构：
 * - @Entry装饰器标记为独立页面入口组件
 * - @Component封装注册业务逻辑和UI呈现
 * - 采用分层状态管理策略确保数据一致性
 *
 * 状态管理设计：
 * - 表单输入字段的响应式状态管理
 * - 协议同意的双向绑定状态
 * - 错误消息的即时反馈机制
 * - 页面动画效果的状态控制
 *
 * 技术特点：
 * - 支持头像选择和相册权限申请
 * - 表单验证和错误处理机制
 * - 平滑的页面过渡动画效果
 * - 全局状态同步和会话管理
 *
 * 安全考虑：
 * - 密码输入使用密码类型确保安全
 * - 协议同意强制验证
 * - 权限申请的明确用户授权
 *
 * 版本信息：
 * - HarmonyOS ArkTS实现
 * - 遵循HarmonyOS UI设计规范
 * - 支持多种设备适配
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import picker from '@ohos.file.picker';
import router from '@ohos.router';
import { UserStore } from '../store/UserStore';

/**
 * 注册页面主组件
 *
 * @Entry 标记为页面级入口组件，具备独立的路由能力
 * @Component 定义可复用的UI组件结构和业务逻辑
 *
 * 核心职责：
 * - 管理用户注册流程的完整生命周期
 * - 处理表单验证和用户输入交互
 * - 协调权限申请和头像选择功能
 * - 提供友好的用户体验和错误反馈
 *
 * 设计模式：
 * - 响应式状态管理：使用@State装饰器实现数据驱动UI
 * - 组件化设计：将复杂功能拆分为独立方法
 * - 异常处理：完善的错误捕获和用户提示机制
 */
@Entry
@Component
export struct RegisterPage {
  // ==================== 表单输入状态管理 ====================

  /**
   * 用户名输入状态
   * @State装饰器确保UI响应式更新
  * 初始值为空字符串，等待用户输入
   */
  @State regUsername: string = '' // 用户名输入

  /**
   * 密码输入状态
   * 密码字段在UI层使用密码类型输入框
   */
  @State regPassword: string = '' // 密码输入

  /**
   * 确认密码输入状态
   * 用于二次验证密码一致性
   */
  @State regConfirmPassword: string = '' // 确认密码输入

  /**
   * 昵称输入状态（可选字段）
   * 如果用户未输入，默认使用用户名作为昵称
   */
  @State regNickname: string = '' // 昵称输入（可选）

  /**
   * 头像URL地址状态
   * 存储用户选择的头像图片URI
   * 支持本地相册选择和默认头像
   */
  @State regAvatarUrl: string = '' // 头像地址（可选）

  /**
   * 协议同意状态
   * 控制注册按钮的可用性，必须为true才能注册
   */
  @State registerAgree: boolean = false // 协议同意状态

  /**
   * 错误消息提示状态
   * 用于显示表单验证和注册过程中的错误信息
   */
  @State message: string = '' // 错误消息提示

  // ==================== 页面动画状态管理 ====================

  /**
   * 头部导航栏透明度状态
   * 控制页面加载时的淡入动画效果
   */
  @State headerOpacity: number = 0 // 头部透明度

  /**
   * 头部导航栏偏移量状态
   * 实现从上方滑入的动画效果
   */
  @State headerOffset: number = 12 // 头部偏移量

  /**
   * 表单卡片透明度状态
   * 控制表单区域的淡入动画
   */
  @State cardOpacity: number = 0 // 表单卡片透明度

  /**
   * 表单卡片偏移量状态
   * 实现表单从下方滑入的动画效果
   */
  @State cardOffset: number = 18 // 表单卡片偏移量

  /**
   * 获取宿主上下文（UIAbility上下文）
   *
   * 用于访问应用级资源和执行数据存储操作
   * 在HarmonyOS中，UIAbility上下文提供应用运行环境
   *
   * @returns UIAbility上下文对象，用于数据持久化操作
   *
   * 技术说明：
   * - getUIContext()获取当前UI上下文
   * - getHostContext()获取宿主能力上下文
   * - 类型断言确保类型安全
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 处理用户注册的核心业务逻辑
   *
   * 完整的注册流程：
   * 1. 清空历史错误消息
   * 2. 验证协议同意状态
   * 3. 调用UserStore执行注册
   * 4. 处理注册结果和错误
   * 5. 注册成功后的后续操作
   *
   * 异常处理策略：
   * - 协议验证失败：立即返回并显示错误
   * - 注册服务失败：显示具体错误信息
   * - 成功注册：执行登录和权限引导
   *
   * @async 异步方法，等待注册操作完成
   * @throws 捕获并处理注册过程中的异常
   */
  private async handleRegister() {
    // 清空之前的错误消息，准备新的验证
    this.message = '';

    // 协议同意验证 - 注册前置条件
    if (!this.registerAgree) {
      this.message = '请先阅读并同意服务条款再注册';
      return;
    }

    // 调用UserStore执行实际的注册操作
    // 参数说明：
    // - hostCtx: 应用上下文，用于数据存储
    // - 用户名和密码：核心注册信息
    // - 昵称：可选，未提供时使用用户名
    // - 默认签名：新用户欢迎语
    // - 头像URL：可选的头像地址
    const result = await UserStore.register(
      this.hostCtx(),
      this.regUsername.trim(),        // 去除前后空格
      this.regPassword,
      this.regConfirmPassword,
      this.regNickname.trim() || this.regUsername.trim(), // 昵称兜底逻辑
      '这个人是新用户，快来打个招呼吧～', // 默认用户签名
      this.regAvatarUrl
    );

    // 注册结果处理：检查返回状态
    if (result.ok === false) {
      this.message = result.message; // 显示具体的错误信息
      return;
    }

    // 注册成功后的处理流程
    // 更新全局会话版本，触发其他页面的状态更新
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    // 用户反馈：注册成功提示
    promptAction.showToast({ message: '注册成功，已登录' });

    // 新用户引导：申请必要的应用权限
    await this.requestNewUserPermissions();

    // 页面跳转：进入用户个人中心
    await this.goToMine();
  }

  /**
   * 返回上一页的导航逻辑
   *
   * 支持多种返回策略：
   * 1. 优先使用router.back()正常返回
   * 2. 异常情况下跳转到我的页面作为兜底
   *
   * 设计考虑：
   * - 提供流畅的导航体验
   * - 避免导航异常导致的页面卡死
   * - 确保用户总能到达有效页面
   *
   * @async 异步导航操作
   */
  private async goBack() {
    try {
      // 尝试正常返回上一页
      await router.back();
    } catch (e) {
      // 回退失败时的兜底策略：跳转到我的页面
      await router.pushUrl({ url: 'pages/MinePage' });
    }
  }

  /**
   * 注册完成后跳转到我的页面
   *
   * 使用replaceUrl确保注册页面被替换，避免回退到注册页
   * 异常情况下使用pushUrl作为备用方案
   *
   * 导航策略：
   * - replaceUrl: 替换当前页面，无法返回
   * - pushUrl: 推入新页面，可以返回
   *
   * @async 异步页面跳转
   */
  private async goToMine() {
    try {
      // 设置主页面Tab为“我的”，再替换到主页面避免回退到注册页
      AppStorage.setOrCreate('main_tab_index', 0);
      AppStorage.set('main_tab_index', 3);
      await router.replaceUrl({ url: 'pages/Index' });
    } catch (e) {
      // 替换失败时使用推入导航
      await router.pushUrl({ url: 'pages/Index' });
    }
  }

  /**
   * 选择注册头像的完整流程
   *
   * 头像选择步骤：
   * 1. 申请相册访问权限
   * 2. 创建图片选择器并配置选项
   * 3. 等待用户选择图片
   * 4. 处理选择结果并更新状态
   *
   * 权限管理：
   * - 运行时权限申请
   * - 用户拒绝权限的友好提示
   * - 异常情况的容错处理
   *
   * @async 异步操作，等待用户选择和权限申请
   */
  private async chooseAvatar() {
    try {
      // 第一步：申请相册访问权限
      const permitted = await this.requestPhotoPermission();
      if (!permitted) {
        promptAction.showToast({ message: '未授权相册权限，无法选择头像' });
        return;
      }

      // 第二步：创建并配置图片选择器
      const photoPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE; // 限制为图片类型
      options.maxSelectNumber = 1; // 单次只能选择一张图片

      // 第三步：打开选择器并等待用户操作
      const result = await photoPicker.select(options);

      // 第四步：处理选择结果
      if (result?.photoUris?.length) {
        this.regAvatarUrl = result.photoUris[0]; // 更新头像URL状态
      }
    } catch (e) {
      // 头像选择失败的友好提示
      promptAction.showToast({ message: '头像选择失败，请稍后重试' });
    }
  }

  /**
   * 相册权限申请弹窗
   *
   * 权限申请的最佳实践：
   * - 明确的权限用途说明
   * - 友好的用户交互界面
   * - 合理的默认选项设置
   *
   * @returns Promise<boolean> 用户是否授权相册权限
   *
   * 设计原则：
   * - 权限申请时机：使用时申请
   * - 权限说明：清晰说明用途
   * - 用户选择：提供明确的选择
   */
  private async requestPhotoPermission(): Promise<boolean> {
    try {
      const result = await promptAction.showDialog({
        title: '申请相册权限',
        message: '用于选择头像和上传图片，我们仅会在您主动操作时访问相册。',
        buttons: [
          { text: '暂不允许', color: '#666666' }, // 中性选项
          { text: '允许', color: '#4C6FFF' }      // 主要操作选项
        ]
      });
      return result?.index === 1; // 返回用户选择结果
    } catch {
      return false; // 异常情况下默认拒绝权限
    }
  }

  /**
   * 新用户权限申请引导
   *
   * 注册成功后的权限引导流程：
   * 1. 通知权限：用于消息提醒
   * 2. 个性化推荐权限：提升用户体验
   *
   * 设计特点：
   * - 非阻塞式引导：不影响主要注册流程
   * - 明确的权限说明：让用户理解权限用途
   * - 容错处理：权限引导失败不影响主要功能
   *
   * @async 异步权限引导
   */
  private async requestNewUserPermissions() {
    try {
      // 通知权限申请
      await promptAction.showDialog({
        title: '申请通知权限',
        message: '用于提醒评论回复、点赞消息等重要通知。',
        buttons: [
          { text: '暂不允许', color: '#666666' },
          { text: '允许', color: '#4C6FFF' }
        ]
      });

      // 个性化推荐权限申请
      await promptAction.showDialog({
        title: '申请个性化推荐权限',
        message: '用于根据您的浏览和收藏偏好生成更精准的推荐内容。',
        buttons: [
          { text: '暂不允许', color: '#666666' },
          { text: '允许', color: '#4C6FFF' }
        ]
      });
    } catch (e) {
      // 忽略权限引导异常，避免阻塞注册流程
      // 权限引导是可选的增强功能，不影响核心注册
    }
  }

  /**
   * 查看协议弹窗
   *
   * 提供用户协议和隐私政策的查看功能
   * 支持两种协议类型：
   * - user: 用户服务协议
   * - privacy: 隐私政策说明
   *
   * @param type 协议类型，区分用户协议和隐私政策
   *
   * 用户体验设计：
   * - 简洁明了的协议说明
   * - 统一的对话框样式
   * - 明确的确认操作
   */
  private showAgreement(type: 'user' | 'privacy') {
    const title = type === 'user' ? '用户协议' : '隐私政策';
    const message = type === 'user'
      ? '感谢使用本应用。本协议用于说明账号服务与使用规范，注册即代表您同意遵守相关规则。'
      : '我们仅在提供服务所需范围内处理必要信息，并采取合理措施保护您的数据安全。';

    promptAction.showDialog({
      title,
      message,
      buttons: [{ text: '我知道了', color: '#4C6FFF' }] // 单一确认操作
    });
  }

  /**
   * UI构建方法 - 创建注册表单界面
   *
   * 页面布局结构：
   * Stack (根容器)
   *   ├── Image (背景层)
   *   └── Column (内容层)
   *        ├── Flex (导航栏)
   *        └── Scroll (表单区域)
   *             └── Column (表单卡片)
   *                  ├── 头像上传区域
   *                  ├── 表单输入区域
   *                  ├── 协议同意区域
   *                  └── 注册操作区域
   *
   * 设计特点：
   * - 响应式布局：适配不同屏幕尺寸
   * - 卡片式设计：清晰的视觉层次
   * - 动画效果：流畅的用户体验
   * - 错误反馈：即时的表单验证
   */
  build() {
    // 根容器：Stack布局支持层级叠加
    Stack() {
      // 背景图片层：全屏背景增强视觉体验
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover) // 保持图片比例并覆盖整个区域

      // 主内容区域：垂直排列的列布局
      Column() {
        // ==================== 顶部导航栏区域 ====================
        Flex({
          alignItems: ItemAlign.Center,    // 垂直居中
          justifyContent: FlexAlign.Center // 水平居中
        }) {
          // 返回按钮：提供页面导航功能
          Text('←')
            .fontSize(20)
            .margin({ left: 12 })
            .onClick(async () => {
              await this.goBack(); // 异步导航操作
            })

          Blank().layoutWeight(1)  // 左侧弹性空白：实现标题居中

          // 页面标题：突出页面功能
          Text('注册')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)

          Blank().layoutWeight(1)  // 右侧弹性空白：保持布局对称
        }
        .width('100%')
        .height(52) // 固定高度导航栏
        .opacity(this.headerOpacity)    // 透明度动画控制
        .translate({ x: 0, y: this.headerOffset }) // 位置动画控制

        // ==================== 表单区域（可滚动容器） ====================
        Scroll() {
          Column({ space: 12 }) { // 表单项间距12vp
            // 表单标题区域
            Row({ space: 8 }) {
              Text('注册').fontSize(16).fontWeight(FontWeight.Medium)
            }

            // ==================== 头像上传区域 ====================
            Row({ space: 12 }) {
              // 头像显示容器：圆形头像框
              Stack({ alignContent: Alignment.Center }) {
                if (this.regAvatarUrl) {
                  // 用户已选择头像：显示自定义头像
                  Image(this.regAvatarUrl)
                    .width(56)
                    .height(56)
                    .borderRadius(28) // 圆形头像
                    .objectFit(ImageFit.Cover) // 图片适应容器
                } else {
                  // 默认头像状态：显示默认图片和用户名首字母
                  Image($r('app.media.mrtx')) // 默认头像资源
                    .width(56)
                    .height(56)
                    .borderRadius(28)
                    .objectFit(ImageFit.Cover)
                  Text(this.regUsername ? this.regUsername.slice(0, 1) : '我')
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .textAlign(TextAlign.Center)
                }
              }
              .width(56)
              .height(56)
              .borderRadius(28)
              .border({ width: 1, color: '#E2E8F5' }) // 浅色边框

              // 头像说明文字区域
              Column({ space: 6 }) {
                Text('上传头像').fontSize(14).fontWeight(FontWeight.Medium)
                Text('可选').fontSize(12).opacity(0.6) // 次要提示文字
              }
              .layoutWeight(1) // 弹性布局权重

              // 头像选择按钮
              Button('选择图片', { type: ButtonType.Normal })
                .onClick(async () => {
                  await this.chooseAvatar(); // 异步头像选择
                })
            }
            .alignItems(VerticalAlign.Center) // 垂直居中对齐

            // ==================== 表单输入区域 ====================

            // 用户名输入框
            TextInput({ text: this.regUsername, placeholder: '设置用户名' })
              .onChange((v) => { this.regUsername = v; }) // 实时更新状态
              .padding({ left: 12, right: 12 })
              .borderRadius(10)
              .backgroundColor('#F6F7FB') // 浅灰色背景

            // 密码输入框（密码类型）
            TextInput({ text: this.regPassword, placeholder: '设置密码' })
              .type(InputType.Password) // 密码输入类型，显示为圆点
              .onChange((v) => { this.regPassword = v; })
              .padding({ left: 12, right: 12 })
              .borderRadius(10)
              .backgroundColor('#F6F7FB')

            // 确认密码输入框
            TextInput({ text: this.regConfirmPassword, placeholder: '确认密码' })
              .type(InputType.Password)
              .onChange((v) => { this.regConfirmPassword = v; })
              .padding({ left: 12, right: 12 })
              .borderRadius(10)
              .backgroundColor('#F6F7FB')

            // 昵称输入框（可选字段）
            TextInput({ text: this.regNickname, placeholder: '昵称（可选）' })
              .onChange((v) => { this.regNickname = v; })
              .padding({ left: 12, right: 12 })
              .borderRadius(10)
              .backgroundColor('#F6F7FB')

            // ==================== 协议同意区域 ====================
            Row({ space: 8 }) {
              // 协议同意复选框
              Checkbox({ name: 'registerAgree', group: 'registerAgreement' })
                .select(this.registerAgree)
                .onChange((value: boolean) => {
                  this.registerAgree = value;
                  if (value) {
                    this.message = ''; // 同意协议时清空错误消息
                  }
                })

              // 协议文本（支持点击查看详情）
              Text() {
                Span('我已阅读并同意').fontSize(12)
                Span('《用户协议》')
                  .fontSize(12)
                  .fontColor('#3D6DFF') // 链接样式
                  .onClick((): void => {
                    this.showAgreement('user'); // 查看用户协议
                  })
                Span('和').fontSize(12)
                Span('《隐私政策》')
                  .fontSize(12)
                  .fontColor('#3D6DFF')
                  .onClick((): void => {
                    this.showAgreement('privacy'); // 查看隐私政策
                  })
              }
              // 整行点击也可切换协议状态
              .onClick(() => {
                const next = !this.registerAgree;
                this.registerAgree = next;
                if (next) {
                  this.message = '';
                }
              })
            }
            .alignItems(VerticalAlign.Center)
            .margin({ top: 4 }) // 上边距分隔

            // ==================== 注册操作区域 ====================

            // 主注册按钮
            Button('注册并登录', { type: ButtonType.Capsule })
              .onClick(async () => { await this.handleRegister(); }) // 异步注册操作

            // 错误消息显示区域（条件渲染）
            if (this.message) {
              Text(this.message)
                .fontSize(14)
                .fontColor(Color.Red) // 错误提示红色
                .margin({ top: 4 })
            }
          }
          // 表单卡片样式设计
          .padding(16) // 内边距
          .borderRadius(16) // 圆角边框
          .backgroundColor('#FFFFFF') // 白色背景
          .border({ width: 1, color: '#E9EEF5' }) // 浅色边框
          .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 }) // 阴影效果
          .opacity(this.cardOpacity) // 卡片透明度动画
          .translate({ x: 0, y: this.cardOffset }) // 卡片位置动画
        }
        .layoutWeight(1) // 弹性布局：占据剩余垂直空间
        .padding({ left: 16, right: 16, bottom: 16 }) // 滚动容器边距
      }
      .width('100%')
      .height('100%')

      // ==================== 页面动画效果 ====================
      .onAppear(() => {
        // 页面显示时的入场动画序列
        // 头部导航栏动画：快速淡入和上移
        animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.headerOpacity = 1;    // 完全显示
          this.headerOffset = 0;     // 归位到正常位置
        });

        // 表单卡片动画：稍延迟的淡入和上移
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.cardOpacity = 1;
          this.cardOffset = 0;
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}